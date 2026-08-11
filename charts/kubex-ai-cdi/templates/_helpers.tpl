{{- define "kubex-ai-cdi.name" -}}
{{- default .Chart.Name .Values.nameOverride -}}
{{- end -}}

{{- define "kubex-ai-cdi.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := include "kubex-ai-cdi.name" . -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "kubex-ai-cdi.selectorLabels" -}}
app.kubernetes.io/name: {{ include "kubex-ai-cdi.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "kubex-ai-cdi.serviceName" -}}
{{- default (printf "%s-service" (include "kubex-ai-cdi.fullname" .)) .Values.service.name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "kubex-ai-cdi.clusterRoleName" -}}
{{- if .Values.clusterRoleNameOverride -}}
{{- .Values.clusterRoleNameOverride -}}
{{- else -}}
{{- printf "%s-reader" (include "kubex-ai-cdi.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "kubex-ai-cdi.clusterRoleBindingName" -}}
{{- if .Values.clusterRoleBindingNameOverride -}}
{{- .Values.clusterRoleBindingNameOverride -}}
{{- else -}}
{{- include "kubex-ai-cdi.clusterRoleName" . -}}
{{- end -}}
{{- end -}}

{{- define "kubex-ai-cdi.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (printf "%s-sa" (include "kubex-ai-cdi.fullname" .)) .Values.serviceAccount.name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- required "serviceAccount.name is required when serviceAccount.create is false" .Values.serviceAccount.name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
