# Lab 01 - Rede VPC

[English](README.md) | [Português (Brasil)](README.pt-BR.md)

**Situação:** implantado em São Paulo (`southamerica-east1`). State do Terraform migrado para o Cloud Storage (`labs/01-vpc-network`) em 20/11/2026.

A rede base dos outros labs: uma VPC em modo personalizado com uma sub-rede regional. O state fica no bucket do [Lab 03](../03-terraform-backend/README.pt-BR.md).

## O que é criado

- **VPC `portfolio-vpc`** com `auto_create_subnetworks = false` e `routing_mode = "REGIONAL"`.
- **Sub-rede `portfolio-subnet`**, `10.10.0.0/24`, em São Paulo.
- **State remoto** (`backend.tf`) no bucket `gcp-portfolio-tfstate-usc1-7f4e9a2c` (`us-central1`), prefixo `labs/01-vpc-network`, com versionamento, Soft Delete de 7 dias e lock.

Desliguei a criação automática de sub-redes de propósito. No modo automático, o Google cria uma sub-rede em cada região, com faixas escolhidas por ele. No modo personalizado, toda faixa da rede é uma faixa que eu planejei.

O [Lab 02](../02-secure-compute-engine/README.pt-BR.md) reaproveita esta VPC: ele lê a rede por um data source e acrescenta a própria sub-rede em Iowa.

## Variáveis e saídas

| Variável | O que é | Padrão |
| --- | --- | --- |
| `project_id` | ID do projeto no Google Cloud | obrigatória |
| `region` | Região da sub-rede | `southamerica-east1` |
| `network_name` | Nome da VPC | `portfolio-vpc` |
| `subnet_name` | Nome da sub-rede | `portfolio-subnet` |
| `subnet_cidr` | Faixa da sub-rede | `10.10.0.0/24` |

Saídas: `vpc_name`, `vpc_id`, `subnet_name`, `subnet_cidr` e `subnet_region`.

O `project_id` precisa ser um ID de projeto válido e o `subnet_cidr` uma faixa IPv4 válida. Caso contrário, o Terraform para antes de chamar a API. As versões estão em [`versions.tf`](versions.tf): provider do Google `7.46.2`, a mesma do `.terraform.lock.hcl`.

## O que eu verifiquei

- `portfolio-vpc` e `portfolio-subnet` estão implantadas e ativas.
- O `backend.tf` entrou no [PR #10](https://github.com/matheuslab-bit/matheuslab-bit/pull/10). Em 20/11/2026 migrei o state do meu disco para `gs://gcp-portfolio-tfstate-usc1-7f4e9a2c/labs/01-vpc-network/default.tfstate` com `terraform init -migrate-state`. Depois disso, `terraform state list`, `terraform plan` (`No changes. Your infrastructure matches the configuration.`) e `gcloud compute` não mostraram nenhuma diferença, e o versionamento de objetos estava ativo.
- Localmente, `terraform fmt -check -recursive`, `terraform validate` e `terraform plan` passaram com o Terraform `1.17.2`.
- No GitHub Actions, o [`terraform-ci.yml`](../../.github/workflows/terraform-ci.yml) valida o lab com o Terraform `1.9.8` (a versão mais antiga que eu suporto) e roda o Checkov. O CI usa `-backend=false`, então não precisa de credenciais de nuvem.

## Alertas do Checkov que aceitei

Cada um está explicado num comentário `#checkov:skip` no [`main.tf`](main.tf):

| Checagem | Motivo |
| --- | --- |
| `CKV_GCP_26`, VPC Flow Logs | Fica para o lab de monitoramento, para não gerar custo de logs agora. |
| `CKV_GCP_74`, Private Google Access | Ainda não roda nada na sub-rede de São Paulo. Vou ligar quando alguma carga precisar das APIs do Google. |
| `CKV2_GCP_18`, firewall de rede | As regras de firewall ficam em cada lab de carga. O Lab 02 tem as próprias regras de liberar e bloquear para o IAP. |

## Como rodar

Você precisa de Terraform `>= 1.9.8, < 2.0.0`, um projeto com faturamento e a API do Compute Engine ativos, acesso ao bucket de state (`roles/storage.objectAdmin` no bucket), permissão para gerenciar VPCs e o `gcloud` instalado.

Para conferir o código sem nenhuma credencial, dentro de `projects/01-vpc-network/`:

```powershell
terraform fmt -check -recursive
terraform init -backend=false -lockfile=readonly -input=false
terraform validate
```

Contra o backend real:

```powershell
gcloud auth application-default login
terraform init -lockfile=readonly
terraform plan
```

O `project_id` vai num `terraform.tfvars` local, que não vai para o Git (ou `-var="project_id=SEU_PROJETO"`). Nunca coloque credenciais em arquivos do Terraform.

## Custo e cuidados

VPC e sub-redes sem IP externo, Cloud NAT ou VPN não têm custo fixo por hora. O tráfego de saída e o que roda dentro da rede podem gerar cobrança.

O Lab 02 depende da `portfolio-vpc`, então **não rode `terraform destroy` aqui** enquanto o Lab 02 existir. Mantenha `.terraform/`, backups locais de state, planos salvos, credenciais e `*.tfvars` fora do Git.

## Checklist

- [x] Arquivos do Terraform escritos e documentados (`versions.tf`, `main.tf`, `variables.tf`, `outputs.tf`, `backend.tf`)
- [x] `terraform fmt -check` e `terraform validate` aprovados localmente
- [x] CI aprovado no GitHub Actions (`push` e `pull_request`)
- [x] Implantado em São Paulo (`portfolio-vpc` e `portfolio-subnet`, `10.10.0.0/24`), conferido com `gcloud compute` e `terraform plan` (`No changes`)
- [x] `backend.tf` adicionado ([PR #10](https://github.com/matheuslab-bit/matheuslab-bit/pull/10)) e state migrado para o GCS (`labs/01-vpc-network`) com lock e versionamento conferidos
