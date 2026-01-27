{{- define "common.namespace" -}}
  {{- default .Release.Namespace .Values.nsPrefix -}}
{{- end -}}
{{- define "common.checkValues" -}}
{{- $hostValueName := ".Values.container-optimization-data-forwarder.config.forwarder.densify.url.host" -}}
{{- $hostValueErr := printf "%s is required" $hostValueName -}}
{{- $host1 := index .Values "container-optimization-data-forwarder" "config" "forwarder" "densify" "url" "host" -}}
{{- $host2 := trim $host1 -}}
{{- $host := required $hostValueErr $host2 -}}
{{- $instance := "" -}}
{{- if hasSuffix ".densify.com" $host -}}
    {{- $instance = trimSuffix ".densify.com" $host -}}
{{- else if hasSuffix ".kubex.ai" $host -}}
    {{- $instance = trimSuffix ".kubex.ai" $host -}}
{{- end -}}
{{- if not $instance -}}
    {{- fail (printf "%s is not of <instance>.densify.com or <instance>.kubex.ai format" $hostValueName) -}}
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
{{- end -}}
{{- end -}}
