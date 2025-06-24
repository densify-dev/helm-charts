{{/*
Expand the name of the chart.
*/}}
{{- define "kubex-automation-controller.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "kubex-automation-controller.fullname" -}}
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

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "kubex-automation-controller.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "kubex-automation-controller.labels" -}}
helm.sh/chart: {{ include "kubex-automation-controller.chart" . }}
{{ include "kubex-automation-controller.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "kubex-automation-controller.selectorLabels" -}}
app.kubernetes.io/name: {{ include "kubex-automation-controller.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "kubex-automation-controller.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "kubex-automation-controller.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "kubex-automation-controller.defaultPolicies" -}}
cpu-reclaim:
  enablement:
    cpu:
      request:
        downsize: true
cpu-mem-reclaim:
  enablement:
    cpu:
      request:
        downsize: true
    memory:
      request:
        downsize: true
full-request-management:
  enablement:
    cpu:
      request:
        upsize: true
        downsize: true
        set-uninitialized-values: true
      limit:
        upsize: true
    memory:
      request:
        upsize: true
        downsize: true
        set-uninitialized-values: true
      limit:
        upsize: true
limit-oom-prevention:
  enablement:
    memory:
      limit:
        upsize: true
limit-oom-throttling-prevention:
        enablement:
          cpu:
            limit:
              upsize: true
          memory:
            limit:
              upsize: true
full-limit-management:
        enablement:
          cpu:
            limit:
              upsize: true
              set-uninitialized-values: true
          memory:
            limit:
              upsize: true
              set-uninitialized-values: true
full-optimization:
        enablement:
          cpu:
            request:
              upsize: true
              downsize: true
              set-uninitialized-values: true
            limit:
              upsize: true
              downsize: true
              set-uninitialized-values: true
          memory:
            request:
              upsize: true
              downsize: true
              set-uninitialized-values: true
            limit:
              upsize: true
              downsize: true
              set-uninitialized-values: true
{{- end }}

{{/*
- .Values.nsPrefix  : override namespace prefix
*/}}
{{- define "common.namespace" -}}
  {{- default .Release.Namespace .Values.nsPrefix -}}
{{- end -}}

{{- define "kubex-automation-controller.env_vars" -}}
- name: DENSIFY_USERNAME
  valueFrom:
    secretKeyRef:
      name: densify-api-secret-container-automation
      key: DENSIFY_USERNAME
- name: DENSIFY_EPASSWORD
  valueFrom:
    secretKeyRef:
      name: densify-api-secret-container-automation
      key: DENSIFY_EPASSWORD
- name: DENSIFY_BASE_URL
  valueFrom:
    configMapKeyRef:
      name: densify-config
      key: DENSIFY_BASE_URL
- name: CLUSTER_NAME
  valueFrom:
    configMapKeyRef:
      name: densify-config
      key: CLUSTER_NAME
{{- end }}

