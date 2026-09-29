import re
import subprocess
from pathlib import Path


chart_dir = Path(__file__).resolve().parents[1]
rendered = subprocess.run(
    [
        "helm",
        "template",
        "kubex-automation-stack",
        str(chart_dir),
        "--values",
        str(chart_dir / "values-edit.yaml"),
        "--set",
        "container-optimization-data-forwarder.config.forwarder.densify.url.host=test.kubex.ai",
    ],
    check=True,
    capture_output=True,
    text=True,
).stdout

job = re.search(
    r"(?ms)^    - job_name: kubernetes-service-endpoints\n(.*?)(?=^    - job_name: |\Z)",
    rendered,
)
assert job, "rendered Prometheus config is missing kubernetes-service-endpoints"
relabel_configs = re.search(r"(?ms)^      relabel_configs:\n(.*)", job[1])
assert relabel_configs, "service-endpoints relabel_configs are missing"
rules = re.split(r"(?m)(?=^      - action: )", relabel_configs[1])


def rule_regex(action, source_label):
    for rule in rules:
        if not rule.startswith(f"      - action: {action}\n"):
            continue
        labels = re.findall(r"(?m)^        - ([^\n]+)$", rule)
        if source_label in labels:
            return re.search(r"(?m)^        regex: (.+)$", rule)[1]
    raise AssertionError(f"missing {action} rule for {source_label}")


keep = re.compile(rule_regex("keep", "__meta_kubernetes_endpointslice_name"))
drop = re.compile(rule_regex("drop", "__meta_kubernetes_service_name"))


def retained(endpoint_slice, service, port):
    return bool(keep.fullmatch(endpoint_slice)) and not drop.fullmatch(f"{service};{port}")


for prefix in ("kubex-automation-stack", "kubex", "densify"):
    ksm = f"{prefix}-kube-state-metrics"
    assert retained(f"{ksm}-abc123", ksm, "8080"), f"{ksm} target was dropped"
    assert not retained(f"{ksm}-abc123", ksm, "8081"), f"{ksm}:8081 target was retained"

    exporter = f"{prefix}-prometheus-node-exporter"
    assert retained(f"{exporter}-abc123", exporter, "9191"), f"{exporter} target was dropped"

for service, port in (
    ("other-release-kube-state-metrics", "8080"),
    ("other-release-prometheus-node-exporter", "9191"),
):
    assert not retained(f"{service}-abc123", service, port), f"unrelated {service} target was retained"

print("Prometheus relabel regression check passed")
