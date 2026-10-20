# prometheus

[kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack) no namespace `monitoring`.

| Item | Valor |
|---|---|
| Chart | `prometheus-community/kube-prometheus-stack` |
| Versão | `92.10.1` |
| Release | `prometheus` |
| Namespace | `monitoring` |

## O que é instalado

| Componente | Função |
|---|---|
| Prometheus Operator | Gerencia o Prometheus a partir de CRDs (`ServiceMonitor`, `PodMonitor`, `PrometheusRule`) |
| Prometheus | Coleta e armazena métricas e avalia as regras de alerta |
| node-exporter | Métricas dos nós (CPU, memória, disco, rede) |
| kube-state-metrics | Métricas de estado dos objetos do Kubernetes (deployments, pods, réplicas) |
| Regras e dashboards padrão | Alertas e dashboards de cluster mantidos pela comunidade |

## Decisões de configuração

- **Grafana desligado.** O Grafana é instalado separadamente, pelo diretório [`grafana/`](../grafana/). Com `forceDeployDashboards: true`, este chart continua publicando os dashboards padrão como ConfigMaps, que o Grafana carrega automaticamente.
- **Sem Alertmanager.** Os alertas são consultados na tela *Alerts* do Prometheus. Para notificar (Slack, e-mail), habilite `alertmanager.enabled` e configure os receivers.
- **etcd, controller-manager, scheduler e kube-proxy não são coletados.** No kind esses componentes escutam só em `127.0.0.1`. Coletá-los geraria targets fora do ar e alertas falsos.
- **Descoberta em todos os namespaces.** Com `*SelectorNilUsesHelmValues: false`, o Prometheus carrega qualquer `ServiceMonitor`, `PodMonitor` ou `PrometheusRule` do cluster, sem exigir o label `release`.
- **Retenção de 2 dias** e requests baixos, adequados a um cluster local.

## Instalação

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update prometheus-community

helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  --kube-context kind-splic --namespace monitoring --create-namespace \
  --version 92.10.1 --values prometheus/values.yaml --wait --timeout 10m
```

O mesmo comando aplica mudanças no `values.yaml` e atualiza a versão.

## Validação

```bash
kubectl --context kind-splic -n monitoring get pods
kubectl --context kind-splic -n monitoring port-forward svc/prometheus-operated 9090
```

Em http://localhost:9090:

- **Status → Targets:** todos os targets devem estar `UP`.
- **Alerts:** só o `Watchdog` deve estar disparando. Ele existe para estar sempre ativo e provar que a avaliação de alertas funciona.

## Monitorar uma aplicação

A aplicação expõe métricas em `/metrics` e inclui um `ServiceMonitor` nos próprios manifests, no namespace dela:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: <aplicacao>
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: <aplicacao>   # labels do Service
  endpoints:
    - port: http                            # nome da porta no Service
      path: /metrics
      interval: 15s
```

Alertas seguem o mesmo modelo, com um `PrometheusRule` no namespace da aplicação. Os dois são descobertos automaticamente, em até um minuto.

Se você usa kustomize, declare o `spec.selector` explicitamente: a opção `labels` com `includeSelectors` não preenche selectors de CRDs.

## Problemas comuns

| Sintoma | Causa provável |
|---|---|
| Target da aplicação não aparece | `ServiceMonitor` sem `spec.selector`, ou labels que não batem com o Service |
| Target aparece como `DOWN` | Nome da porta no `ServiceMonitor` diferente do Service, ou `/metrics` respondendo com redirect |
| Regra não aparece em *Alerts* | Erro de sintaxe no `PrometheusRule`. Veja os logs do operator: `kubectl -n monitoring logs deploy/prometheus-kube-prometheus-operator` |
