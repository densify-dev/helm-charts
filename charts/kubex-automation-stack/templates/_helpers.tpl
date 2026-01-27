{{- define "common.namespace" -}}
  {{- default .Release.Namespace .Values.nsPrefix -}}
{{- end -}}

{{- define "common.clusterName" -}}
  {{- .Values.global.cluster.name -}}
{{- end -}}

{{- define "common.kubexUrlHost" -}}
  {{- .Values.global.kubex.url.host -}}
{{- end -}}

{{- define "stack.normalizedFlavor" -}}
  {{- $stack := .Values.stack | default dict -}}
  {{- $flavor := default "standard" $stack.flavor -}}
  {{- $normalized := lower (printf "%v" $flavor) -}}
  {{- if or (eq $normalized "") (eq $normalized "standard") -}}
    {{- printf "standard" -}}
  {{- else if or (eq $normalized "gkeautopilot") (eq $normalized "gke-autopilot") -}}
    {{- printf "gke-autopilot" -}}
  {{- else if eq $normalized "openshift" -}}
    {{- printf "openshift" -}}
  {{- else -}}
    {{- fail (printf "Unsupported value '%s' for .Values.stack.flavor (allowed: standard, gkeAutopilot, openshift)" $flavor) -}}
  {{- end -}}
{{- end -}}

{{- define "common.checkValues" -}}
{{- /* Parse global.instanceUrl if provided and set global.kubex.url.host */ -}}
{{- if .Values.global.instanceUrl -}}
  {{- $instanceUrl := .Values.global.instanceUrl | trim -}}
  {{- $host := "" -}}
  {{- if hasPrefix "https://" $instanceUrl -}}
    {{- $host = trimPrefix "https://" $instanceUrl -}}
  {{- else if hasPrefix "http://" $instanceUrl -}}
    {{- $host = trimPrefix "http://" $instanceUrl -}}
  {{- else -}}
    {{- $host = $instanceUrl -}}
  {{- end -}}
  {{- /* Remove any trailing path/query */ -}}
  {{- $host = regexReplaceAll "/.*$" $host "" -}}
  {{- /* Set global.kubex.url.host if not already set */ -}}
  {{- if not (hasKey .Values.global "kubex") -}}
    {{- $_ := set .Values.global "kubex" (dict) -}}
  {{- end -}}
  {{- if not (hasKey .Values.global.kubex "url") -}}
    {{- $_ := set .Values.global.kubex "url" (dict) -}}
  {{- end -}}
  {{- $_ := set .Values.global.kubex.url "host" $host -}}
{{- end -}}
{{- /* Check for Kubex URL host - use global */ -}}
{{- $host := include "common.kubexUrlHost" . | trim -}}
{{- if not $host -}}
    {{- fail ".Values.global.kubex.url.host is required" -}}
{{- end -}}
{{- /* Validate the host format */ -}}
{{- $domain := ".densify.com" -}}
{{- $kubexDomain := ".kubex.ai" -}}
{{- $instance := trimSuffix $domain (trimSuffix $kubexDomain $host) -}}
{{- if or (not $instance) (and (eq $instance $host) (not (contains $kubexDomain $host)) (not (contains $domain $host))) -}}
    {{- fail (printf "Kubex URL host '%s' must be in format <instance>.kubex.ai or <instance>.densify.com" $host) -}}
{{- end -}}

{{- /* Parse global.clusterName if provided and set global.cluster.name */ -}}
{{- if .Values.global.clusterName -}}
  {{- if not (hasKey .Values.global "cluster") -}}
    {{- $_ := set .Values.global "cluster" (dict) -}}
  {{- end -}}
  {{- $_ := set .Values.global.cluster "name" .Values.global.clusterName -}}
{{- end -}}

{{- /* Check for cluster name - use global */ -}}
{{- $clusterName := include "common.clusterName" . | trim -}}
{{- if not $clusterName -}}
    {{- fail ".Values.global.cluster.name is required" -}}
{{- end -}}

{{- /* Propagate global credentials to subcharts */ -}}
{{- if .Values.global.credentials -}}
  {{- /* Propagate to kubex-automation-controller if not explicitly set */ -}}
  {{- if (index .Values "kubex-automation-controller" "enabled") -}}
    {{- $controller := index .Values "kubex-automation-controller" -}}
    {{- if not (hasKey $controller "credentials") -}}
      {{- $_ := set $controller "credentials" (dict) -}}
    {{- end -}}
    {{- $controllerCreds := index $controller "credentials" -}}
    {{- if not $controllerCreds.username -}}
      {{- $_ := set $controllerCreds "username" .Values.global.credentials.username -}}
    {{- end -}}
    {{- if not $controllerCreds.epassword -}}
      {{- $_ := set $controllerCreds "epassword" .Values.global.credentials.epassword -}}
    {{- end -}}
  {{- end -}}
  {{- /* Propagate to kubex-data-collector if not explicitly set */ -}}
  {{- if (index .Values "kubex-data-collector" "enabled") -}}
    {{- $collector := index .Values "kubex-data-collector" -}}
    {{- if not (hasKey $collector "credentials") -}}
      {{- $_ := set $collector "credentials" (dict) -}}
    {{- end -}}
    {{- $collectorCreds := index $collector "credentials" -}}
    {{- if not $collectorCreds.username -}}
      {{- $_ := set $collectorCreds "username" .Values.global.credentials.username -}}
    {{- end -}}
    {{- if not $collectorCreds.epassword -}}
      {{- $_ := set $collectorCreds "epassword" .Values.global.credentials.epassword -}}
    {{- end -}}
  {{- end -}}
{{- end -}}

{{- /* Propagate global values to subcharts */ -}}
{{- if (index .Values "kubex-automation-controller" "enabled") -}}
  {{- if not (index .Values "kubex-automation-controller" "cluster" "name") -}}
    {{- $_ := set (index .Values "kubex-automation-controller" "cluster") "name" .Values.global.cluster.name -}}
  {{- end -}}
  {{- $kubexUrl := index .Values "kubex-automation-controller" "config" "kubex" "url" | default dict -}}
  {{- if not $kubexUrl.host -}}
    {{- $_ := set $kubexUrl "host" .Values.global.kubex.url.host -}}
  {{- end -}}
{{- end -}}
{{- if (index .Values "kubex-data-collector" "enabled") -}}
  {{- $collector := index .Values "kubex-data-collector" -}}
  {{- if not $collector -}}
    {{- $_ := set .Values "kubex-data-collector" (dict) -}}
    {{- $collector = index .Values "kubex-data-collector" -}}
  {{- end -}}
  {{- if not (hasKey $collector "config") -}}
    {{- $_ := set $collector "config" (dict) -}}
  {{- end -}}
  {{- $config := index $collector "config" -}}
  {{- if not (hasKey $config "clusters") -}}
    {{- $_ := set $config "clusters" (list) -}}
  {{- end -}}
  {{- $clusters := index $config "clusters" -}}
  {{- if eq (len $clusters) 0 -}}
    {{- $_ := set $config "clusters" (list (dict "name" (include "common.clusterName" .))) -}}
    {{- $clusters = index $config "clusters" -}}
  {{- end -}}
  {{- $firstCluster := index $clusters 0 -}}
  {{- $clusterName := default "" (index $firstCluster "name") -}}
  {{- if eq $clusterName "" -}}
    {{- $_ := set $firstCluster "name" (include "common.clusterName" .) -}}
  {{- end -}}
  {{- if not (hasKey $config "collector") -}}
    {{- $_ := set $config "collector" (dict) -}}
  {{- end -}}
  {{- $collectorConfig := index $config "collector" -}}
  {{- if not (hasKey $collectorConfig "url") -}}
    {{- $_ := set $collectorConfig "url" (dict) -}}
  {{- end -}}
  {{- $collectorUrl := index $collectorConfig "url" -}}
  {{- if not (hasKey $collectorUrl "host") -}}
    {{- $_ := set $collectorUrl "host" .Values.global.kubex.url.host -}}
  {{- end -}}
{{- end -}}

{{- /* Additional validation for data forwarder if enabled */ -}}
{{- if (index .Values "kubex-data-collector" "enabled") -}}
  {{- $clusters := index .Values "kubex-data-collector" "config" "clusters" | default list -}}
  {{- if gt (len $clusters) 0 -}}
    {{- if ne 1 (len $clusters) -}}
        {{- fail ".Values.kubex-data-collector.config.clusters must be a list of size 1 when using this stack chart" -}}
    {{- end -}}
    {{- $cluster := first $clusters -}}
    {{- with $cluster -}}
        {{- if (.identifiers) -}}
            {{- fail ".Values.kubex-data-collector.config.clusters[0].identifiers is forbidden when using this stack chart" -}}
        {{- end -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- include "stack.syncCredentials" . -}}
{{- include "stack.applyFlavorDefaults" . -}}
{{- end -}}

{{- define "stack.syncCredentials" -}}
  {{- $stack := .Values.stack | default dict -}}
  {{- $densify := $stack.densify | default dict -}}
  {{- $collector := index .Values "kubex-data-collector" -}}
  {{- if not $collector -}}
    {{- $_ := set .Values "kubex-data-collector" (dict) -}}
    {{- $collector = index .Values "kubex-data-collector" -}}
  {{- end -}}
  {{- if not (hasKey $collector "credentials") -}}
    {{- $_ := set $collector "credentials" (dict) -}}
  {{- end -}}
  {{- $creds := index $collector "credentials" -}}
  {{- if and ($densify.username) (not $creds.username) -}}
    {{- $_ := set $creds "username" $densify.username -}}
  {{- end -}}
  {{- if and ($densify.encrypted_password) (not $creds.epassword) -}}
    {{- $_ := set $creds "epassword" $densify.encrypted_password -}}
  {{- end -}}
  {{- if and ($stack.densify) (hasKey $stack.densify "createSecret") -}}
    {{- $_ := set .Values.global "createSecret" $stack.densify.createSecret -}}
  {{- end -}}
{{- end -}}

{{- define "stack.disablePrometheus" -}}
  {{- $prom := .Values.prometheus -}}
  {{- if not $prom -}}
    {{- $_ := set .Values "prometheus" (dict) -}}
    {{- $prom = .Values.prometheus -}}
  {{- end -}}
  {{- $_ := set $prom "enabled" false -}}
{{- end -}}

{{- define "stack.enableKubeStateMetrics" -}}
  {{- $ksm := index .Values "kube-state-metrics" -}}
  {{- if not $ksm -}}
    {{- $_ := set .Values "kube-state-metrics" (dict) -}}
    {{- $ksm = index .Values "kube-state-metrics" -}}
  {{- end -}}
  {{- $_ := set $ksm "enabled" true -}}
{{- end -}}

{{- define "stack.applyGkeAutopilotDefaults" -}}
  {{- $stack := .Values.stack | default dict -}}
  {{- $runsInCluster := default true $stack.runsInGKEAutopilot -}}
  {{- $gkeAutopilot := $stack.gkeAutopilot | default dict -}}
  {{- $collector := index .Values "kubex-data-collector" -}}
  {{- if not $collector -}}
    {{- $_ := set .Values "kubex-data-collector" (dict) -}}
    {{- $collector = index .Values "kubex-data-collector" -}}
  {{- end -}}
  {{- if not (hasKey $collector "job") -}}
    {{- $_ := set $collector "job" (dict) -}}
  {{- end -}}
  {{- $jobSettings := index $collector "job" -}}
  {{- $_ := set $jobSettings "checkPrometheusReady" false -}}
  {{- if $runsInCluster -}}
    {{- include "stack.enableKubeStateMetrics" . -}}
    {{- if not (hasKey $collector "serviceAccount") -}}
      {{- $_ := set $collector "serviceAccount" (dict) -}}
    {{- end -}}
    {{- $sa := index $collector "serviceAccount" -}}
    {{- if not (hasKey $sa "isGKE") -}}
      {{- $_ := set $sa "isGKE" true -}}
    {{- end -}}
    {{- if and $gkeAutopilot.serviceAccountName (not $sa.name) -}}
      {{- $_ := set $sa "name" $gkeAutopilot.serviceAccountName -}}
    {{- end -}}
  {{- else -}}
    {{- $ksm := index .Values "kube-state-metrics" -}}
    {{- if $ksm -}}
      {{- $_ := set $ksm "enabled" false -}}
    {{- end -}}
  {{- end -}}
{{- end -}}

{{- define "stack.applyOpenShiftCollectorDefaults" -}}
  {{- $collector := index .Values "kubex-data-collector" -}}
  {{- if not $collector -}}
    {{- $_ := set .Values "kubex-data-collector" (dict) -}}
    {{- $collector = index .Values "kubex-data-collector" -}}
  {{- end -}}
  {{- $_ := set $collector "assignedUIDs" true -}}
  {{- if not (hasKey $collector "rbac") -}}
    {{- $_ := set $collector "rbac" (dict) -}}
  {{- end -}}
  {{- $rbac := index $collector "rbac" -}}
  {{- $_ := set $rbac "create" true -}}
  {{- if not (hasKey $collector "serviceAccount") -}}
    {{- $_ := set $collector "serviceAccount" (dict) -}}
  {{- end -}}
  {{- $sa := index $collector "serviceAccount" -}}
  {{- $openshift := (index (.Values.stack | default dict) "openshift") | default dict -}}
  {{- if and $openshift.image (not $collector.image) -}}
    {{- $_ := set $collector "image" $openshift.image -}}
  {{- end -}}
  {{- if not (hasKey $collector "job") -}}
    {{- $_ := set $collector "job" (dict) -}}
  {{- end -}}
  {{- $jobSettings := index $collector "job" -}}
  {{- $_ := set $jobSettings "checkPrometheusReady" false -}}
  {{- $_ := set $sa "create" true -}}
  {{- if not $sa.name -}}
    {{- $_ := set $sa "name" (default "kubex-collection" $openshift.serviceAccountName) -}}
  {{- end -}}
  {{- if not (hasKey $collector "config") -}}
    {{- $_ := set $collector "config" (dict) -}}
  {{- end -}}
  {{- $config := index $collector "config" -}}
  {{- if not (hasKey $config "prometheus") -}}
    {{- $_ := set $config "prometheus" (dict) -}}
  {{- end -}}
  {{- $prom := index $config "prometheus" -}}
  {{- if not (hasKey $prom "url") -}}
    {{- $_ := set $prom "url" (dict) -}}
  {{- end -}}
  {{- $url := index $prom "url" -}}
  {{- if not $url.scheme -}}
    {{- $_ := set $url "scheme" (default "https" $openshift.prometheus.scheme) -}}
  {{- end -}}
  {{- if not $url.host -}}
    {{- $_ := set $url "host" (default "prometheus-k8s.openshift-monitoring.svc" $openshift.prometheus.host) -}}
  {{- end -}}
  {{- if not (hasKey $url "port") -}}
    {{- $_ := set $url "port" (default 9091 $openshift.prometheus.port) -}}
  {{- end -}}
  {{- if not (hasKey $prom "ca_cert") -}}
    {{- $_ := set $prom "ca_cert" (default "/var/run/secrets/kubernetes.io/serviceaccount/service-ca.crt" $openshift.prometheus.caCert) -}}
  {{- end -}}
{{- end -}}

{{- define "stack.applyFlavorDefaults" -}}
  {{- $flavor := include "stack.normalizedFlavor" . -}}
  {{- if eq $flavor "gke-autopilot" -}}
    {{- include "stack.disablePrometheus" . -}}
    {{- include "stack.applyGkeAutopilotDefaults" . -}}
  {{- else if eq $flavor "openshift" -}}
    {{- include "stack.disablePrometheus" . -}}
    {{- include "stack.applyOpenShiftCollectorDefaults" . -}}
    {{- include "stack.applyOpenShiftAutomationDefaults" . -}}
  {{- end -}}
{{- end -}}

{{- define "stack.applyOpenShiftAutomationDefaults" -}}
  {{- if (index .Values "kubex-automation-controller" "enabled") -}}
    {{- $controller := index .Values "kubex-automation-controller" -}}
    {{- if not (hasKey $controller "deployment") -}}
      {{- $_ := set $controller "deployment" (dict) -}}
    {{- end -}}
    {{- $deployment := index $controller "deployment" -}}
    {{- $_ := set $deployment "assignedUIDs" true -}}
    {{- if not (hasKey $controller "valkey") -}}
      {{- $_ := set $controller "valkey" (dict) -}}
    {{- end -}}
    {{- $valkey := index $controller "valkey" -}}
    {{- $_ := set $valkey "assignedUIDs" true -}}
    {{/* Override valkey podSecurityContext for OpenShift - keep only runAsNonRoot */}}
    {{- $_ := set $valkey "podSecurityContext" (dict "runAsNonRoot" true) -}}
    {{- $_ := set $valkey "securityContext" (dict "allowPrivilegeEscalation" false "privileged" false "readOnlyRootFilesystem" true "runAsNonRoot" true "capabilities" (dict "drop" (list "ALL"))) -}}
  {{- end -}}
{{- end -}}
