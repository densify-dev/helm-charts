{{- define "kubex-connector.name" -}}
{{- default .Chart.Name .Values.nameOverride -}}
{{- end -}}

{{- define "kubex-connector.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := include "kubex-connector.name" . -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "kubex-connector.kubexHost" -}}
{{- $localKubex := .Values.kubex | default dict -}}
{{- $localUrl := $localKubex.url | default dict -}}
{{- $global := .Values.global | default dict -}}
{{- $kubex := $global.kubex | default dict -}}
{{- $url := $kubex.url | default dict -}}
{{- $forwarder := $kubex.forwarder | default dict -}}
{{- $forwarderConnection := $forwarder.densify | default dict -}}
{{- $forwarderUrl := $forwarderConnection.url | default dict -}}
{{- $stackForwarder := index .Values "container-optimization-data-forwarder" | default dict -}}
{{- $stackConfig := $stackForwarder.config | default dict -}}
{{- $stackForwarderConnection := $stackConfig.forwarder | default dict -}}
{{- $stackKubexConfig := $stackForwarderConnection.densify | default dict -}}
{{- $stackUrl := $stackKubexConfig.url | default dict -}}
{{- $host := trim (default "" $localUrl.host) -}}
{{- if eq $host "" -}}
{{- $host = trim (default "" $url.host) -}}
{{- end -}}
{{- if eq $host "" -}}
{{- $host = trim (default "" $forwarderUrl.host) -}}
{{- end -}}
{{- if eq $host "" -}}
{{- $host = trim (default "" $stackUrl.host) -}}
{{- end -}}
{{- $host -}}
{{- end -}}

{{- define "kubex-connector.kubexClusterName" -}}
{{- $localKubex := .Values.kubex | default dict -}}
{{- $clusterName := trim (default "" $localKubex.clusterName) -}}
{{- if ne $clusterName "" -}}
{{- $clusterName -}}
{{- else -}}
{{- $global := .Values.global | default dict -}}
{{- $kubex := $global.kubex | default dict -}}
{{- $clusters := $kubex.clusters | default list -}}
{{- if eq (len $clusters) 0 -}}
{{- $stackForwarder := index .Values "container-optimization-data-forwarder" | default dict -}}
{{- $stackConfig := $stackForwarder.config | default dict -}}
{{- $clusters = $stackConfig.clusters | default list -}}
{{- end -}}
{{- $cluster := first $clusters | default dict -}}
{{- trim (default "" $cluster.name) -}}
{{- end -}}
{{- end -}}

{{- define "kubex-connector.tenantID" -}}
{{- $kubexHost := include "kubex-connector.kubexHost" . -}}
{{- if eq $kubexHost "" }}
{{- fail "kubex host is required when forwarderConfigMap.name is not set" -}}
{{- end -}}
{{- index (splitList "." $kubexHost) 0 -}}
{{- end -}}

{{- define "kubex-connector.clusterID" -}}
{{- $clusterName := include "kubex-connector.kubexClusterName" . -}}
{{- if eq $clusterName "" }}
{{- fail "kubex cluster name is required when forwarderConfigMap.name is not set" -}}
{{- end -}}
{{- $clusterName -}}
{{- end -}}

{{- define "kubex-connector.relayUpstreamWssUrl" -}}
{{- $kubexHost := include "kubex-connector.kubexHost" . -}}
{{- if eq $kubexHost "" }}
{{- fail "kubex host is required when forwarderConfigMap.name is not set" -}}
{{- end -}}
{{- printf "wss://%s/tunnel/connect" $kubexHost -}}
{{- end -}}

{{- define "kubex-connector.selectorLabels" -}}
app.kubernetes.io/name: {{ include "kubex-connector.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
