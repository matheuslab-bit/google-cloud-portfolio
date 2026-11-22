# Lab 06 - Workload Identity Federation (CI sem chave)

> **Em poucas palavras:** Em vez de guardar uma senha do Google Cloud no GitHub, o GitHub mostra um crachá temporário a cada execução, e o Google confere se o crachá veio deste repositório antes de deixar entrar.

**Situação:** implantado em 21/11/2026 (17 recursos, `terraform plan` sem mudanças depois). O workflow está ativo em [`.github/workflows/terraform-plan.yml`](../../.github/workflows/terraform-plan.yml).

Sem acesso à nuvem, o CI só consegue conferir a sintaxe. O atalho comum é criar uma chave de conta de serviço, colar o JSON num secret do GitHub e esquecer lá por anos. Essa chave é o vazamento clássico. Este lab dá ao GitHub Actions acesso ao Google Cloud sem nenhuma chave guardada: o GitHub prova quem é com um token de vida curta, e o Google troca esse token por credenciais temporárias.

## Como funciona a troca de token

```text
Job do GitHub Actions (pull request em matheuslab-bit/google-cloud-portfolio)
   │  1. pede um token OIDC ao GitHub (id-token: write)
   ▼
Workload Identity Pool "github-actions" / provedor "github-oidc"
   │  2. confere o emissor e a condição: ID do repositório E sub imutável = repo:DONO@ID/NOME@ID:pull_request
   ▼
Security Token Service
   │  3. devolve um token federado
   ▼
Conta de serviço "github-terraform-plan" (só leitura)
   │  4. credenciais temporárias, válidas por cerca de uma hora
   ▼
terraform plan contra o projeto real e o state remoto
```

## O que é criado

| Recurso | Detalhe |
| --- | --- |
| Pool de identidade `github-actions` | Onde chegam as identidades externas vindas do GitHub |
| Provedor OIDC `github-oidc` | Confia em `token.actions.githubusercontent.com` e mapeia os campos do token (sub, repositório, dono, ref) |
| Conta de serviço `github-terraform-plan` | Sem chaves. Só este repositório consegue usá-la |
| Papéis só de leitura | Compute, contas de serviço, políticas de IAM, APIs ativas, Monitoring, Logging, Cloud Run, Artifact Registry e metadados de segredos |
| Acesso ao bucket de state | Só aos objetos em `labs/`, necessário para criar e apagar o `.tflock` durante o `plan` |
| Workflow de exemplo | [`examples/terraform-plan.yml`](examples/terraform-plan.yml), guardado como referência; a cópia ativa está em `.github/workflows/terraform-plan.yml` |

## Decisões que tomei

- **A condição é a segurança.** Um provedor sem `attribute_condition` aceita token de qualquer repositório do GitHub no mundo. O meu confere o ID do repositório e fixa o campo `sub` em `repo:matheuslab-bit@343780539/google-cloud-portfolio@1466069275:pull_request`, então só execuções de pull request deste repositório entram. Aplicar mudanças a partir da `main` exigiria uma segunda identidade, separada.
- **Sub imutável.** Este repositório usa o formato imutável do `sub` do GitHub, com os IDs do dono e do repositório ao lado dos nomes. A minha primeira condição esperava o formato antigo `repo:DONO/NOME:pull_request`, e no primeiro teste o GitHub teve o token recusado (`rejected by the attribute condition`). Corrigi montando o `sub` a partir de `github_repository_id` e `github_repository_owner_id` (lidos com `gh api repos/DONO/NOME`). Os IDs ainda impedem que um repositório apagado e recriado com o mesmo nome entre.
- **Sem o papel Viewer.** O Checkov apontou o `roles/viewer` (CKV_GCP_117), e estava certo: ele lê quase tudo. Troquei pelos papéis de leitura específicos que o `plan` precisa nestes labs.
- **Até o `plan` grava uma coisa.** Ele cria e apaga o objeto `.tflock` no bucket de state. Uma condição de IAM limita essa escrita ao prefixo `labs/`.
- **Valor de segredo fica de fora.** O `roles/secretmanager.viewer` mostra os metadados dos segredos, não o conteúdo. Ler valores exigiria `secretAccessor`, que o CI não recebe.

## Checkov

47 aprovadas, 0 falhas e 1 alerta aceito, com justificativa no [`main.tf`](main.tf):

| Checagem | Motivo |
| --- | --- |
| `CKV_GCP_125`, condição de confiança do OIDC do GitHub | Falso positivo. O Checkov não resolve a variável `var.github_repository` dentro da condição. Confirmei: com o nome do repositório escrito por extenso, a mesma condição passa. |

## Como rodar

É preciso `roles/iam.workloadIdentityPoolAdmin`, `roles/iam.serviceAccountAdmin`, `roles/resourcemanager.projectIamAdmin` e `roles/storage.admin` no bucket de state.

```powershell
cd projects/06-workload-identity-federation
Copy-Item terraform.tfvars.example terraform.tfvars   # project_id, github_repository, state_bucket
terraform init -lockfile=readonly
terraform apply
terraform output
```

Depois, no GitHub (Settings > Secrets and variables > Actions > Variables), crie `GCP_WORKLOAD_IDENTITY_PROVIDER`, `GCP_SERVICE_ACCOUNT` e `GCP_PROJECT_ID` com as saídas, e copie o [`examples/terraform-plan.yml`](examples/terraform-plan.yml) para `.github/workflows/`. São variáveis, não secrets: nenhum desses valores é sensível.

## Como testar depois de implantar

- Abra um pull request que mexa em `projects/`: o job de plan deve se autenticar e mostrar `No changes` nos labs 01 e 02.
- Rode o mesmo workflow a partir de um fork ou de outro repositório: a autenticação tem que falhar.
- No Cloud Logging, as entradas de `sts.googleapis.com` mostram cada troca de token e qual repositório pediu.

## Custo

Workload Identity Federation, Security Token Service e contas de serviço não têm custo.

## Checklist

- [x] Terraform escrito: pool, provedor com condição fixada, conta de serviço sem chave, papéis restritos e acesso condicional ao bucket
- [x] Workflow de exemplo pronto para ativar
- [x] `terraform fmt`, `validate` e Checkov aprovados localmente e no CI
- [x] Implantado em 21/11/2026 e variáveis do repositório criadas
- [x] `terraform plan` rodando num pull request sem nenhuma chave: PR #5, `No changes` nos labs 01 e 02 (21/11/2026)
