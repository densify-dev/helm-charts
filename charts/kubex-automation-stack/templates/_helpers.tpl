{{- define "common.namespace" -}}
  {{- default .Release.Namespace .Values.nsPrefix -}}
{{- end -}}

{{- define "kubex-automation-stack.appScrapeConfigs" -}}
{{- $metricNames := .Values.appMetricNames | default dict -}}
{{- range $app, $selectors := (.Values.appScrapeConfigs | default dict) -}}
{{- $serviceLabels := $selectors.serviceLabels | default dict -}}
{{- $podLabels := $selectors.podLabels | default dict -}}
{{- $metricRegex := index $metricNames $app -}}
{{- if gt (len $serviceLabels) 0 }}
- job_name: {{ printf "kubex-%s-endpoint" $app | quote }}
  kubernetes_sd_configs:
    - role: endpointslice
  relabel_configs:
    {{- $seenLabels := dict }}
    {{- range $label, $regex := $serviceLabels }}
    {{- $metaLabel := regexReplaceAll "[^A-Za-z0-9_]" $label "_" }}
    {{- if hasKey $seenLabels $metaLabel }}{{ fail (printf "service label %s normalizes to duplicate name %s" $label $metaLabel) }}{{ end }}
    {{- $_ := set $seenLabels $metaLabel true }}
    - source_labels: [{{ printf "__meta_kubernetes_service_labelpresent_%s" $metaLabel | quote }}]
      regex: 'true'
      action: keep
    - source_labels: [{{ printf "__meta_kubernetes_service_label_%s" $metaLabel | quote }}]
      regex: {{ if eq (toString $regex) "*" }}'.*'{{ else }}{{ $regex | quote }}{{ end }}
      action: keep
    {{- end }}
    {{- if gt (len $podLabels) 0 }}
    {{- $seenLabels := dict }}
    {{- range $label, $regex := $podLabels }}
    {{- $metaLabel := regexReplaceAll "[^A-Za-z0-9_]" $label "_" }}
    {{- if hasKey $seenLabels $metaLabel }}{{ fail (printf "pod label %s normalizes to duplicate name %s" $label $metaLabel) }}{{ end }}
    {{- $_ := set $seenLabels $metaLabel true }}
    {{- $valueRegex := toString $regex }}
    {{- if eq $valueRegex "*" }}{{ $valueRegex = ".*" }}{{ end }}
    - source_labels: [{{ printf "__meta_kubernetes_pod_labelpresent_%s" $metaLabel | quote }}]
      regex: 'true'
      target_label: {{ printf "__tmp_kubex_pod_match_%s_present" $metaLabel | quote }}
      replacement: 'true'
      action: replace
    - source_labels: [{{ printf "__meta_kubernetes_pod_label_%s" $metaLabel | quote }}]
      regex: {{ $valueRegex | quote }}
      target_label: {{ printf "__tmp_kubex_pod_match_%s_value" $metaLabel | quote }}
      replacement: 'true'
      action: replace
    {{- end }}
    {{- $allPodLabelsRegex := "" }}
    - source_labels:
      {{- range $label, $_ := $podLabels }}
      {{- $metaLabel := regexReplaceAll "[^A-Za-z0-9_]" $label "_" }}
      {{- if ne $allPodLabelsRegex "" }}{{ $allPodLabelsRegex = printf "%s;" $allPodLabelsRegex }}{{ end }}
      {{- $allPodLabelsRegex = printf "%strue;true" $allPodLabelsRegex }}
      - {{ printf "__tmp_kubex_pod_match_%s_present" $metaLabel | quote }}
      - {{ printf "__tmp_kubex_pod_match_%s_value" $metaLabel | quote }}
      {{- end }}
      separator: ';'
      regex: {{ $allPodLabelsRegex | quote }}
      action: drop
    {{- end }}
    - source_labels: [__meta_kubernetes_namespace]
      target_label: namespace
    - source_labels: [__meta_kubernetes_pod_name]
      target_label: pod
    - source_labels: [__meta_kubernetes_pod_container_name]
      target_label: container
    - source_labels: [__meta_kubernetes_endpointslice_endpoint_node_name]
      target_label: node
    - source_labels: [__meta_kubernetes_pod_node_name]
      regex: '(.+)'
      target_label: node
  metric_relabel_configs:
    - source_labels: [__name__]
      regex: {{ required (printf "prometheus.appMetricNames.%s is required" $app) $metricRegex | quote }}
      action: keep
{{- end }}
{{- if gt (len $podLabels) 0 }}
- job_name: {{ printf "kubex-%s-pod" $app | quote }}
  kubernetes_sd_configs:
    - role: pod
  relabel_configs:
    {{- $seenLabels := dict }}
    {{- range $label, $regex := $podLabels }}
    {{- $metaLabel := regexReplaceAll "[^A-Za-z0-9_]" $label "_" }}
    {{- if hasKey $seenLabels $metaLabel }}{{ fail (printf "pod label %s normalizes to duplicate name %s" $label $metaLabel) }}{{ end }}
    {{- $_ := set $seenLabels $metaLabel true }}
    - source_labels: [{{ printf "__meta_kubernetes_pod_labelpresent_%s" $metaLabel | quote }}]
      regex: 'true'
      action: keep
    - source_labels: [{{ printf "__meta_kubernetes_pod_label_%s" $metaLabel | quote }}]
      regex: {{ if eq (toString $regex) "*" }}'.*'{{ else }}{{ $regex | quote }}{{ end }}
      action: keep
    {{- end }}
    - source_labels: [__meta_kubernetes_pod_phase]
      regex: 'Pending|Succeeded|Failed|Completed'
      action: drop
    - source_labels: [__meta_kubernetes_namespace]
      target_label: namespace
    - source_labels: [__meta_kubernetes_pod_name]
      target_label: pod
    - source_labels: [__meta_kubernetes_pod_container_name]
      target_label: container
    - source_labels: [__meta_kubernetes_pod_node_name]
      target_label: node
  metric_relabel_configs:
    - source_labels: [__name__]
      regex: {{ required (printf "prometheus.appMetricNames.%s is required" $app) $metricRegex | quote }}
      action: keep
{{- end }}
{{- end }}
{{- end -}}

{{- define "common.checkValues" -}}
{{- $openshiftEnabled := .Values.openshift.enabled -}}
{{- $deployPrometheus := .Values.stack.prometheus.deploy -}}
{{- if and $openshiftEnabled $deployPrometheus -}}
  {{- fail "OpenShift mode requires stack.prometheus.deploy=false. Use the OpenShift overlay values file for OpenShift installs." -}}
{{- end -}}
{{- $hostValueName := ".Values.container-optimization-data-forwarder.config.forwarder.densify.url.host" -}}
{{- $hostValueErr := printf "%s is required" $hostValueName -}}
{{- $host1 := index .Values "container-optimization-data-forwarder" "config" "forwarder" "densify" "url" "host" -}}
{{- $host2 := trim $host1 -}}
{{- $host := required $hostValueErr $host2 -}}
{{- /* Accept either .densify.com or .kubex.ai */ -}}
{{- $domain := "" -}}
{{- if hasSuffix ".densify.com" $host -}}
  {{- $domain = ".densify.com" -}}
{{- else if hasSuffix ".kubex.ai" $host -}}
  {{- $domain = ".kubex.ai" -}}
{{- end -}}

{{- if eq $domain "" -}}
  {{- fail (printf "%s must end with .kubex.ai or .densify.com (format: <instance>.<domain>)" $hostValueName) -}}
{{- end -}}

{{- $instance := trimSuffix $domain $host -}}
{{- if or (not $instance) (eq $instance $host) -}}
  {{- fail (printf "%s is not of <instance>%s format" $hostValueName $domain) -}}
{{- end -}}
{{- $clustersValueName := ".Values.container-optimization-data-forwarder.config.clusters" -}}
{{- $clusterValueErr := printf "%s is required" $clustersValueName -}}
{{- $clusters := index .Values "container-optimization-data-forwarder" "config" "clusters" -}}
{{- $clusters = required $clusterValueErr $clusters -}}
{{- $clusterValueErr = printf "%s must be a list of size 1" $clustersValueName -}}
{{- if ne 1 (len $clusters) -}}
    {{- fail $clusterValueErr -}}
{{- end -}}
{{ $cluster := first $clusters -}}
{{- with $cluster -}}
    {{- if not (.name) -}}
        {{- $clusterValueErr = printf "%s[0].name is required" $clustersValueName -}}
        {{- fail $clusterValueErr -}}
    {{- end -}}
    {{- if (.identifiers) -}}
        {{- $clusterValueErr = printf "%s[0].identifiers is forbidden" $clustersValueName -}}
        {{- fail $clusterValueErr -}}
    {{- end -}}
{{- end -}}
{{- end -}}
