{{/*
  Expand the name of a chart.
*/}}
{{- define "common.name" -}}
  {{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
  Create a default fully qualified application name.
  Truncated at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "common.fullname" -}}
  {{- $name := default .Chart.Name .Values.nameOverride -}}
  {{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
  Resolve the namespace to apply to a chart. The default namespace suffix
  is the name of the chart. This can be overridden if necessary (eg. for subcharts)
  using the following value:

  - .Values.nsPrefix  : override namespace prefix
*/}}
{{- define "common.namespace" -}}
  {{- default .Release.Namespace .Values.nsPrefix -}}
{{- end -}}

{{/*
  Resolve the name of a chart's service.

  The default will be the chart name (or .Values.nameOverride if set).
  And the use of .Values.service.name overrides all.

  - .Values.service.name  : override default service (ie. chart) name
*/}}
{{/*
  Expand the service name for a chart.
*/}}
{{- define "common.servicename" -}}
  {{- $name := default .Chart.Name .Values.nameOverride -}}
  {{- default $name .Values.service.name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create the name of the service account to use
*/}}
{{- define "common.serviceAccountName" -}}
{{- if .Values.authorization.serviceAccount.create -}}
    {{ default (include "common.fullname" .) .Values.authorization.serviceAccount.name }}
{{- else -}}
    {{ default "default" .Values.authorization.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{/*
Create the name of the cluster role binding to use
*/}}
{{- define "common.clusterRoleBindingName" -}}
{{- if .Values.authorization.clusterRoleBinding.create -}}
    {{ default (include "common.fullname" .) .Values.authorization.clusterRoleBinding.name }}
{{- else -}}
    {{ default "default" .Values.authorization.clusterRoleBinding.name }}
{{- end -}}
{{- end -}}

{{/*
Create the name of the cluster role to use
*/}}
{{- define "common.clusterRoleName" -}}
{{- if .Values.authorization.clusterRole.create -}}
    {{ default (include "common.fullname" .) .Values.authorization.clusterRole.name }}
{{- else -}}
    {{ default "default" .Values.authorization.clusterRole.name }}
{{- end -}}
{{- end -}}