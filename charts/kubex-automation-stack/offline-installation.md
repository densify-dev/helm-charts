# Installing kubex-automation-stack via Helm Offline Installation

Follow these steps to install the `kubex-automation-stack` from the Densify Helm repository:

---

1. Add the Densify Helm repository on a machine with internet access:

    ```sh
    helm repo add densify https://densify-dev.github.io/helm-charts
    ```

2. Pull the `kubex-automation-stack` chart on a machine with internet access:

    ```sh
    helm pull densify/kubex-automation-stack
    ```

3. Extract the downloaded chart `kubex-automation-stack-<version>.tgz`

4. Determine the sizing file as described in [Sizing](https://github.com/densify-dev/helm-charts/blob/master/charts/kubex-automation-stack/README.md#Sizing)

5. Edit `kubex-automation-stack/values-edit.yaml` as described in [Configuration](https://github.com/densify-dev/helm-charts/blob/master/charts/kubex-automation-stack/README.md#Configuration)

6. Transfer the `kubex-automation-stack` directory to the target Kubernetes cluster where you want to install the chart.

7. If your cluster has amd64 architecture, install the Helm chart using the custom values file:

    ```sh
    cd kubex-automation-stack
    helm install --create-namespace -n kubex -f values-edit.yaml -f <sizing file> kubex .
    ```

8. If your cluster has arm64 architecture, install the Helm chart using the custom values file:

    ```sh
    cd kubex-automation-stack
    helm install --create-namespace -n kubex -f values-edit.yaml -f <sizing file> -f values-arm64.yaml kubex .
    ```

---
