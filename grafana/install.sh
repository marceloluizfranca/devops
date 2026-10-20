#!/usr/bin/env bash
# Instala o Grafana e os dashboards deste diretório.
set -euo pipefail
cd "$(dirname "$0")"

CONTEXTO="${KUBE_CONTEXT:-kind-splic}"
VERSAO_CHART="14.0.1"
K="kubectl --context $CONTEXTO -n monitoring"

helm repo add grafana-community https://grafana-community.github.io/helm-charts >/dev/null
helm repo update grafana-community >/dev/null

kubectl --context "$CONTEXTO" create namespace monitoring --dry-run=client -o yaml \
  | kubectl --context "$CONTEXTO" apply -f -

# Gera a senha do admin só na primeira instalação
if ! $K get secret grafana-admin >/dev/null 2>&1; then
  $K create secret generic grafana-admin \
    --from-literal=admin-user=admin \
    --from-literal=admin-password="$(openssl rand -base64 18)"
fi

# Cada JSON em dashboards/ vira um ConfigMap na pasta "Aplicações"
for arquivo in dashboards/*.json; do
  nome="dashboard-$(basename "$arquivo" .json)"
  $K create configmap "$nome" --from-file="$arquivo" --dry-run=client -o yaml | $K apply -f -
  $K label configmap "$nome" grafana_dashboard=1 --overwrite
  $K annotate configmap "$nome" grafana_folder=Aplicações --overwrite
done

helm upgrade --install grafana grafana-community/grafana \
  --kube-context "$CONTEXTO" --namespace monitoring \
  --version "$VERSAO_CHART" --values values.yaml --wait

echo
echo "Grafana: http://localhost:30300"
echo "Usuário: admin"
echo "Senha:   $($K get secret grafana-admin -o jsonpath='{.data.admin-password}' | base64 -d)"
