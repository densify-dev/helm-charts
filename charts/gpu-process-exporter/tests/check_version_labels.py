"""Run with Python 3 and PyYAML; requires Helm on PATH."""

from pathlib import Path
import re
import subprocess

import yaml


chart = Path(__file__).resolve().parents[1]
chart_version = yaml.safe_load((chart / "Chart.yaml").read_text())["version"]
cases = [
    ("1.1.4", "1.1.4"),
    ("1.1.4@sha256:" + "0" * 64, "1.1.4"),
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
    objects = list(yaml.safe_load_all(rendered))
    rbac = [
        obj for obj in objects
        if obj and obj.get("kind") in {"ServiceAccount", "ClusterRole", "ClusterRoleBinding"}
    ]
    assert len(rbac) == 3
    for obj in rbac:
        labels = obj["metadata"]["labels"]
        assert labels["helm.sh/chart"] == f"gpu-process-exporter-{chart_version}"
        assert labels["app.kubernetes.io/managed-by"] == "Helm"
    daemonset = next(
        obj for obj in objects
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
