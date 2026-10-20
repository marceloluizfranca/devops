# github-runners

Runners self-hosted do GitHub Actions rodando dentro do cluster, com o [Actions Runner Controller (ARC)](https://docs.github.com/pt/actions/hosting-your-own-runners/managing-self-hosted-runners-with-actions-runner-controller/about-actions-runner-controller) no modo *runner scale set*.

## Componentes

| Arquivo | Função |
|---|---|
| `controller-values.yaml` | Controller do ARC, no namespace `arc-systems` |
| `runner-set-clima-api.yaml` | Scale set `arc-splic`, ligado ao repositório clima-api, no namespace `arc-runners` |
| `rbac/clima-deployer.yaml` | Namespace `clima`, ServiceAccount do runner e Role com o mínimo necessário para o deploy |
| `install.sh` | Instala tudo na ordem certa |

## Como funciona

1. O *listener* do scale set mantém uma conexão de saída com o GitHub e fica esperando jobs com `runs-on: arc-splic`.
2. Quando chega um job, o controller cria um pod de runner efêmero, que executa o job e é destruído no final.
3. Sem jobs, não há nenhum pod de runner rodando (`minRunners: 0`).
4. O pod usa a ServiceAccount `clima-deployer`, que só pode mexer em deployments, services e servicemonitors do namespace `clima`.

Em contas pessoais do GitHub não existem runners por organização. Por isso cada scale set atende um único repositório. Para outro repositório, crie um novo arquivo `runner-set-<repo>.yaml` e uma nova release.

## Token

O ARC precisa de um token para registrar os runners. Crie um **fine-grained personal access token** em *Settings → Developer settings → Personal access tokens*:

- Repository access: apenas `clima-api`
- Permissions → Repository → **Administration: Read and write**
- Permissions → Repository → **Metadata: Read-only**

O token nunca é versionado: o `install.sh` grava ele no Secret `github-token` do namespace `arc-runners`.

## Instalação

```bash
GITHUB_TOKEN=<token> ./install.sh
```

## Validação

```bash
kubectl -n arc-systems get pods       # controller e listener Running
kubectl -n arc-runners get pods -w    # pods de runner aparecem durante os jobs
```

No GitHub, o scale set aparece em *clima-api → Settings → Actions → Runners*.

## Por que o build não roda aqui

A imagem é construída num runner hospedado pelo GitHub (`ubuntu-24.04-arm`) e o runner do cluster só faz o deploy. Construir imagens dentro do kind exigiria Docker-in-Docker com pod privilegiado. Assim os pods de runner ficam leves e sem privilégios.
