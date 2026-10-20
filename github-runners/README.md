# github-runners

Runners self-hosted do GitHub Actions dentro do cluster, com o [Actions Runner Controller (ARC)](https://docs.github.com/pt/actions/hosting-your-own-runners/managing-self-hosted-runners-with-actions-runner-controller/about-actions-runner-controller) no modo *runner scale set*.

| Item | Valor |
|---|---|
| Charts | `oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller` e `.../gha-runner-scale-set` |
| Versão | `0.15.0` |
| Namespaces | `arc-systems` (controller) e `arc-runners` (scale sets e runners) |

## Arquivos

| Arquivo | Função |
|---|---|
| `controller-values.yaml` | Values do controller |
| `runner-set-values.yaml` | Values comuns a todos os scale sets (escala, imagem, recursos) |
| `rbac/arc-deployer.yaml` | `ClusterRole` com o mínimo necessário para um deploy |

## Como funciona

1. O **controller** observa os scale sets instalados no cluster.
2. Cada **scale set** está ligado a um repositório e tem um *listener*, que mantém uma conexão de saída com o GitHub esperando jobs com `runs-on: <nome-do-scale-set>`.
3. Quando chega um job, o controller cria um **pod de runner efêmero**, que executa o job e é destruído ao final. Sem jobs, não há pod de runner rodando (`minRunners: 0`).
4. O pod de runner usa uma **ServiceAccount própria do scale set**, ligada ao `ClusterRole` `arc-deployer` apenas no namespace da aplicação. O `kubectl` dentro do job usa essa identidade automaticamente, sem kubeconfig.

Em contas pessoais do GitHub não existem runners de organização. Cada scale set atende a um único repositório.

## Instalação do controller

Feita uma vez por cluster:

```bash
helm upgrade --install arc \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller \
  --kube-context kind-splic --namespace arc-systems --create-namespace \
  --version 0.15.0 --values github-runners/controller-values.yaml --wait

kubectl --context kind-splic create namespace arc-runners --dry-run=client -o yaml \
  | kubectl --context kind-splic apply -f -
kubectl --context kind-splic apply -f github-runners/rbac/arc-deployer.yaml
```

## Adicionar um repositório

Defina as variáveis do repositório que vai usar os runners:

```bash
REPO=<repositorio>          # ex.: minha-api
DONO=<usuario-ou-org>       # dono do repositório no GitHub
NAMESPACE=<namespace>       # namespace onde a aplicação roda
SCALE_SET=<nome>            # valor usado em "runs-on" no workflow
```

**1. Token.** Crie um *fine-grained personal access token* em *Settings → Developer settings → Personal access tokens*:

- **Repository access:** apenas o repositório.
- **Permissions → Repository → Administration:** *Read and write*.
- **Metadata:** *Read-only*, marcado automaticamente.

Grave o token no cluster. Ele nunca vai para o Git:

```bash
kubectl --context kind-splic -n arc-runners create secret generic "github-token-$REPO" \
  --from-literal=github_token='<token>'
```

**2. Namespace e permissões.**

```bash
kubectl --context kind-splic create namespace "$NAMESPACE"
kubectl --context kind-splic -n arc-runners create serviceaccount "$REPO-deployer"
kubectl --context kind-splic -n "$NAMESPACE" create rolebinding "$REPO-deployer" \
  --clusterrole=arc-deployer --serviceaccount="arc-runners:$REPO-deployer"
```

**3. Scale set.**

```bash
helm upgrade --install "$SCALE_SET" \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set \
  --kube-context kind-splic --namespace arc-runners --version 0.15.0 \
  --values github-runners/runner-set-values.yaml \
  --set githubConfigUrl="https://github.com/$DONO/$REPO" \
  --set githubConfigSecret="github-token-$REPO" \
  --set template.spec.serviceAccountName="$REPO-deployer" \
  --wait
```

**4. Workflow.** No repositório, use o scale set no job de deploy:

```yaml
deploy:
  runs-on: <nome-do-scale-set>
  steps:
    - uses: actions/checkout@v5
    - uses: azure/setup-kubectl@v4
    - run: kubectl apply -k k8s/
```

## Validação

```bash
kubectl --context kind-splic -n arc-systems get pods    # controller e um listener por scale set
kubectl --context kind-splic -n arc-runners get pods -w # pods de runner aparecem durante os jobs
helm --kube-context kind-splic -n arc-runners list      # scale sets instalados
```

No GitHub, o scale set aparece em *Settings → Actions → Runners* do repositório.

Para confirmar as permissões de um scale set:

```bash
kubectl --context kind-splic auth can-i patch deployments -n "$NAMESPACE" \
  --as="system:serviceaccount:arc-runners:$REPO-deployer"   # yes
kubectl --context kind-splic auth can-i get secrets -n "$NAMESPACE" \
  --as="system:serviceaccount:arc-runners:$REPO-deployer"   # no
```

## Operação

| Ação | Comando |
|---|---|
| Trocar o token | Recrie o secret com `--dry-run=client -o yaml \| kubectl apply -f -`. O listener usa o novo token sozinho. |
| Remover um repositório | `helm -n arc-runners uninstall <scale-set>` e apague o secret, a ServiceAccount e o RoleBinding |
| Atualizar o ARC | Troque a versão nos comandos e rode o `helm upgrade` do controller e de cada scale set. As duas versões precisam ser iguais. |

## Problemas comuns

| Sintoma | Causa provável |
|---|---|
| Job fica em *Queued* | `runs-on` diferente do nome do scale set, ou listener fora do ar. Veja `kubectl -n arc-systems logs <listener>` |
| Listener em erro `401`/`403` | Token expirado ou sem a permissão *Administration* |
| `forbidden` no `kubectl` do job | Falta o RoleBinding no namespace, ou o recurso não está no `ClusterRole` `arc-deployer` |
| Imagem não baixa (`ImagePullBackOff`) | Pacote privado no GHCR. Deixe o pacote público ou crie um `imagePullSecret` no namespace |
