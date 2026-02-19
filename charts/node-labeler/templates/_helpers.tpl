{{/* Expand the chart name. */}}
{{- define "node-labeler.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/* Create a fully qualified app name. */}}
{{- define "node-labeler.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/* Create chart name and version as used by chart label. */}}
{{- define "node-labeler.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/* Common labels. */}}
{{- define "node-labeler.labels" -}}
helm.sh/chart: {{ include "node-labeler.chart" . }}
{{ include "node-labeler.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/* Selector labels. */}}
{{- define "node-labeler.selectorLabels" -}}
app.kubernetes.io/name: {{ include "node-labeler.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/* Create the service account name to use. */}}
{{- define "node-labeler.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "node-labeler.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/* Extract health probe port from bind address. */}}
{{- define "node-labeler.healthProbePort" -}}
{{- $match := regexFind "[0-9]+$" (.Values.healthProbe.bindAddress | toString) -}}
{{- if $match -}}{{ $match }}{{- else -}}8081{{- end -}}
{{- end }}

{{/* Extract metrics port from bind address. */}}
{{- define "node-labeler.metricsPort" -}}
{{- $match := regexFind "[0-9]+$" (.Values.metrics.bindAddress | toString) -}}
{{- if $match -}}{{ $match }}{{- else -}}8443{{- end -}}
{{- end }}
