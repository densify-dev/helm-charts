#!/usr/bin/env python3
"""Email release notes for primary charts released in a commit range.

For each primary chart in .github/changelog-notify.json whose Chart.yaml
changed in the selected commit range, email its changelog additions and any
dependency release notes adopted by the chart. When enabled, dependency notes
are automatically added for subcharts declared in Chart.yaml whenever their
CHANGELOG.md exists and the stack adopted a newer dependency version. Explicit
includes remain available for non-standard changelog paths.

Subscriber addresses come from GitHub secrets (one per chart) and are never
printed, because Actions logs on a public repo are public. Delivery uses one
SendGrid request per chart; an ambiguous network failure stops the workflow so
the operator can inspect SendGrid before deciding whether to retry.
"""
import html
import hashlib
import json
import os
import re
import subprocess
import sys
from functools import total_ordering
import urllib.error
import urllib.request
from urllib.parse import urljoin

import markdown
import yaml

MAIL_SEND_URL = "https://api.sendgrid.com/v3/mail/send"
CONFIG_PATH = ".github/changelog-notify.json"
EMPTY_TREE = "4b825dc642cb6eb9a060e54bf8d69288fbee4904"  # git's empty tree
MAX_RECIPIENTS = 1000  # SendGrid's limit on personalizations per request


def git(*args):
    return subprocess.run(["git", *args], check=True,
                          capture_output=True, text=True).stdout


def added_lines(before, after, path):
    """Return only the lines added to `path` between two commits."""
    diff = git("diff", "-U0", before, after, "--", path)
    lines = [l[1:] for l in diff.splitlines()
             if l.startswith("+") and not l.startswith("+++")]
    return "\n".join(lines).strip()


def changed(before, after, path):
    """Return whether a path changed in the selected commit range."""
    result = subprocess.run(
        ["git", "diff", "--quiet", before, after, "--", path],
        check=False,
    )
    if result.returncode not in (0, 1):
        raise subprocess.CalledProcessError(result.returncode, result.args)
    return result.returncode == 1


def file_at(ref, path):
    """Return a repository file at ref, or an empty string if it is absent."""
    if ref == EMPTY_TREE:
        return ""
    ref_check = subprocess.run(
        ["git", "rev-parse", "--verify", f"{ref}^{{commit}}"],
        check=False,
        capture_output=True,
        text=True,
    )
    if ref_check.returncode != 0:
        raise subprocess.CalledProcessError(ref_check.returncode, ref_check.args)
    result = subprocess.run(["git", "show", f"{ref}:{path}"], check=False,
                            capture_output=True, text=True)
    if result.returncode == 0:
        return result.stdout
    path_check = subprocess.run(
        ["git", "cat-file", "-e", f"{ref}:{path}"], check=False,
        capture_output=True,
    )
    # The revision was validated above, so any cat-file miss here means the
    # path is absent at that revision (Git uses 128 for this case).
    if path_check.returncode != 0:
        return ""
    raise subprocess.CalledProcessError(result.returncode, result.args)


def dependency_version(ref, chart_path, dependency):
    """Read a dependency version from a Chart.yaml."""
    chart = file_at(ref, chart_path)
    for item in chart_dependencies(chart):
        if item.get("name") == dependency:
            version = item.get("version")
            return str(version) if version is not None else None
    return None


def dependency_names(ref, chart_path):
    """Return dependency names declared in a Chart.yaml."""
    chart = file_at(ref, chart_path)
    return [item["name"] for item in chart_dependencies(chart)
            if item.get("name")]


def chart_dependencies(chart):
    """Return validated dependency mappings from Chart.yaml."""
    document = yaml.safe_load(chart) or {}
    dependencies = document.get("dependencies", [])
    if dependencies is None:
        return []
    if not isinstance(dependencies, list) or any(
            not isinstance(item, dict) for item in dependencies):
        raise ValueError("Chart.yaml dependencies must be a list of mappings")
    return dependencies


def primary_chart_path(changelog_path):
    return f"{changelog_path.rsplit('/', 1)[0]}/Chart.yaml"


def release_version(changelog_text):
    """Return the first release version in a primary changelog addition."""
    match = re.search(r"^## \[((?:\d+\.){2}\d+(?:[-+][0-9A-Za-z.-]+)?)\]", changelog_text,
                      re.MULTILINE)
    return match.group(1) if match else None


@total_ordering
class SemVer:
    """Minimal SemVer value supporting release-note range comparisons."""

    def __init__(self, value):
        match = re.fullmatch(
            r"v?((?:\d+\.){2}\d+)(?:-([0-9A-Za-z.-]+))?(?:\+([0-9A-Za-z.-]+))?",
            str(value),
        )
        if not match:
            raise ValueError(f"invalid semantic version: {value}")
        self.base = tuple(map(int, match.group(1).split(".")))
        self.prerelease = match.group(2).split(".") if match.group(2) else None

    def __eq__(self, other):
        return isinstance(other, SemVer) and self.base == other.base and self.prerelease == other.prerelease

    def __lt__(self, other):
        if not isinstance(other, SemVer):
            return NotImplemented
        if self.base != other.base:
            return self.base < other.base
        if self.prerelease is None:
            return False
        if other.prerelease is None:
            return True
        for left, right in zip(self.prerelease, other.prerelease):
            if left == right:
                continue
            if left.isdigit() and right.isdigit():
                return int(left) < int(right)
            if left.isdigit() != right.isdigit():
                return left.isdigit()
            return left < right
        return len(self.prerelease) < len(other.prerelease)


def version_tuple(version):
    try:
        return SemVer(version) if version else None
    except ValueError:
        return None


def release_notes_between(changelog, old_version, new_version):
    """Return complete release sections in (old_version, new_version]."""
    old = version_tuple(old_version)
    new = version_tuple(new_version)
    if not old or not new or old >= new:
        return ""

    sections = re.findall(
        r"(?ms)^## \[(?:\d+\.){2}\d+(?:[-+][0-9A-Za-z.-]+)?\].*?(?=^## \[|\Z)", changelog)
    selected = []
    for section in sections:
        version = re.search(
            r"^## \[((?:\d+\.){2}\d+(?:[-+][0-9A-Za-z.-]+)?)\]",
            section,
            re.MULTILINE,
        )
        if version and old < version_tuple(version.group(1)) <= new:
            selected.append(section.strip())
    return "\n\n".join(selected)


def resolve_links(text, source_path, server, repo, ref):
    """Make relative Markdown links point to files beside source_path on GitHub."""
    base = f"{server}/{repo}/blob/{ref}/{source_path.rsplit('/', 1)[0]}/"

    def replace(match):
        target = match.group(1)
        if (target.startswith(("#", "/", "//")) or
                re.match(r"^[a-z][a-z0-9+.-]*:", target, re.IGNORECASE)):
            return match.group(0)
        return match.group(0).replace(target, urljoin(base, target), 1)

    return re.sub(r"\]\(([^)\s]+)", replace, text)


def combined_changelog_text(before, after, primary_path, text, config,
                            server, repo):
    """Combine primary notes with dependency releases adopted by the chart."""
    sections = []
    if text:
        sections.append(resolve_links(text, primary_path, server, repo, after))

    chart_path = primary_chart_path(primary_path)
    includes = list(config.get("includes", []))
    configured_dependencies = {
        included.get("dependency") for included in includes
        if included.get("dependency")
    }
    if config.get("include_subcharts"):
        template = config.get(
            "subchart_changelog_template", "charts/{dependency}/CHANGELOG.md")
        paths = config.get("subchart_changelog_paths", {})
        for dependency in dependency_names(after, chart_path):
            if dependency in configured_dependencies:
                continue
            includes.append({
                "chart": dependency,
                "dependency": dependency,
                "changelog": paths.get(
                    dependency, template.format(dependency=dependency)),
            })

    for included in includes:
        dependency = included.get("dependency")
        included_text = ""
        if dependency:
            old_version = dependency_version(before, chart_path, dependency)
            new_version = dependency_version(after, chart_path, dependency)
            changelog = file_at(after, included["changelog"])
            if changelog:
                included_text = release_notes_between(
                    changelog, old_version, new_version)
        else:
            included_text = added_lines(before, after, included["changelog"])
        if included_text:
            included_text = resolve_links(
                included_text, included["changelog"], server, repo, after)
            sections.append(
                f"## {included['chart']} release notes\n\n{included_text}"
            )
    return "\n\n".join(sections)


def parse_emails(raw):
    """Secret value: addresses separated by commas, spaces or new lines."""
    candidates = (e.strip().lower() for e in re.split(r"[,\s;]+", raw or ""))
    return sorted({e for e in candidates
                   if re.fullmatch(r"[^@\s]+@[^@\s]+\.[^@\s]+", e)})


def send(api_key, payload):
    req = urllib.request.Request(
        MAIL_SEND_URL, data=json.dumps(payload).encode(), method="POST",
        headers={"Authorization": f"Bearer {api_key}",
                 "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return resp.status  # 202 = accepted
    except urllib.error.HTTPError as err:
        err.read()
        sys.exit(f"SendGrid mail send failed: HTTP {err.code}")
    except urllib.error.URLError:
        sys.exit("SendGrid request outcome is unknown; inspect SendGrid before retrying.")


def sanitize_html(fragment):
    """Allow only safe URL schemes in generated link and image attributes."""
    def replace(match):
        prefix, target, suffix = match.groups()
        if target.startswith(("http://", "https://", "mailto:", "#")):
            return match.group(0)
        return f"{prefix}#{suffix}"

    return re.sub(
        r"(\b(?:href|src)\s*=\s*[\"'])(.*?)([\"'])",
        replace,
        fragment,
        flags=re.IGNORECASE,
    )


def build_html(chart, body_md, link):
    # CHANGELOG.md uses `---` as an entry separator. Remove it before Markdown
    # conversion so it cannot be interpreted as a setext heading underline.
    markdown_body = html.escape(
        re.sub(r"(?m)^---\s*$", "", body_md).strip(), quote=False)
    body = sanitize_html(markdown.markdown(markdown_body, extensions=["extra"]))
    safe_chart = html.escape(chart)
    safe_link = html.escape(link, quote=True)
    return f"""<html><body style="font-family:Arial,sans-serif;max-width:640px;margin:auto">
<h2>{safe_chart}: changelog update</h2>
{body}
<p><a href="{safe_link}">View the full CHANGELOG on GitHub</a></p>
<hr>
<p style="font-size:12px;color:#666">
You're receiving this because you subscribed to {safe_chart} release notes.<br>
<a href="<%asm_group_unsubscribe_raw_url%>">Unsubscribe from {safe_chart} updates</a> |
<a href="<%asm_preferences_raw_url%>">Manage all chart subscriptions</a>
</p></body></html>"""


def build_text(chart, body_md, link):
    return (f"{chart}: changelog update\n\n{body_md}\n\n"
            f"Full changelog: {link}\n\n"
            "Unsubscribe from this chart: <%asm_group_unsubscribe_raw_url%>\n"
            "Manage all subscriptions: <%asm_preferences_raw_url%>\n")


def main():
    api_key = os.environ.get("SENDGRID_API_KEY")
    before = os.environ.get("BEFORE_SHA", "").strip()
    after = os.environ.get("AFTER_SHA", "HEAD").strip()
    if not before or set(before) == {"0"}:   # first push to a new branch
        before = EMPTY_TREE
    dry_run = os.environ.get("DRY_RUN", "false").lower() == "true"
    test_mode = os.environ.get("TEST_MODE", "false").lower() == "true"

    if not api_key and not dry_run:
        sys.exit("SENDGRID_API_KEY secret is missing.")

    with open(CONFIG_PATH) as fh:
        config = json.load(fh)

    repo = os.environ.get("GITHUB_REPOSITORY", "")
    server = os.environ.get("GITHUB_SERVER_URL", "https://github.com")
    sent = 0
    delivery_complete = True

    for chart, cfg in config["charts"].items():
        # Embedded charts are delivered through their primary chart's release
        # notification, after the dependency bump has been published.
        if cfg.get("notification") == "embedded":
            continue

        path = cfg["changelog"]
        # Dependency notes are sent only when the stack Chart.yaml changed, so
        # a subchart release is announced after the stack adopts that version.
        if not changed(before, after, primary_chart_path(path)):
            continue
        text = added_lines(before, after, path)
        primary_version = release_version(text)
        text = combined_changelog_text(
            before, after, path, text, cfg, server, repo)
        if not text:
            continue

        secret_name = "SUBSCRIBERS_TEST" if test_mode else cfg["subscribers_secret"]
        recipients = parse_emails(os.environ.get(secret_name))

        version = f" v{primary_version}" if primary_version else ""
        subject = f"{chart}{version}: weekly release digest"
        link = f"{server}/{repo}/blob/{after}/{path}"

        print(f"--- {chart}: notification prepared")
        print(f"Subject: {subject}")
        if not recipients:
            print(f"::error::No valid subscribers configured for {chart}.")
            delivery_complete = False
            continue
        if len(recipients) > MAX_RECIPIENTS:
            sys.exit(
                f"{chart} has {len(recipients)} subscribers; the workflow supports "
                f"at most {MAX_RECIPIENTS} to avoid partial batch delivery."
            )
        if dry_run:
            continue

        payload = {
            # one personalization per person, so nobody sees other recipients
            "personalizations": [{"to": [{"email": e}]} for e in recipients],
            "from": config["from"],
            "subject": subject,
            "content": [
                {"type": "text/plain",
                 "value": build_text(chart, text, link)},
                {"type": "text/html",
                 "value": build_html(chart, text, link)},
            ],
            "asm": {"group_id": cfg["unsubscribe_group_id"],
                    "groups_to_display": [cfg["unsubscribe_group_id"]]},
            "categories": ["helm-changelog", chart[:255]],
        }
        if config.get("reply_to"):
            payload["reply_to"] = config["reply_to"]
        delivery_id = hashlib.sha256(
            f"{chart}\0{before}\0{after}".encode()).hexdigest()
        payload["custom_args"] = {"changelog_delivery_id": delivery_id}
        status = send(api_key, payload)
        print(f"SendGrid accepted the notification (HTTP {status}).")
        sent += 1

    mode = " (dry run)" if dry_run else (" (test mode)" if test_mode else "")
    if not delivery_complete:
        sys.exit("No subscribers were configured for one or more notifications.")
    print(f"Done. Emails sent for {sent} chart(s){mode}.")


if __name__ == "__main__":
    main()

