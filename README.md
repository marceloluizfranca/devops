# devops

Infraestrutura do ambiente de demonstração: um cluster Kubernetes local ([kind](https://kind.sigs.k8s.io/)) com runners self-hosted do GitHub Actions e uma stack de monitoramento. Cada ferramenta fica em seu próprio diretório, com os values do Helm, um `install.sh` idempotente e um README.

| Diretório | O que instala |
|---|---|
| [`kind/`](kind/) | Cluster `splic`: 1 control-plane + 1 worker |
| [`prometheus/`](prometheus/) | kube-prometheus-stack (Prometheus Operator, Prometheus, node-exporter, kube-state-metrics) e as regras de alerta |
| [`grafana/`](grafana/) | Grafana com datasource e dashboards provisionados por código |
| [`github-runners/`](github-runners/) | Actions Runner Controller (ARC) e o scale set que faz deploy da [clima-api](https://github.com/marceloluizfranca/clima-api) |

## Arquitetura

```
                         GitHub
        ┌──────────────────────────────────────┐
        │  clima-api: push → testes → imagem   │──── push da imagem ───▶ ghcr.io
        │                           │          │                            │
        │                     job "deploy"     │                            │
        └───────────────────────────▲──────────┘                            │
                                    │ o runner busca o job (HTTPS de saída)  │
  ┌─ cluster kind "splic" ──────────┼────────────────────────────────────┐   │
  │                                 │                                    │   │
  │  arc-systems   controller do ARC                                     │   │
  │  arc-runners   listener + pods de runner (SA clima-deployer) ──┐     │   │
  │                                                     kubectl apply    │   │
  │  clima         clima-api (2 réplicas) ◀────────────────────────┘ ◀───────┘ pull
  │                    ▲ /metrics                                        │
  │  monitoring    Prometheus ──▶ Grafana (:30300)                       │
  └──────────────────────────────────────────────────────────────────────┘
```

O cluster não precisa estar acessível pela internet: o runner é quem abre a conexão com o GitHub para buscar jobs. O deploy usa a ServiceAccount do pod do runner, com permissão restrita ao namespace `clima`, então nenhum kubeconfig fica guardado no GitHub.

## Ordem de instalação

A ordem importa: o Prometheus instala as CRDs (como `ServiceMonitor`) usadas pela aplicação, e o diretório dos runners cria o namespace `clima` e as permissões de deploy.

```bash
./kind/criar-cluster.sh
./prometheus/install.sh
./grafana/install.sh
GITHUB_TOKEN=<token> ./github-runners/install.sh
```

Depois disso, qualquer push na `main` da clima-api faz o deploy no cluster.

Todos os scripts usam o contexto `kind-splic` por padrão. Para outro cluster, defina `KUBE_CONTEXT`.

## Acessos

| Serviço | Endereço |
|---|---|
| clima-api | http://localhost:30080/docs |
| Grafana | http://localhost:30300 (usuário `admin`; a senha é exibida pelo `grafana/install.sh`) |
| Prometheus | `kubectl -n monitoring port-forward svc/prometheus-operated 9090` e depois http://localhost:9090 |

## Requisitos

Docker (ou OrbStack), kind, kubectl e Helm 3.8 ou superior (para charts OCI).

## Versionamento

Commits seguem o [Conventional Commits](https://www.conventionalcommits.org/pt-br/) e as versões seguem o [SemVer](https://semver.org/lang/pt-BR/).
