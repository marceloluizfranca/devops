#!/usr/bin/env bash
# Instala o ARC (controller + scale set da clima-api) no cluster kind.
# Uso: GITHUB_TOKEN=<fine-grained PAT> ./install.sh
set -euo pipefail
cd "$(dirname "$0")"

CONTEXTO="${KUBE_CONTEXT:-kind-splic}"
VERSAO_ARC="0.15.0"
CHARTS="oci://ghcr.io/actions/actions-runner-controller-charts"

: "${GITHUB_TOKEN:?defina GITHUB_TOKEN com um fine-grained PAT (Administration: read/write no repositório)}"

helm upgrade --install arc "$CHARTS/gha-runner-scale-set-controller" \
  --kube-context "$CONTEXTO" --namespace arc-systems --create-namespace \
  --version "$VERSAO_ARC" --values controller-values.yaml --wait

kubectl --context "$CONTEXTO" create namespace arc-runners --dry-run=client -o yaml \
  | kubectl --context "$CONTEXTO" apply -f -
kubectl --context "$CONTEXTO" apply -f rbac/clima-deployer.yaml

# Recria o secret a cada execução para permitir a troca do token
kubectl --context "$CONTEXTO" -n arc-runners create secret generic github-token \
  --from-literal=github_token="$GITHUB_TOKEN" --dry-run=client -o yaml \
  | kubectl --context "$CONTEXTO" apply -f -

helm upgrade --install arc-splic "$CHARTS/gha-runner-scale-set" \
  --kube-context "$CONTEXTO" --namespace arc-runners \
  --version "$VERSAO_ARC" --values runner-set-clima-api.yaml --wait

kubectl --context "$CONTEXTO" -n arc-systems get pods
