# devops

Guia da plataforma Kubernetes local `splic`: o que está instalado no cluster, como reinstalar cada componente e como uma aplicação passa a usar a plataforma.

Cada componente tem um diretório com a configuração versionada (values do Helm e manifests) e um README com os comandos de instalação, validação e operação.

## Inventário

| Componente | Diretório | Chart / origem | Versão | Namespace |
|---|---|---|---|---|
| Cluster kind | [`kind/`](kind/) | kind | Kubernetes v1.37 | — |
| Prometheus Operator, Prometheus, node-exporter, kube-state-metrics | [`prometheus/`](prometheus/) | `prometheus-community/kube-prometheus-stack` | 92.10.1 | `monitoring` |
| Grafana | [`grafana/`](grafana/) | `grafana-community/grafana` | 14.0.1 (Grafana 13.2) | `monitoring` |
| Actions Runner Controller | [`github-runners/`](github-runners/) | `oci://ghcr.io/actions/actions-runner-controller-charts` | 0.15.0 | `arc-systems`, `arc-runners` |

## Arquitetura

```
                       GitHub
     ┌────────────────────────────────────────┐
     │  workflow: testes → imagem → deploy    │──── push da imagem ────▶ ghcr.io
     │                                ▲       │                            │
     └────────────────────────────────┼───────┘                            │
                                      │ o runner busca o job (HTTPS de saída)
 ┌─ cluster kind "splic" ─────────────┼──────────────────────────────┐     │
 │                                    │                              │     │
 │  arc-systems    controller do ARC  │                              │     │
 │  arc-runners    listener + pods de runner efêmeros ───┐           │     │
 │                                             kubectl apply         │     │
 │  <aplicação>    Deployment, Service, ServiceMonitor ◀─┘ ◀─────────────────┘ pull
 │                    ▲ /metrics                                     │
 │  monitoring     Prometheus ──▶ Grafana (:30300)                   │
 └───────────────────────────────────────────────────────────────────┘
```

Pontos principais:

- **O cluster não precisa ser acessível pela internet.** O runner abre a conexão com o GitHub para buscar jobs; o GitHub nunca chama o cluster.
- **Nenhum kubeconfig fica no GitHub.** O pod do runner usa uma ServiceAccount com permissão só no namespace da aplicação.
- **O build da imagem não roda no cluster.** Ele roda em runners hospedados pelo GitHub; os runners do cluster só fazem deploy, sem Docker-in-Docker nem pods privilegiados.
- **Cada aplicação declara o próprio monitoramento** (ServiceMonitor, PrometheusRule e dashboard). A plataforma descobre esses recursos em qualquer namespace.

## Instalação do zero

A ordem importa: o Prometheus instala as CRDs (`ServiceMonitor`, `PrometheusRule`) que as aplicações usam.

1. [Criar o cluster](kind/README.md)
2. [Instalar o Prometheus](prometheus/README.md)
3. [Instalar o Grafana e os dashboards da plataforma](grafana/README.md)
4. [Instalar o controller do ARC](github-runners/README.md#instalação-do-controller)

Os comandos são executados a partir da raiz deste repositório e usam `--kube-context kind-splic`, para evitar aplicar algo em outro cluster por engano.

### Requisitos

Docker (ou OrbStack), kind, kubectl e Helm 3.8 ou superior (necessário para charts OCI).

## Acessos

| Serviço | Endereço |
|---|---|
| Grafana | http://localhost:30300, usuário `admin` (senha em [grafana/](grafana/README.md#senha-do-admin)) |
| Prometheus | `kubectl --context kind-splic -n monitoring port-forward svc/prometheus-operated 9090`, depois http://localhost:9090 |
| Aplicações | NodePort `30080`, mapeado em http://localhost:30080 |

## Integrar uma aplicação à plataforma

Checklist para um novo repositório:

1. **Namespace e permissões de deploy.** Criar o namespace e um RoleBinding para o `ClusterRole` `arc-deployer`. Ver [github-runners](github-runners/README.md#adicionar-um-repositório).
2. **Runner scale set.** Instalar um scale set apontando para o repositório e usar o nome dele em `runs-on` no workflow.
3. **Métricas.** Expor `/metrics` e incluir um `ServiceMonitor` nos manifests da aplicação. Ver [prometheus](prometheus/README.md#monitorar-uma-aplicação).
4. **Alertas.** Opcionalmente, incluir um `PrometheusRule` nos manifests.
5. **Dashboard.** Opcionalmente, incluir um ConfigMap com o label `grafana_dashboard: "1"`. Ver [grafana](grafana/README.md#adicionar-um-dashboard-de-aplicação). O consumo de recursos da aplicação já aparece no dashboard *Recursos dos pods*, filtrando pelo namespace.

## Convenções

- **Configuração versionada.** Todo componente é instalado com Helm a partir dos values deste repositório. Mudanças feitas direto no cluster são sobrescritas no próximo `helm upgrade`.
- **Versões fixas.** Toda versão de chart é fixada no README do componente. Para atualizar, troque a versão no README e rode o `helm upgrade` documentado.
- **Segredos fora do Git.** Tokens e senhas são criados com `kubectl create secret` e nunca versionados.
- **Commits** seguem o [Conventional Commits](https://www.conventionalcommits.org/pt-br/) e as versões seguem o [SemVer](https://semver.org/lang/pt-BR/).
