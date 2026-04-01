diff --git a/charts/kubex-automation-engine/templates/validatingwebhook.yaml b/charts/kubex-automation-engine/templates/validatingwebhook.yaml
index 2e47e63..09d8470 100644
--- a/charts/kubex-automation-engine/templates/validatingwebhook.yaml
+++ b/charts/kubex-automation-engine/templates/validatingwebhook.yaml
@@ -23,13 +23,15 @@ webhooks:
       namespace: {{ include "kubex-automation-engine.namespace" . }}
       path: /validate-rightsizing-kubex-ai-v1alpha1-automationstrategy
   failurePolicy: {{ .Values.webhook.failurePolicy }}
-  name: vautomationstrategydelete-v1alpha1.kb.io
+  name: vautomationstrategy-v1alpha1.kb.io
   rules:
   - apiGroups:
     - rightsizing.kubex.ai
     apiVersions:
     - v1alpha1
     operations:
+    - CREATE
+    - UPDATE
     - DELETE
     resources:
     - automationstrategies
@@ -45,13 +47,15 @@ webhooks:
       namespace: {{ include "kubex-automation-engine.namespace" . }}
       path: /validate-rightsizing-kubex-ai-v1alpha1-clusterautomationstrategy
   failurePolicy: {{ .Values.webhook.failurePolicy }}
-  name: vclusterautomationstrategydelete-v1alpha1.kb.io
+  name: vclusterautomationstrategy-v1alpha1.kb.io
   rules:
   - apiGroups:
     - rightsizing.kubex.ai
     apiVersions:
     - v1alpha1
     operations:
+    - CREATE
+    - UPDATE
     - DELETE
     resources:
     - clusterautomationstrategies
