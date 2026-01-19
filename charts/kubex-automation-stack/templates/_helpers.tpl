{{- define "common.namespace" -}}
  {{- default .Release.Namespace .Values.nsPrefix -}}
{{- end -}}

{{- define "common.clusterName" -}}
  {{- .Values.global.cluster.name -}}
{{- end -}}

{{- define "common.kubexUrlHost" -}}
  {{- .Values.global.kubex.url.host -}}
{{- end -}}

{{- define "common.checkValues" -}}
{{- /* Check for Kubex URL host - use global */ -}}
{{- $host := include "common.kubexUrlHost" . | trim -}}
{{- if not $host -}}
    {{- fail ".Values.global.kubex.url.host is required" -}}
{{- end -}}
{{- /* Validate the host format */ -}}
{{- $domain := ".densify.com" -}}
{{- $kubexDomain := ".kubex.ai" -}}
{{- $instance := trimSuffix $domain (trimSuffix $kubexDomain $host) -}}
{{- if or (not $instance) (and (eq $instance $host) (not (contains $kubexDomain $host)) (not (contains $domain $host))) -}}
    {{- fail (printf "Kubex URL host '%s' must be in format <instance>.kubex.ai or <instance>.densify.com" $host) -}}
{{- end -}}

{{- /* Check for cluster name - use global */ -}}
{{- $clusterName := include "common.clusterName" . | trim -}}
{{- if not $clusterName -}}
    {{- fail ".Values.global.cluster.name is required" -}}
{{- end -}}

{{- /* Propagate global values to subcharts */ -}}
{{- if (index .Values "kubex-automation-controller" "enabled") -}}
  {{- if not (index .Values "kubex-automation-controller" "cluster" "name") -}}
    {{- $_ := set (index .Values "kubex-automation-controller" "cluster") "name" .Values.global.cluster.name -}}
  {{- end -}}
  {{- $kubexUrl := index .Values "kubex-automation-controller" "config" "kubex" "url" | default dict -}}
  {{- if not $kubexUrl.host -}}
    {{- $_ := set $kubexUrl "host" .Values.global.kubex.url.host -}}
  {{- end -}}
{{- end -}}
{{- if (index .Values "kubex-data-collector" "enabled") -}}
  {{- $clusters := index .Values "kubex-data-collector" "config" "clusters" | default list -}}
  {{- if gt (len $clusters) 0 -}}
    {{- $clusterName := index $clusters 0 "name" | default "" -}}
    {{- if eq $clusterName "" -}}
      {{- $_ := set (index $clusters 0) "name" .Values.global.cluster.name -}}
    {{- end -}}
  {{- end -}}
  {{- if not (index .Values "kubex-data-collector" "config" "collector" "url" "host") -}}
    {{- $_ := set (index .Values "kubex-data-collector" "config" "collector" "url") "host" .Values.global.kubex.url.host -}}
  {{- end -}}
{{- end -}}

{{- /* Additional validation for data forwarder if enabled */ -}}
{{- if (index .Values "kubex-data-collector" "enabled") -}}
  {{- $clusters := index .Values "kubex-data-collector" "config" "clusters" | default list -}}
  {{- if gt (len $clusters) 0 -}}
    {{- if ne 1 (len $clusters) -}}
        {{- fail ".Values.kubex-data-collector.config.clusters must be a list of size 1 when using this stack chart" -}}
    {{- end -}}
    {{- $cluster := first $clusters -}}
    {{- with $cluster -}}
        {{- if (.identifiers) -}}
            {{- fail ".Values.kubex-data-collector.config.clusters[0].identifiers is forbidden when using this stack chart" -}}
        {{- end -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- end -}}
