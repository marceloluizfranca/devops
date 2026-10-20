#!/usr/bin/env bash
# Instala o kube-prometheus-stack (sem Grafana) e as regras de alerta.
set -euo pipefail
cd "$(dirname "$0")"

CONTEXTO="${KUBE_CONTEXT:-kind-splic}"
VERSAO_CHART="92.10.1"

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null
helm repo update prometheus-community >/dev/null

helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  --kube-context "$CONTEXTO" --namespace monitoring --create-namespace \
  --version "$VERSAO_CHART" --values values.yaml --wait --timeout 10m

kubectl --context "$CONTEXTO" apply -f regras/

kubectl --context "$CONTEXTO" -n monitoring get pods
