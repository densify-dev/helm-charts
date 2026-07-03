{{- define "kubex-ai-cdi.serviceAccountName" -}}
{{- default "kubex-ai-cdi-sa" .Values.serviceAccount.name -}}
{{- end -}}
