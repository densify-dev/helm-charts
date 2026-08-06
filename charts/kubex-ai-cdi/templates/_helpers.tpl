{{- define "kubex-ai-cdi.name" -}}
{{- default .Chart.Name .Values.nameOverride -}}
{{- end -}}

{{- define "kubex-ai-cdi.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride -}}
{{- else -}}
{{- printf "%s-deployment" (include "kubex-ai-cdi.name" .) -}}
{{- end -}}
{{- end -}}

{{- define "kubex-ai-cdi.clusterRoleName" -}}
{{- if .Values.clusterRoleNameOverride -}}
{{- .Values.clusterRoleNameOverride -}}
{{- else -}}
{{- printf "%s-reader" (include "kubex-ai-cdi.name" .) -}}
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
{{- default "kubex-ai-cdi-sa" .Values.serviceAccount.name -}}
{{- end -}}
