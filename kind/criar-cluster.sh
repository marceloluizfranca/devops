#!/usr/bin/env bash
# Cria o cluster kind "splic" se ele ainda não existir
set -euo pipefail
cd "$(dirname "$0")"

if kind get clusters | grep -qx splic; then
  echo "cluster splic já existe"
else
  kind create cluster --config splic.yaml
fi
kubectl --context kind-splic wait --for=condition=Ready nodes --all --timeout=180s
