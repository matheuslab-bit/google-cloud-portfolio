# Lab 03 - State do Terraform no Cloud Storage

[English](README.md) | [Português (Brasil)](README.pt-BR.md)

**Situação:** implantado em Iowa (`us-central1`) em 20/11/2026. Guarda o state atual do Lab 01 (`labs/01-vpc-network`) e do Lab 02 (`labs/02-secure-compute-engine`). Objetos `.tflock` temporários aparecem enquanto um lock está ativo.

Um bucket do Cloud Storage dedicado e bem protegido para guardar o state do Terraform dos outros labs. O código e o CI foram integrados no [PR #9](https://github.com/matheuslab-bit/matheuslab-bit/pull/9). Em 20/11/2026 criei o bucket, migrei para ele o state dos labs 01 e 02 com `terraform init -migrate-state` e adicionei os arquivos `backend.tf` deles no [PR #10](https://github.com/matheuslab-bit/matheuslab-bit/pull/10).

## Por quê

Antes deste lab, cada lab guardava o `.tfstate` no meu disco. Se o disco desse problema, ou se duas execuções rodassem ao mesmo tempo, o state podia se perder ou corromper. Com um bucket compartilhado, ganho lock, versões antigas que consigo recuperar e uma regra de ciclo de vida que mantém o custo sob controle.

## Estrutura

```text
Lab 03 (state local, o ponto de partida)
  └── cria e gerencia o bucket (us-central1, STANDARD)
        ├── labs/01-vpc-network/default.tfstate            <- Lab 01
        └── labs/02-secure-compute-engine/default.tfstate  <- Lab 02
```

Configuração do bucket: acesso uniforme no nível do bucket, prevenção de acesso público obrigatória, versionamento ligado, Soft Delete de 7 dias (604800 s), `force_destroy = false`, `deletion_policy = "PREVENT"`, `prevent_destroy = true` e exclusão das versões arquivadas depois de 90 dias.

### Quem guarda o state do bucket de state?

Este lab mantém o próprio `terraform.tfstate` **local**, com uma cópia de backup em outra pasta, fora do repositório. Uma cópia local no mesmo disco não protege contra falha do disco, então não é um backup de verdade.

Guardar o state de um bucket dentro dele mesmo cria o problema do ovo e da galinha na hora de criar, recuperar ou apagar. Como o Lab 03 cuida de um único recurso estável, state local com uma cópia separada é simples e evita que eu me tranque para fora.

Os outros labs (01, 02 e os futuros) apontam para este bucket com blocos `backend "gcs"`, cada um no seu prefixo, então cada um tem um state independente.

## Como o backend GCS funciona

**Lock.** Antes de qualquer comando que leia ou altere o state (`plan`, `apply`, `destroy`, `import`), o Terraform cria um objeto `.tflock` temporário ao lado do `default.tfstate`. Ele faz isso até no `plan`, que não grava nada. Se uma segunda execução começar ao mesmo tempo, ela para na hora em vez de corromper o state.

**Versionamento.** Cada `terraform apply` grava uma nova versão do `default.tfstate`. A anterior não é sobrescrita: o GCS guarda como versão não atual (`ARCHIVED`), com um número de geração próprio.

**Regra de 90 dias** (`days_since_noncurrent_time = 90`, `with_state = "ARCHIVED"`). As versões antigas são apagadas depois de 90 dias. O state atual nunca é apagado por essa regra, não importa quanto tempo passe sem um novo `apply`. O GCS executa essas regras em segundo plano, então a exclusão pode acontecer algum tempo depois do 90º dia.

**Soft Delete de 7 dias** (`retention_duration_seconds = 604800`). Defini explicitamente, em vez de confiar no padrão. Quando uma versão é apagada (pela regra de 90 dias ou manualmente), ela ainda pode ser recuperada por mais 7 dias.

No total, uma versão antiga do state pode ser recuperada por cerca de 90 dias como versão não atual, mais 7 dias no Soft Delete.

## Segurança

- **`uniform_bucket_level_access = true`:** sem ACL por objeto. O acesso é controlado só pelo IAM.
- **`public_access_prevention = "enforced"`:** bloqueia `allUsers` e `allAuthenticatedUsers`, então o state nunca fica público por engano.
- **`force_destroy = false`:** o Terraform não consegue esvaziar e apagar o bucket enquanto houver state nele.
- **`deletion_policy = "PREVENT"`:** proteção contra exclusão no provider do Google `7.46.2`.
- **`lifecycle.prevent_destroy = true`:** o Terraform recusa qualquer plano que destruiria o bucket.

Essas três proteções só evitam acidentes que passam **pelo Terraform**. Elas não substituem backup e não impedem que alguém com permissão apague o bucket pelo Console, com `gcloud storage rm` ou pela API.

`project_id` e `bucket_name` são variáveis obrigatórias definidas num `terraform.tfvars` local (ignorado pelo Git). Use um nome de bucket que não revele nada, como `gcp-portfolio-tfstate-usc1-<sufixo-aleatorio>`, sem o ID do projeto nem dados pessoais.

### Checkov

Versionamento, acesso uniforme e prevenção de acesso público passam. Um alerta foi aceito e está explicado com `#checkov:skip` no [`main.tf`](main.tf):

| Checagem | Motivo |
| --- | --- |
| `CKV_GCP_62`, log de acesso ao bucket | Exigiria um segundo bucket só para logs. As alterações no bucket já ficam registradas no Cloud Audit Logs (Admin Activity). |

### Permissões

- **Para criar o bucket (este lab):** `storage.buckets.create`, `storage.buckets.get` e `storage.buckets.update` no projeto (por exemplo, `roles/storage.admin` ou um papel personalizado).
- **Para usar o backend nos outros labs (`plan` / `apply`):** leitura e escrita nos objetos (`roles/storage.objectAdmin` neste bucket, ou `storage.objects.get`, `list`, `create` e `delete`).
- **Para `terraform plan` no CI** (com Workload Identity Federation, num lab futuro): até um `plan` só de leitura precisa criar e apagar o `.tflock` (`storage.objects.create` e `storage.objects.delete` no prefixo). Desligar o lock num state compartilhado é má ideia, porque duas execuções ao mesmo tempo podem ler dados inconsistentes.
- **Para restaurar objetos em Soft Delete:** `storage.objects.list`, `storage.objects.get`, `storage.objects.restore` e `storage.objects.create` no bucket.

## Custo

O nível gratuito inclui **5 GB-mês de Regional Standard Storage** em algumas regiões dos EUA (incluindo `us-central1`), além de uma cota mensal de operações Classe A e Classe B, conforme as regras atuais do Google.

- O state dos labs 01 e 02 soma **cerca de 24 KB** (`4,88 KB` + `19,10 KB`).
- Mesmo com dezenas de versões antigas guardadas por 90 dias, fica muito abaixo de 5 MB.
- O nível gratuito é compartilhado pela conta de faturamento. Passar dos limites de operações, tráfego entre regiões ou outros projetos pode gerar cobrança. Alertas de faturamento não bloqueiam gastos.

## Recuperando o state

> **Antes de tudo:** copie o `default.tfstate` atual (se existir) para um lugar seguro antes de restaurar uma versão antiga. Se escolher a versão errada, ainda dá para voltar.

### A. Restaurar uma versão antiga (dentro dos 90 dias)

1. Salve o state atual:
   ```powershell
   gcloud storage cp gs://SEU_BUCKET/labs/01-vpc-network/default.tfstate ./pre-recovery-default.tfstate.bak
   ```
2. Liste todas as versões do state do lab:
   ```powershell
   gcloud storage ls --all-versions gs://SEU_BUCKET/labs/01-vpc-network/default.tfstate
   ```
3. Olhe as datas e escolha o `<GENERATION>` da última versão boa.
4. Copie essa versão de volta como state atual:
   ```powershell
   gcloud storage cp gs://SEU_BUCKET/labs/01-vpc-network/default.tfstate#<GENERATION> gs://SEU_BUCKET/labs/01-vpc-network/default.tfstate
   ```
5. Rode `terraform plan` na pasta do lab e confirme que o state bate com o que está na nuvem.

### B. Restaurar uma versão apagada (dentro dos 7 dias de Soft Delete)

Se o state ou uma versão antiga foi apagado (manualmente ou pela regra de 90 dias), ainda dá para recuperar por 7 dias. É preciso ter `storage.objects.list`, `get`, `restore` e `create` no bucket.

1. Salve o state atual:
   ```powershell
   gcloud storage cp gs://SEU_BUCKET/labs/01-vpc-network/default.tfstate ./pre-soft-restore-default.tfstate.bak
   ```
2. Liste as versões apagadas:
   ```powershell
   gcloud storage ls --soft-deleted gs://SEU_BUCKET/labs/01-vpc-network/default.tfstate
   ```
3. Escolha o `<GENERATION>` e restaure:
   ```powershell
   gcloud storage restore gs://SEU_BUCKET/labs/01-vpc-network/default.tfstate#<GENERATION>
   ```
4. Rode `terraform plan` na pasta do lab para confirmar.

## Como rodar

Sempre dentro de `projects/03-terraform-backend/`:

```powershell
terraform fmt -check -recursive
terraform init -backend=false -lockfile=readonly -input=false
terraform validate
```

Para rodar o plan contra o bucket implantado, com um `terraform.tfvars` local copiado do `terraform.tfvars.example`:

```powershell
Copy-Item terraform.tfvars.example terraform.tfvars
# coloque o project_id real e um bucket_name único no terraform.tfvars
terraform plan -input=false
```

Não coloque `terraform.tfvars`, `*.tfplan` nem `*.tfstate` no Git.

## Checklist

- [x] Arquivos do Terraform escritos (`versions.tf`, `variables.tf`, `main.tf`, `outputs.tf`, `terraform.tfvars.example`)
- [x] Documentação em português e inglês (`README.md` e `README.pt-BR.md`)
- [x] `terraform fmt -check`, `terraform init -backend=false` e `terraform validate` aprovados localmente e no GitHub Actions ([PR #9](https://github.com/matheuslab-bit/matheuslab-bit/pull/9))
- [x] Bucket criado no Google Cloud (`us-central1`, 20/11/2026)
- [x] State dos labs 01 e 02 migrado com `terraform init -migrate-state` (`No changes` conferido) e arquivos `backend.tf` adicionados no [PR #10](https://github.com/matheuslab-bit/matheuslab-bit/pull/10)
