#!/usr/bin/env python3
"""Save as: .github/scripts/notify_changelog.py

For each primary chart in .github/changelog-notify.json whose own or included
CHANGELOG.md changed in the selected commit range, email the newly added lines
to that chart's subscribers. Included dependency release notes are added to
the same digest email.

Subscriber addresses come from GitHub secrets (one per chart) and are never
printed, because Actions logs on a public repo are public.
"""
import json
import os
import re
import subprocess
import sys
import time
import urllib.error
import urllib.request
from urllib.parse import urljoin

import markdown

MAIL_SEND_URL = "https://api.sendgrid.com/v3/mail/send"
CONFIG_PATH = ".github/changelog-notify.json"
EMPTY_TREE = "4b825dc642cb6eb9a060e54bf8d69288fbee4904"  # git's empty tree
BATCH_SIZE = 1000  # SendGrid's limit on personalizations per request
MAX_SEND_ATTEMPTS = 3


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
    result = subprocess.run(["git", "show", f"{ref}:{path}"], check=False,
                            capture_output=True, text=True)
    return result.stdout if result.returncode == 0 else ""


def dependency_version(ref, chart_path, dependency):
    """Read a dependency version from a Chart.yaml without requiring PyYAML."""
    chart = file_at(ref, chart_path)
    pattern = (rf"(?ms)^\s*-\s+name:\s*['\"]?{re.escape(dependency)}['\"]?\s*$"
               rf".*?^\s+version:\s*['\"]?([^'\"\s]+)")
    match = re.search(pattern, chart)
    return match.group(1) if match else None


def primary_chart_path(changelog_path):
    return f"{changelog_path.rsplit('/', 1)[0]}/Chart.yaml"


def release_version(changelog_text):
    """Return the first release version in a primary changelog addition."""
    match = re.search(r"^## \[(\d+\.\d+\.\d+)\]", changelog_text,
                      re.MULTILINE)
    return match.group(1) if match else None


def version_tuple(version):
    match = re.fullmatch(r"(\d+)\.(\d+)\.(\d+)", version or "")
    return tuple(map(int, match.groups())) if match else None


def release_notes_between(changelog, old_version, new_version):
    """Return complete release sections in (old_version, new_version]."""
    old = version_tuple(old_version)
    new = version_tuple(new_version)
    if not old or not new or old >= new:
        return ""

    sections = re.findall(
        r"(?ms)^## \[(?:\d+\.\d+\.\d+)\].*?(?=^## \[|\Z)", changelog)
    selected = []
    for section in sections:
        version = re.search(r"^## \[(\d+\.\d+\.\d+)\]", section, re.MULTILINE)
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
    """Combine primary notes with included releases adopted by the primary chart."""
    sections = []
    if text:
        sections.append(resolve_links(text, primary_path, server, repo, after))

    chart_path = primary_chart_path(primary_path)
    for included in config.get("includes", []):
        dependency = included.get("dependency")
        included_text = ""
        if dependency:
            old_version = dependency_version(before, chart_path, dependency)
            new_version = dependency_version(after, chart_path, dependency)
            included_text = release_notes_between(
                file_at(after, included["changelog"]), old_version, new_version)
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
    retryable = {408, 429, 500, 502, 503, 504}
    for attempt in range(1, MAX_SEND_ATTEMPTS + 1):
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                return resp.status  # 202 = accepted
        except urllib.error.HTTPError as err:
            detail = err.read().decode(errors="replace")
            if err.code not in retryable or attempt == MAX_SEND_ATTEMPTS:
                sys.exit(f"SendGrid mail send failed: {err.code} {detail}")
            print(f"SendGrid returned HTTP {err.code}; retrying ({attempt}/{MAX_SEND_ATTEMPTS - 1})...")
        except urllib.error.URLError as err:
            if attempt == MAX_SEND_ATTEMPTS:
                sys.exit(f"SendGrid request failed: {err.reason}")
            print(f"SendGrid request failed; retrying ({attempt}/{MAX_SEND_ATTEMPTS - 1})...")
        time.sleep(2 ** (attempt - 1))


def build_html(chart, body_md, link, address):
    # CHANGELOG.md uses `---` as an entry separator. Remove it before Markdown
    # conversion so it cannot be interpreted as a setext heading underline.
    markdown_body = re.sub(r"(?m)^---\s*$", "", body_md).strip()
    body = markdown.markdown(markdown_body, extensions=["extra"])
    return f"""<html><body style="font-family:Arial,sans-serif;max-width:640px;margin:auto">
<h2>{chart}: changelog update</h2>
{body}
<p><a href="{link}">View the full CHANGELOG on GitHub</a></p>
<hr>
<p style="font-size:12px;color:#666">
You're receiving this because you subscribed to {chart} release notes.<br>
<a href="<%asm_group_unsubscribe_raw_url%>">Unsubscribe from {chart} updates</a> |
<a href="<%asm_preferences_raw_url%>">Manage all chart subscriptions</a><br>
{address}
</p></body></html>"""


def build_text(chart, body_md, link, address):
    return (f"{chart}: changelog update\n\n{body_md}\n\n"
            f"Full changelog: {link}\n\n"
            "Unsubscribe from this chart: <%asm_group_unsubscribe_raw_url%>\n"
            "Manage all subscriptions: <%asm_preferences_raw_url%>\n"
            f"{address}\n")


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
        # Included dependency notes belong to a primary notification only after
        # the primary chart itself is released. A dependency's own release can
        # otherwise notify stack subscribers before the stack adopts it.
        if not changed(before, after, primary_chart_path(path)):
            continue
        text = added_lines(before, after, path)
        if not text:
            continue
        primary_version = release_version(text)
        primary_text = resolve_links(text, path, server, repo, after)
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
        print(f"Subject: {subject}\n{primary_text}\n")
        if not recipients:
            print(f"::error::No valid subscribers configured for {chart}.")
            delivery_complete = False
            continue
        if dry_run:
            continue

        for i in range(0, len(recipients), BATCH_SIZE):
            batch = recipients[i:i + BATCH_SIZE]
            payload = {
                # one personalization per person, so nobody sees other recipients
                "personalizations": [{"to": [{"email": e}]} for e in batch],
                "from": config["from"],
                "subject": subject,
                "content": [
                    {"type": "text/plain",
                     "value": build_text(chart, text, link, config["postal_address"])},
                    {"type": "text/html",
                     "value": build_html(chart, text, link, config["postal_address"])},
                ],
                "asm": {"group_id": cfg["unsubscribe_group_id"],
                        "groups_to_display": [cfg["unsubscribe_group_id"]]},
                "categories": ["helm-changelog", chart[:255]],
            }
            if config.get("reply_to"):
                payload["reply_to"] = config["reply_to"]
            status = send(api_key, payload)
            print(f"SendGrid accepted a notification batch (HTTP {status}).")
        sent += 1

    mode = " (dry run)" if dry_run else (" (test mode)" if test_mode else "")
    if not delivery_complete:
        sys.exit("No subscribers were configured for one or more notifications.")
    print(f"Done. Emails sent for {sent} chart(s){mode}.")


if __name__ == "__main__":
    main()

