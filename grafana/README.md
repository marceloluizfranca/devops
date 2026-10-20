# grafana

Grafana no namespace `monitoring`, instalado com o chart [grafana-community/grafana](https://github.com/grafana-community/helm-charts). Tudo é provisionado por código: datasource, dashboards e senha do admin.

## Como os dashboards são carregados

Um sidecar no pod do Grafana observa ConfigMaps com o label `grafana_dashboard=1` no namespace `monitoring` e carrega cada um como dashboard. Há duas origens:

- **Dashboards do cluster** (Kubernetes, node-exporter, Prometheus): publicados pelo kube-prometheus-stack.
- **Dashboards das aplicações**: cada JSON em `dashboards/` vira um ConfigMap no `install.sh` e aparece na pasta *Aplicações*.

Para adicionar um dashboard, salve o JSON em `dashboards/` e rode o `install.sh` de novo.

## Dashboard da clima-api

`dashboards/clima-api.json` mostra:

- requisições por segundo
- taxa de erro 5xx
- latência p50, p95 e p99
- falhas na Open-Meteo
- réplicas disponíveis
- CPU e memória por pod

## Instalação

```bash
./install.sh
```

O script cria o Secret `grafana-admin` com uma senha aleatória na primeira execução e a exibe no final. Para consultar depois:

```bash
kubectl -n monitoring get secret grafana-admin -o jsonpath='{.data.admin-password}' | base64 -d
```

## Acesso

http://localhost:30300. A porta 30300 do Service é mapeada para o host na configuração do kind.

## Validação

Em *Connections → Data sources → Prometheus*, clique em *Save & test*: deve aparecer "Successfully queried the Prometheus API".
