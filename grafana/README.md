# grafana

Grafana no namespace `monitoring`, com datasource e dashboards provisionados por código.

| Item | Valor |
|---|---|
| Chart | `grafana-community/grafana` |
| Versão | `14.0.1` (Grafana 13.2) |
| Release | `grafana` |
| Namespace | `monitoring` |
| Acesso | http://localhost:30300 (NodePort `30300`) |

O chart oficial do Grafana foi transferido do repositório `grafana` para o `grafana-community`. O repositório antigo parou de receber versões.

## Decisões de configuração

- **Datasource provisionado.** O Prometheus (`http://prometheus-operated.monitoring.svc:9090`) é o datasource padrão, com uid `prometheus`. Dashboards podem referenciá-lo por esse uid.
- **Dashboards por ConfigMap.** Um sidecar carrega todo ConfigMap com o label `grafana_dashboard: "1"` em qualquer namespace. A anotação `grafana_folder` define a pasta.
- **Sem persistência.** Tudo é provisionado por código. Ao reiniciar o pod, o Grafana volta ao estado do repositório: mudanças feitas pela interface (inclusive a troca de senha) se perdem.
- **Memória com limite de 1Gi.** O chart define `GOMEMLIMIT` como 90% do limite. Com limites baixos (384Mi), o Grafana 13 ultrapassa esse valor, entra em coleta de lixo contínua e para de responder.

## Instalação

```bash
helm repo add grafana-community https://grafana-community.github.io/helm-charts
helm repo update grafana-community

# Senha do admin: criada uma única vez, fora do Git
kubectl --context kind-splic create namespace monitoring --dry-run=client -o yaml \
  | kubectl --context kind-splic apply -f -
kubectl --context kind-splic -n monitoring create secret generic grafana-admin \
  --from-literal=admin-user=admin \
  --from-literal=admin-password="$(openssl rand -base64 18)"

helm upgrade --install grafana grafana-community/grafana \
  --kube-context kind-splic --namespace monitoring \
  --version 14.0.1 --values grafana/values.yaml --wait
```

Em atualizações, rode só o `helm upgrade`. O Secret já existe.

Por fim, publique os dashboards da plataforma:

```bash
kubectl --context kind-splic apply -k grafana/dashboards
```

## Senha do admin

```bash
kubectl --context kind-splic -n monitoring get secret grafana-admin \
  -o jsonpath='{.data.admin-password}' | base64 -d
```

Para trocar a senha de forma permanente, atualize o Secret e reinicie o pod. Uma troca feita só pela interface se perde no próximo restart.

```bash
kubectl --context kind-splic -n monitoring create secret generic grafana-admin \
  --from-literal=admin-user=admin --from-literal=admin-password='<nova-senha>' \
  --dry-run=client -o yaml | kubectl --context kind-splic apply -f -
kubectl --context kind-splic -n monitoring rollout restart deploy/grafana
```

## Validação

```bash
kubectl --context kind-splic -n monitoring get pods -l app.kubernetes.io/name=grafana
```

O pod deve estar `2/2 Running`. Na interface, em *Connections → Data sources → Prometheus*, o botão *Save & test* deve retornar "Successfully queried the Prometheus API".

## Dashboards da plataforma

Ficam em `dashboards/` e são publicados na pasta *Plataforma* pelo `kubectl apply -k` acima. O kustomize gera um ConfigMap por arquivo, já com o label e a pasta.

| Dashboard | Conteúdo |
|---|---|
| **Recursos dos pods** (`recursos-pods.json`) | Pods prontos, restarts, CPU e memória em uso comparados a requests e limites, tráfego de rede e uma tabela de uso x requests x limites por container. Tem filtros de namespace e pod. |

Os dashboards padrão do kube-prometheus-stack (Kubernetes, node-exporter, Prometheus) também ficam disponíveis, na pasta *General*.

O dashboard de recursos aceita o namespace na URL, para links a partir de dashboards das aplicações: `/d/recursos-pods/recursos-dos-pods?var-namespace=<namespace>`.

Para alterar um dashboard da plataforma, edite na interface, exporte o JSON (*Export → Export as JSON*), substitua o arquivo em `dashboards/` e rode o `kubectl apply -k` de novo.

## Adicionar um dashboard de aplicação

Monte o dashboard na interface e exporte o JSON (*Share → Export*). Depois publique o JSON como ConfigMap no namespace da aplicação:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: <aplicacao>-dashboard
  labels:
    grafana_dashboard: "1"
  annotations:
    grafana_folder: Aplicações
data:
  <aplicacao>.json: |
    { ... JSON exportado ... }
```

O sidecar carrega o dashboard em poucos segundos, sem reiniciar o Grafana. Use o datasource com uid `prometheus` no JSON.

## Problemas comuns

| Sintoma | Causa provável |
|---|---|
| Interface não carrega, pod `1/2` | Falta de memória: compare o uso com o `GOMEMLIMIT` do container |
| Dashboard não aparece | ConfigMap sem o label `grafana_dashboard: "1"`. Veja os logs do sidecar: `kubectl -n monitoring logs deploy/grafana -c grafana-sc-dashboard` |
| Senha não funciona após restart | A senha foi trocada pela interface; vale a do Secret `grafana-admin` |
