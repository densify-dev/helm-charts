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
  Create the name of the service account to use; special case for AMP on EKS
*/}}
{{- define "common.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
    {{- default (include "common.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
    {{- if and (.Values.config.prometheus.sigv4) (not (or .Values.config.prometheus.sigv4.AwsSecretName .Values.config.prometheus.sigv4.access_key)) -}}
        {{- default "amp-iamproxy-query-service-account" .Values.serviceAccount.name -}}
    {{- else -}}
        {{- default "default" .Values.serviceAccount.name -}}
    {{- end -}}
{{- end -}}
{{- end -}}
{{- define "common.serviceAccountToken" -}}
{{- if or (.Values.serviceAccount.create) (.Values.serviceAccount.name) (.Values.config.prometheus.bearer_token) -}}
    {{- default "/var/run/secrets/kubernetes.io/serviceaccount/token" .Values.config.prometheus.bearer_token -}}
{{- end -}}
{{- end -}}
{{- define "common.serviceAccountCaCert" -}}
{{- if or (.Values.serviceAccount.create) (.Values.serviceAccount.name) (.Values.config.prometheus.ca_cert) -}}
    {{- default "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt" .Values.config.prometheus.ca_cert -}}
{{- end -}}
{{- end -}}
{{- define "common.prometheusPort" -}}
  {{- default "9090" .Values.config.prometheus.url.port | quote -}}
{{- end -}}
