# Terraform no Google Cloud

Coisas que aprendi fazendo os labs, algumas do jeito difícil.

## State

- **Nunca deixe o state só no seu disco.** Foi o motivo do [Lab 03](../projects/03-terraform-backend/README.pt-BR.md). Um bucket GCS com versionamento e lock resolve: dá para recuperar versões antigas, e duas execuções ao mesmo tempo não corrompem nada.
- **Um prefixo por projeto ou ambiente** (`labs/01-vpc-network`, `labs/02-...`). Se um state quebrar, os outros continuam inteiros.
- **O bucket do state não guarda o próprio state.** Ele é criado com state local e uma cópia de segurança separada. Senão, para recuperar o bucket você precisaria do bucket.
- **Segredo no state fica em texto puro.** Senha, chave e valor de `google_secret_manager_secret_version` vão para o arquivo de state. No [Lab 05](../projects/05-cloud-run-app/README.pt-BR.md), o Terraform cria só o segredo e o valor entra pelo `gcloud`.

## Lock travado

Se uma execução morrer no meio, o `.tflock` pode ficar no bucket:

```bash
terraform plan    # mostra "Error acquiring the state lock" com um ID
terraform force-unlock ID_DO_LOCK
```

Só use `force-unlock` com certeza de que ninguém mais está rodando. Até o `plan` pega o lock, mesmo sem gravar nada.

## Recurso criado fora do Terraform

Erro `409 already exists`: o recurso existe, mas o Terraform não sabe dele. Em vez de apagar, importe:

```hcl
import {
  to = google_compute_network.portfolio_vpc
  id = "projects/MEU_PROJETO/global/networks/portfolio-vpc"
}
```

`terraform plan` mostra o que vai ser importado e se a configuração bate com o que existe.

## Proteções

- `lifecycle { prevent_destroy = true }` faz o Terraform recusar qualquer plano que destrua o recurso. Uso no bucket de state.
- `deletion_protection` (VMs, Cloud SQL, alguns serviços) bloqueia a exclusão no próprio Google. Proteção dupla em recurso crítico.
- Nenhuma delas impede alguém de apagar pelo console. Para isso existe IAM.

## Versões

- Fixe a versão do provider (`version = "7.46.2"`) e coloque o `.terraform.lock.hcl` no Git. Assim, todo mundo e o CI usam exatamente o mesmo provider.
- `terraform init -lockfile=readonly` falha se alguém tentar mudar o provider sem querer.

## Validação antes de chegar na nuvem

- `validation` nas variáveis pega erro de digitação (ID de projeto, CIDR, e-mail) antes de qualquer chamada à API.
- No CI, `terraform init -backend=false` permite rodar `fmt` e `validate` sem nenhuma credencial.
- O Checkov aponta problema de segurança no código. Quando eu discordo de um alerta, deixo o motivo num `#checkov:skip` ao lado do recurso. Assim, quem lê sabe que foi uma decisão, não um esquecimento.

## Ler outro lab sem tocar no state dele

O Lab 02 usa a VPC do Lab 01 com um `data "google_compute_network"`, que consulta a API. Ele não lê o state do Lab 01. Cada lab continua independente, e um `destroy` num não apaga nada do outro.
