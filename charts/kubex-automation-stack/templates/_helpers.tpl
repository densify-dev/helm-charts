{{- define "common.checkValues" -}}
{{- $username := required ".Values.stack.densify.username is required" .Values.stack.densify.username -}}
{{- $encryptedPassword := required ".Values.stack.densify.encrypted_password is required" .Values.stack.densify.encrypted_password -}}
{{- $hostValueName := ".Values.container-optimization-data-forwarder.config.forwarder.densify.url.host" -}}
{{- $hostValueErr := printf "%s is required" $hostValueName -}}
{{- $host1 := index .Values "container-optimization-data-forwarder" "config" "forwarder" "densify" "url" "host" -}}
{{- $host2 := trim $host1 -}}
{{- $host := required $hostValueErr $host2 -}}
{{- $domain := ".densify.com" -}}
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
    {{- if (.identifiers) -}}
        {{- $clusterValueErr = printf "%s[0].identifiers is forbidden" $clustersValueName -}}
        {{- fail $clusterValueErr -}}
    {{- end -}}
{{- end -}}
{{- end -}}
