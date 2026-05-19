{{/*
Create the image repository to use
*/}}
{{- define "gpu-process-exporter.imageRepository" -}}
{{- default "densify/gpu-process-exporter" .Values.image.repository }}
{{- end }}
{{/*
Create the image tag to use
*/}}
{{- define "gpu-process-exporter.imageTag" -}}
{{- required "image.tag is required" .Values.image.tag }}
{{- end }}
{{/*
Create the image pull policy to use
*/}}
{{- define "gpu-process-exporter.imagePullPolicy" -}}
{{- default "Always" .Values.image.pullPolicy }}
{{- end }}
{{/*
Create the name of the service account to use
*/}}
{{- define "gpu-process-exporter.serviceAccountName" -}}
{{- $serviceAccount := default dict .Values.serviceAccount -}}
{{- if and (hasKey $serviceAccount "create") (eq $serviceAccount.create false) -}}
{{- required "serviceAccount.name is required when serviceAccount.create is false" $serviceAccount.name }}
{{- else -}}
{{- default "gpu-process-exporter" $serviceAccount.name }}
{{- end }}
{{- end }}
{{/*
Create the cluster role name to use
*/}}
{{- define "gpu-process-exporter.clusterRoleName" -}}
{{- default "gpu-exporter-role" .Values.rbac.clusterRoleName }}
{{- end }}
{{/*
Create the cluster role binding name to use
*/}}
{{- define "gpu-process-exporter.clusterRoleBindingName" -}}
{{- default "gpu-exporter-binding" .Values.rbac.clusterRoleBindingName }}
{{- end }}
{{/*
Create the Prometheus scrape interval to use
*/}}
{{- define "gpu-process-exporter.prometheusScrapeInterval" -}}
{{- default "20s" .Values.prometheusScrape.interval }}
{{- end }}
{{/*
Create the port to use by the container and service
*/}}
{{- define "gpu-process-exporter.port" -}}
{{- default 9494 .Values.port }}
{{- end }}
{{/*
Create the service type to use
*/}}
{{- define "gpu-process-exporter.serviceType" -}}
{{- default "ClusterIP" .Values.service.type }}
{{- end }}
{{/*
Create the host proc mount to use by the container
*/}}
{{- define "gpu-process-exporter.hostProcMount" -}}
{{- default "/proc" .Values.hostProcMount }}
{{- end }}
