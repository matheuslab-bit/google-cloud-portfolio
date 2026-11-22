# Lab 02 - VM privada em Iowa

> **Em poucas palavras:** Uma máquina virtual sem porta para a rua: ninguém da internet chega nela. Eu entro só por uma porta vigiada pelo Google (IAP), que confere quem sou antes de abrir.

**Situação:** implantado em Iowa (`us-central1-a`). SSH pelo IAP com OS Login testado em 18/11/2026. State do Terraform migrado para o Cloud Storage (`labs/02-secure-compute-engine`) em 20/11/2026.

Uma VM Debian 12 `e2-micro` sem IP público. A única forma de entrar é por SSH através do Identity-Aware Proxy (IAP) com OS Login, que usa o IAM no lugar de chaves SSH. O state do Terraform fica no bucket do [Lab 03](../03-terraform-backend/README.md).

É um lab, não um serviço de produção, e não há promessa de custo zero.

## O que é de quem

| Recurso | Configuração | Quem gerencia |
| --- | --- | --- |
| VPC | `portfolio-vpc`, lida com `data "google_compute_network"` | Lab 01 (sem alteração) |
| Sub-rede de São Paulo | `portfolio-subnet`, `southamerica-east1`, `10.10.0.0/24` | Lab 01 (sem alteração) |
| Sub-rede de Iowa | `lab02-iowa-subnet`, `us-central1`, `10.20.0.0/24`, `IPV4_ONLY` | Lab 02 |
| VM | `lab02-secure-vm`, `us-central1-a`, `e2-micro`, `STANDARD` | Lab 02 |
| Disco de boot | `pd-standard` de 10 GB, `debian-cloud/debian-12`, `auto_delete = true` | Lab 02 |
| Conta de serviço | `lab02-secure-vm`, sem papéis e sem chaves | Lab 02 |
| Firewall de SSH | Libera o IAP (`35.235.240.0/20`) com prioridade `900` e bloqueia qualquer outro IPv4 (`0.0.0.0/0`) com `901` | Lab 02 |
| State remoto | `gs://gcp-portfolio-tfstate-usc1-7f4e9a2c`, prefixo `labs/02-secure-compute-engine` | Bucket do Lab 03 |

No Google Cloud, a VPC é global. Criar uma sub-rede em Iowa não muda nada na sub-rede de São Paulo. O Lab 02 tem a própria sub-rede e o próprio prefixo de state, e nunca mexe no state do Lab 01.

```text
Eu -> IAP -> TCP 22 vindo de 35.235.240.0/20 (prioridade 900) -> lab02-secure-vm
               Qualquer outro acesso na porta 22 (prioridade 901) -> bloqueado
```

## Escolhas de segurança

- **Sem IP público:** a interface de rede não tem bloco `access_config`, e `stack_type = "IPV4_ONLY"`.
- **SSH só pelo IAP, com bloqueio logo em seguida:** a porta 22 só é liberada para `35.235.240.0/20` (a faixa do IAP), com prioridade `900`, e bloqueada para todo o resto com `901`. As duas prioridades vêm antes das regras comuns de prioridade 1000, então valem primeiro. As regras só se aplicam à conta de serviço desta VM, por isso essa conta não deve ser usada em outras VMs.
- **Firewall antes da VM:** a VM tem `depends_on` nas duas regras, então as regras de SSH existem antes de a máquina ser criada.
- **OS Login e metadados travados:** `enable-oslogin = "TRUE"`, `block-project-ssh-keys = "TRUE"` e `serial-port-enable = "FALSE"`.
- **Shielded VM:** Secure Boot, vTPM e monitoramento de integridade ligados.
- **Conta de serviço sem nada:** sem chaves e sem papéis no projeto. O escopo OAuth `cloud-platform` sozinho não dá permissão no IAM.
- **ID do projeto fora do código:** o `project_id` é obrigatório, validado com regex e definido num `terraform.tfvars` local (copiado do `terraform.tfvars.example` e ignorado pelo Git).
- **Rede enxuta:** sem Cloud NAT, proxy, script de inicialização ou instalação de pacotes. O Private Google Access está `false` só na sub-rede de Iowa.

O IAP me dá um caminho de entrada para administrar a VM. Ele não dá à VM um caminho de saída para a internet: atualizar os pacotes do Debian exigiria uma rota de saída que eu ainda não montei. Além disso, a família de imagem `debian-12` pode apontar para versões mais novas em planos futuros. Sem atualização, saída para a internet e monitoramento, essa VM não é um servidor de produção.

## Checkov

O Checkov roda neste lab pelo [`terraform-ci.yml`](../../.github/workflows/terraform-ci.yml): **22 checagens passam**, entre elas sem IP público, sem conta de serviço padrão, OS Login, chaves SSH do projeto bloqueadas, porta serial desligada, Shielded VM e nenhum SSH ou RDP aberto para o mundo. Os alertas que aceitei estão explicados com `#checkov:skip` no [`main.tf`](main.tf):

| Checagem | Motivo |
| --- | --- |
| `CKV_GCP_26`, VPC Flow Logs | Fica para o lab de monitoramento, para não gerar custo de logs agora. |
| `CKV_GCP_74`, Private Google Access | Desligado de propósito. A VM não tem rota de saída aprovada neste lab. |
| `CKV_GCP_38`, criptografia do disco com chave própria | O disco usa a criptografia gerenciada pelo Google. Chaves próprias estão planejadas para um lab de Cloud KMS. |

## Permissões

O projeto precisa de faturamento ativo, `e2-micro` e disco padrão disponíveis em `us-central1`, a rede `portfolio-vpc`, o bucket do Lab 03 e as APIs do Compute Engine, IAM, IAP e OS Login ativas.

Quem roda o Terraform precisa de leitura e escrita no bucket de state (`roles/storage.objectAdmin` no bucket, para o state e o `.tflock`), leitura da VPC e das imagens públicas e permissão para gerenciar a sub-rede de Iowa, a VM e o disco, as regras de firewall e a conta de serviço, incluindo `iam.serviceAccounts.actAs` na conta de serviço da VM.

Para conectar por SSH, a pessoa precisa de `roles/iap.tunnelResourceAccessor`, `roles/compute.osLogin` (ou `roles/compute.osAdminLogin` para usar sudo), permissão para ver a instância e `roles/iam.serviceAccountUser` na conta de serviço da VM.

## Como rodar

Sempre dentro de `projects/02-secure-compute-engine/`. Terraform `>= 1.9.8, < 2.0.0` (o CI usa `1.9.8`). Provider do Google `7.46.2`, fixado no `.terraform.lock.hcl`.

Conferir o código sem credenciais (igual ao CI):

```powershell
terraform fmt -check -recursive
terraform init -backend=false -lockfile=readonly -input=false
terraform validate
```

Contra o backend real:

```powershell
Copy-Item terraform.tfvars.example terraform.tfvars
# coloque o project_id real no terraform.tfvars
terraform init -lockfile=readonly -input=false
terraform plan -input=false
```

Conectar pelo IAP:

```powershell
gcloud compute ssh lab02-secure-vm --project=SEU_PROJETO --zone=us-central1-a --tunnel-through-iap
```

No teste de 18/11/2026, o SSH pelo IAP com OS Login funcionou, e confirmei que não havia IP externo, o disco `pd-standard` de 10 GB, as três proteções do Shielded VM e a ligação com a `lab02-iowa-subnet`. Depois da migração do state em 20/11/2026, o `terraform plan` mostrou `No changes. Your infrastructure matches the configuration.`

## Custo (nível gratuito)

O nível gratuito do Google Cloud inclui, por mês, o equivalente a uma `e2-micro` não preemptiva em algumas regiões dos EUA (`us-central1`, `us-west1` ou `us-east1`) e até 30 GB-mês de `pd-standard`, conforme as regras de cobrança atuais do Google. Este lab usa uma `e2-micro` em `us-central1-a` e um disco `pd-standard` de 10 GB, sem IPv4 público, Cloud NAT, snapshots, balanceadores ou imagens pagas.

- Estar no nível gratuito não significa custo zero.
- A cota gratuita é compartilhada pela conta de faturamento inteira. Outros projetos no mesmo mês podem consumir tudo.
- Tráfego de saída, impostos e outras APIs ou logs ainda podem ser cobrados.
- Alerta de orçamento não para a cobrança nem desliga nada. Configure orçamentos e acompanhe o consumo real.

## State e limpeza

- O state fica em `gs://gcp-portfolio-tfstate-usc1-7f4e9a2c/labs/02-secure-compute-engine/default.tfstate` (`backend.tf`), com versionamento, regra de 90 dias para versões antigas, Soft Delete de 7 dias e lock com `.tflock`.
- Mantenha `.terraform/`, backups de state (`*.tfstate*`), planos salvos (`*.tfplan`), `*.tfvars`, credenciais, chaves privadas e logs fora do Git.
- Nunca rode `terraform destroy` no Lab 01 para limpar o Lab 02.

## Referências

- [Nível gratuito do Google Cloud](https://docs.cloud.google.com/free/docs/free-cloud-features)
- [Preços do Compute Engine](https://cloud.google.com/products/compute/pricing/general-purpose)
- [Preços de discos e imagens](https://cloud.google.com/compute/disks-image-pricing)
- [Encaminhamento TCP do IAP](https://docs.cloud.google.com/iap/docs/using-tcp-forwarding)
- [Configuração do OS Login](https://docs.cloud.google.com/compute/docs/oslogin/set-up-oslogin)
- [Contas de serviço e `actAs`](https://docs.cloud.google.com/iam/docs/service-accounts-actas)
- [Regras e prioridades de firewall da VPC](https://docs.cloud.google.com/firewall/docs/firewalls)
