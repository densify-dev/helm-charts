"""Run with Python 3 and PyYAML; requires Helm on PATH."""

from pathlib import Path
import re
import subprocess

import yaml


chart = Path(__file__).resolve().parents[1]
cases = [
    ("1.1.4", "1.1.4"),
    ("_release", "release"),
    ("release._-", "release"),
    ("a" * 128, "a" * 63),
    ("a" * 62 + "-" + "b", "a" * 62),
    ("_", ""),
]
for tag, expected in cases:
    rendered = subprocess.check_output(
        ["helm", "template", "kubex", str(chart), "--set-string", f"image.tag={tag}"],
        text=True,
    )
    daemonset = next(
        obj for obj in yaml.safe_load_all(rendered)
        if obj and obj.get("kind") == "DaemonSet"
    )
    pod = daemonset["spec"]["template"]
    for metadata in [daemonset["metadata"], pod["metadata"]]:
        version = metadata["labels"]["app.kubernetes.io/version"]
        assert version == expected, (tag, version, expected)
        assert len(version) <= 63
        assert re.fullmatch(r"(?:[A-Za-z0-9](?:[A-Za-z0-9_.-]*[A-Za-z0-9])?)?", version)
    assert pod["spec"]["containers"][0]["image"].endswith(f":{tag}")
    assert "app.kubernetes.io/version" not in daemonset["spec"]["selector"]["matchLabels"]

print("PASS: version labels are valid; image tags and selectors stay unchanged.")
