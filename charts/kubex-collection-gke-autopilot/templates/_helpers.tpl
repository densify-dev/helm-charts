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
{{- if hasSuffix $host ".densify.com" -}}
  {{- $domain = ".densify.com" -}}
{{- else if hasSuffix $host ".kubex.ai" -}}
  {{- $domain = ".kubex.ai" -}}
{{- end -}}
{{- if eq $domain "" -}}
  {{- fail (printf "%s must end with .kubex.ai or .densify.com (format: <instance>.<domain>)" $hostValueName) -}}
{{- end -}}
{{- $hostValueErr = printf "%s is not of <instance>%s format" $hostValueName $domain -}}
{{- $instance := trimSuffix $domain $host -}}
{{- if or (not $instance) (eq $instance $host) -}}
    {{- fail $hostValueErr -}}
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
