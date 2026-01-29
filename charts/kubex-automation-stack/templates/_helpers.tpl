{{- define "common.namespace" -}}
  {{- default .Release.Namespace .Values.nsPrefix -}}
{{- end -}}
{{- define "common.checkValues" -}}
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
