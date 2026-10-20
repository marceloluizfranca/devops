# prometheus

[kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack) no namespace `monitoring`: Prometheus Operator, Prometheus, node-exporter e kube-state-metrics.

## Decisões

- **Grafana desligado.** Ele é instalado separadamente pelo diretório [`grafana/`](../grafana/). Com `forceDeployDashboards: true`, este chart continua publicando os dashboards padrão como ConfigMaps, que o Grafana carrega automaticamente.
- **Sem Alertmanager.** É uma demo local, então os alertas são vistos na tela *Alerts* do Prometheus.
- **etcd, controller-manager, scheduler e kube-proxy não são coletados.** No kind esses componentes escutam só em `127.0.0.1` e apareceriam como targets fora do ar, com alertas falsos.
- **Descoberta em todos os namespaces.** Os `*SelectorNilUsesHelmValues: false` fazem o Prometheus pegar qualquer `ServiceMonitor` ou `PrometheusRule`, sem exigir o label `release`. É assim que o ServiceMonitor da clima-api é encontrado.
- **Retenção de 2 dias**, suficiente para a demo.

## Alertas da clima-api

Definidos em `regras/clima-api.yaml`:

| Alerta | Condição |
|---|---|
| `ClimaApiTaxaDeErroAlta` | Mais de 5% de respostas 5xx por 5 min |
| `ClimaApiOpenMeteoFalhando` | Mais de 5 falhas na Open-Meteo em 5 min |
| `ClimaApiLatenciaAlta` | p95 acima de 2s por 10 min |
| `ClimaApiSemReplicas` | Nenhuma réplica disponível por 2 min |

## Instalação

```bash
./install.sh
```

## Validação

```bash
kubectl -n monitoring port-forward svc/prometheus-operated 9090
```

Abra http://localhost:9090/targets: todos os targets devem estar `UP`. Em *Alerts*, só o `Watchdog` deve estar disparando, porque ele existe para estar sempre ativo e provar que o pipeline de alertas funciona.
