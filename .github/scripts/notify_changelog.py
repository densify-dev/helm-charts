#!/usr/bin/env python3
"""Save as: .github/scripts/notify_changelog.py

For each primary chart in .github/changelog-notify.json whose own or included
CHANGELOG.md changed in this push, email the newly added lines to that chart's
subscribers. Included dependency release notes are added to the same email.

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


def combined_changelog_text(before, after, text, config):
    """Combine primary notes with notes from included charts changed together."""
    sections = [text] if text else []
    for included in config.get("includes", []):
        included_text = added_lines(before, after, included["changelog"])
        if included_text:
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

    for chart, cfg in config["charts"].items():
        # Embedded charts are delivered through their primary chart's release
        # notification, after the dependency bump has been published.
        if cfg.get("notification") == "embedded":
            continue

        path = cfg["changelog"]
        text = added_lines(before, after, path)
        text = combined_changelog_text(before, after, text, cfg)
        if not text:
            continue

        secret_name = "SUBSCRIBERS_TEST" if test_mode else cfg["subscribers_secret"]
        recipients = parse_emails(os.environ.get(secret_name))

        match = re.search(r"\bv?(\d+\.\d+\.\d+)\b", text)
        version = f" v{match.group(1)}" if match else ""
        subject = f"{chart}{version}: what's new"
        link = f"{server}/{repo}/blob/{after}/{path}"

        print(f"--- {chart}: {len(recipients)} recipient(s) from {secret_name}")
        print(f"Subject: {subject}\n{text}\n")
        if not recipients:
            print(f"::warning::{secret_name} is empty or missing; skipping {chart}.")
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
            print(f"Batch of {len(batch)} accepted by SendGrid (HTTP {status}).")
        sent += 1

    mode = " (dry run)" if dry_run else (" (test mode)" if test_mode else "")
    print(f"Done. Emails sent for {sent} chart(s){mode}.")


if __name__ == "__main__":
    main()

