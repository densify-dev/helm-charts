{{/*
Validate kubexCredentials.epassword is provided if createSecrets is true
*/}}
{{- define "kubex-automation-engine.kubexEpassword" -}}
{{- if .Values.createSecrets }}
{{- .Values.kubexCredentials.epassword | required "An epassword must be provided in values.yaml under kubexCredentials.epassword" -}}
{{- end }}
{{- end }}

{{/*
Validate kubexCredentials.username is provided if createSecrets is true
*/}}
{{- define "kubex-automation-engine.kubexUsername" -}}
{{- if .Values.createSecrets }}
{{- .Values.kubexCredentials.username | required "A username must be provided in values.yaml under kubexCredentials.username" -}}
{{- end }}
{{- end }}

{{/*
Validate kubex.url.host is provided if createSecrets is true
*/}}
{{- define "kubex-automation-engine.kubexUrl" -}}
{{- if .Values.createSecrets }}
{{- .Values.kubex.url.host | required "A Kubex URL host must be provided in values.yaml under kubex.url.host" -}}
{{- end }}
{{- end }}
{{/*
Expand the name of the chart.
*/}}
{{- define "kubex-automation-engine.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "kubex-automation-engine.fullname" -}}
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
Create a shorter name for uninstall hook resources.
Using the release name avoids repetitive "<release>-<chart>" expansion.
*/}}
{{- define "kubex-automation-engine.cleanupHookName" -}}
{{- printf "%s-cleanup" .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "kubex-automation-engine.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "kubex-automation-engine.labels" -}}
helm.sh/chart: {{ include "kubex-automation-engine.chart" . }}
{{ include "kubex-automation-engine.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.Version | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "kubex-automation-engine.selectorLabels" -}}
app.kubernetes.io/name: {{ include "kubex-automation-engine.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
control-plane: controller-manager
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "kubex-automation-engine.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "kubex-automation-engine.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the image path
*/}}
{{- define "kubex-automation-engine.image" -}}
{{- $tag := required "image.tag must be set to an immutable controller image tag" .Values.image.tag -}}
{{- printf "%s:%s" .Values.image.repository $tag }}
{{- end }}

{{/*
Create the namespace name
*/}}
{{- define "kubex-automation-engine.namespace" -}}
{{- default .Release.Namespace .Values.namespaceOverride }}
{{- end }}

{{/*
Controller manager container args
*/}}
{{- define "kubex-automation-engine.managerArgs" -}}
{{- if .Values.controllerManager.leaderElection.enabled }}
- --leader-elect
{{- end }}
- --health-probe-bind-address={{ .Values.controllerManager.healthProbeBindAddress }}
{{- if .Values.metrics.enabled }}
- --metrics-bind-address={{ .Values.controllerManager.metricsBindAddress }}
{{- include "kubex-automation-engine.metricsSecureArg" . }}
{{- end }}
{{- range .Values.controllerManager.extraArgs }}
- {{ . }}
{{- end }}
{{- end }}

{{/*
Controller metrics security flag.
*/}}
{{- define "kubex-automation-engine.metricsSecureArg" -}}
{{- if and .Values.metrics.enabled (eq .Values.metrics.serviceMonitor.scheme "http") }}
- --metrics-secure=false
{{- end }}
{{- end }}

{{/*
Generate or retrieve self-signed certificates for webhook
Returns a dict with ca, cert, and key
*/}}
{{- define "kubex-automation-engine.gen-certs-data" -}}
{{- $secretName := printf "%s-webhook-server-cert" (include "kubex-automation-engine.fullname" .) -}}
{{- $secret := lookup "v1" "Secret" (include "kubex-automation-engine.namespace" .) $secretName -}}
{{- if $secret -}}
{{/* Reuse existing certificates */}}
{{- $_ := set . "caCert" (index $secret.data "ca.crt") -}}
{{- $_ := set . "tlsCert" (index $secret.data "tls.crt") -}}
{{- $_ := set . "tlsKey" (index $secret.data "tls.key") -}}
{{- else -}}
{{/* Generate new certificates and cache in context */}}
{{- if not .caCert -}}
{{- $serviceName := printf "%s-webhook-service" (include "kubex-automation-engine.fullname" .) -}}
{{- $namespace := include "kubex-automation-engine.namespace" . -}}
{{- $validity := int .Values.selfSignedCert.validity -}}
{{- $cn := printf "%s.%s.svc" $serviceName $namespace -}}
{{- $altNames := list $serviceName (printf "%s.%s" $serviceName $namespace) (printf "%s.%s.svc" $serviceName $namespace) (printf "%s.%s.svc.cluster.local" $serviceName $namespace) -}}
{{- $ca := genCA "kubex-automation-engine-webhook-ca" $validity -}}
{{- $cert := genSignedCert $cn nil $altNames $validity $ca -}}
{{- $_ := set . "caCert" ($ca.Cert | b64enc) -}}
{{- $_ := set . "tlsCert" ($cert.Cert | b64enc) -}}
{{- $_ := set . "tlsKey" ($cert.Key | b64enc) -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Validate Helm-managed allowedPodOwners values before CR creation so users get a clear chart error.
*/}}
{{- define "kubex-automation-engine.validateAllowedPodOwners" -}}
{{- $supportedOwners := list "Deployment" "StatefulSet" "DaemonSet" "CronJob" "Rollout" "Job" "AnalysisRun" -}}
{{- range $policyName, $policySettings := .Values.policy.policies }}
  {{- if $policySettings.allowedPodOwners }}
    {{- range $rawOwner := splitList "," $policySettings.allowedPodOwners }}
      {{- $owner := trim $rawOwner }}
      {{- if and $owner (not (has $owner $supportedOwners)) }}
        {{- fail (printf "policy.policies.%s.allowedPodOwners contains unsupported workload type %q. Supported values: %s. ReplicaSet is no longer supported; use Deployment instead." $policyName $owner (join ", " $supportedOwners)) }}
      {{- end }}
    {{- end }}
  {{- end }}
{{- end }}
{{- end }}
