# kind

Cluster Kubernetes local `splic`, criado com o [kind](https://kind.sigs.k8s.io/) (Kubernetes rodando em containers Docker).

## Topologia

| Nó | Papel |
|---|---|
| `splic-control-plane` | API server, etcd, scheduler e controller-manager |
| `splic-worker` | Workloads da plataforma e das aplicações |

O kind não tem LoadBalancer, então os serviços são expostos por NodePort. As portas abaixo estão mapeadas para o host em `splic.yaml`:

| Porta no host | Uso |
|---|---|
| `30080` | Aplicações |
| `30300` | Grafana |

O mapeamento de portas só é definido na criação do cluster. Para adicionar uma porta, edite `splic.yaml` e recrie o cluster.

## Criar o cluster

```bash
kind create cluster --config kind/splic.yaml
kubectl --context kind-splic wait --for=condition=Ready nodes --all --timeout=180s
```

O kind muda o contexto atual do kubectl para `kind-splic`. Se você usa outros clusters, confira o contexto antes de rodar comandos sem `--context`.

## Validar

```bash
kubectl --context kind-splic get nodes
```

Os dois nós devem estar `Ready`.

## Operação

| Ação | Comando |
|---|---|
| Listar clusters | `kind get clusters` |
| Carregar uma imagem local nos nós | `kind load docker-image <imagem> --name splic` |
| Exportar logs para diagnóstico | `kind export logs --name splic ./logs-kind` |
| Remover o cluster | `kind delete cluster --name splic` |

Remover o cluster apaga tudo, inclusive os dados do Prometheus. Para reconstruir, siga a [instalação do zero](../README.md#instalação-do-zero).
