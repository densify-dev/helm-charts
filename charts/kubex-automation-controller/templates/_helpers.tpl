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
Generate or retrieve self-signed certificates for webhook
Returns a dict with ca, cert, and key
*/}}
{{- define "kubex-automation-controller.gen-certs-data" -}}
{{- $secretName := "kubex-automation-tls" -}}
{{- $secret := lookup "v1" "Secret" .Release.Namespace $secretName -}}
{{- if $secret -}}
{{/* Reuse existing certificates */}}
{{- $_ := set . "caCert" (index $secret.data "ca.crt") -}}
{{- $_ := set . "tlsCert" (index $secret.data "tls.crt") -}}
{{- $_ := set . "tlsKey" (index $secret.data "tls.key") -}}
{{- else -}}
{{/* Generate new certificates and cache in context */}}
{{- if not .caCert -}}
{{- $serviceName := "kubex-webhook-service" -}}
{{- $namespace := .Release.Namespace -}}
{{- $validity := int .Values.selfSignedCert.validity -}}
{{- $cn := printf "%s.%s.svc" $serviceName $namespace -}}
{{- $altNames := list $serviceName (printf "%s.%s" $serviceName $namespace) (printf "%s.%s.svc" $serviceName $namespace) (printf "%s.%s.svc.cluster.local" $serviceName $namespace) -}}
{{- $ca := genCA "kubex-webhook-ca" $validity -}}
{{- $cert := genSignedCert $cn nil $altNames $validity $ca -}}
{{- $_ := set . "caCert" ($ca.Cert | b64enc) -}}
{{- $_ := set . "tlsCert" ($cert.Cert | b64enc) -}}
{{- $_ := set . "tlsKey" ($cert.Key | b64enc) -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Format certificates for secret data
*/}}
{{- define "kubex-automation-controller.gen-certs" -}}
{{- include "kubex-automation-controller.gen-certs-data" . -}}
ca.crt: {{ .caCert }}
tls.crt: {{ .tlsCert }}
tls.key: {{ .tlsKey }}
{{- end -}}

{{/*
Get CA certificate for webhook configuration
*/}}
{{- define "kubex-automation-controller.ca-bundle" -}}
{{- include "kubex-automation-controller.gen-certs-data" . -}}
{{ .caCert }}
{{- end -}}

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

{{- define "kubex-automation-controller.env_vars" }}
- name: CLUSTER_NAME
  valueFrom:
    configMapKeyRef:
      name: kubex-config
      key: CLUSTER_NAME
- name: DEBUG
  value: {{ .Values.deployment.controllerEnv.debug | quote }}
{{- end }}

{{- define "kubex-automation-controller.kubex-automation-controller-clusterrole-rules" }}
  - apiGroups: [""]
    resources: ["namespaces", "nodes", "limitranges", "resourcequotas", "services"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["apps"]
    resources: ["replicasets", "deployments"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["batch"]
    resources: ["jobs"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: [""]
    resources: ["pods/eviction"]
    verbs: ["create"]
  - apiGroups: [""]
    resources: ["pods/resize"]
    verbs: ["patch", "update"]
  - nonResourceURLs:
    - "/metrics"
    verbs:
    - "get"
{{- end }}

{{/*
Generate Kubex epassword that persists across upgrades
*/}}
{{- define "kubex-automation-controller.credentials.epassword" -}}
{{- if .Values.createSecrets }}
{{- $epassword := .Values.credentials.epassword | default "" -}}
{{- if not $epassword -}}
  {{- if .Values.global -}}
    {{- if .Values.global.credentials -}}
      {{- $epassword = .Values.global.credentials.epassword | default "" -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- $epassword | required "An epassword must be provided in global.credentials.epassword or credentials.epassword" -}}
{{- end }}
{{- end }}
{{/*
Generate Kubex username that persists across upgrades
*/}}
{{- define "kubex-automation-controller.credentials.username" -}}
{{- if .Values.createSecrets }}
{{- $username := .Values.credentials.username | default "" -}}
{{- if not $username -}}
  {{- if .Values.global -}}
    {{- if .Values.global.credentials -}}
      {{- $username = .Values.global.credentials.username | default "" -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- $username | required "A username must be provided in global.credentials.username or credentials.username" -}}
{{- end }}
{{- end }}
{{/*
Generate Valkey password that persists across upgrades
*/}}
{{- define "kubex-automation-controller.valkeyPassword" -}}
{{- if .Values.createSecrets }}
{{- .Values.valkey.credentials.password | required "A password must be provided in kubex-automation-values.yaml under valkey.credentials.password" -}}
{{- end }}
{{- end }}
{{/*
Generate Valkey username - defaults to kubexAutomation but can be overridden
*/}}
{{- define "kubex-automation-controller.valkeyUsername" -}}
{{- if .Values.createSecrets }}
{{- .Values.valkey.credentials.user | default "kubexAutomation" -}}
{{- end }}
{{- end }}

{{- define "kubex-automation-controller.userSecretName" -}}
{{- .Values.credentials.userSecretName | default "kubex-api-secret-container-automation" -}}
{{- end }}

{{- define "kubex-automation-controller.densifyUserSecretName" -}}
{{- include "kubex-automation-controller.userSecretName" . -}}
{{- end }}
