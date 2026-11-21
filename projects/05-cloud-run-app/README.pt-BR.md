# Lab 05 - Aplicação no Cloud Run com Artifact Registry e Secret Manager

[English](README.md) | [Português (Brasil)](README.pt-BR.md)

**Situação:** implantado em 21/11/2026 (etapa 1: 7 recursos; etapa 2: o serviço do Cloud Run; `terraform plan` sem mudanças depois).

Os labs 01 a 03 são de infraestrutura. Este roda uma aplicação: uma API de status pequena em Node.js, empacotada em contêiner, guardada no Artifact Registry e servida pelo Cloud Run. Ela também lê um segredo do Secret Manager do jeito certo.

## Como as peças se encaixam

```text
docker build/push ──> Artifact Registry (us-central1, repositório "apps")
                             │
                             ▼
Eu ── token de identidade ──> Cloud Run "status-api"  (roda como lab05-status-api)
                             │
                             └── lê APP_GREETING do Secret Manager (só esse segredo)
```

## O que é criado

| Recurso | Detalhe |
| --- | --- |
| Repositório `apps` no Artifact Registry | Formato Docker, com regras de limpeza: mantém as 5 versões mais recentes e apaga imagens sem tag depois de 7 dias |
| Conta de serviço `lab05-status-api` | Identidade do serviço, com acesso a um segredo e a mais nada |
| Segredo `lab05-app-greeting` | Só o contêiner do segredo; o valor é adicionado com `gcloud` |
| Serviço `status-api` no Cloud Run | De 0 a 2 instâncias, 1 vCPU, 256 MiB, CPU cobrada só durante as requisições, checagens de inicialização e de vida em `/healthz` |
| Acesso público | Desligado por padrão (`allow_public_access = false`) |

## Decisões que tomei

- **O valor do segredo nunca passa pelo Terraform.** Se o Terraform criasse a versão do segredo, o valor ficaria em texto puro no state. O Terraform cria só o segredo; o valor eu adiciono com `gcloud secrets versions add`.
- **Privado por padrão.** É comum liberar `allUsers` no Cloud Run por costume. Aqui você chama o serviço com o seu próprio token de identidade, e o acesso público é uma escolha explícita.
- **Uma identidade por serviço.** A conta de serviço padrão do Compute tem papel de Editor no projeto. Este serviço roda com uma conta própria, que só consegue ler um segredo.
- **Implantação em duas etapas.** O primeiro `apply` cria o repositório, o segredo e a conta (o serviço precisa de uma imagem que ainda não existe). Depois de enviar a imagem, o segundo `apply`, com a variável `image` preenchida, cria o serviço.
- **Custo sob controle.** Escala até zero, limite de 2 instâncias, CPU só durante as requisições e regras de limpeza no repositório.
- **Aplicação pronta para o Cloud Run:** escuta na porta `$PORT`, grava uma linha JSON por requisição (o Cloud Logging lê como dado estruturado) e termina as requisições em andamento ao receber `SIGTERM`. A imagem roda com usuário sem privilégio de root.

## Checkov

0 falhas e 1 alerta aceito, com justificativa no [`main.tf`](main.tf):

| Checagem | Motivo |
| --- | --- |
| `CKV_GCP_84`, repositório criptografado com chave própria | A criptografia gerenciada pelo Google basta para um lab; chaves próprias estão planejadas para um lab de Cloud KMS. |

## Como rodar

```powershell
cd projects/05-cloud-run-app
Copy-Item terraform.tfvars.example terraform.tfvars   # defina project_id e deixe image vazio
terraform init -lockfile=readonly
terraform apply                                        # repositório, segredo e conta de serviço

# adiciona o valor do segredo sem passar pelo Terraform
"ola do Secret Manager" | gcloud secrets versions add lab05-app-greeting --data-file=-

# gera e envia a imagem
gcloud auth configure-docker us-central1-docker.pkg.dev
docker build -t us-central1-docker.pkg.dev/SEU_PROJETO/apps/status-api:1.0.0 app
docker push us-central1-docker.pkg.dev/SEU_PROJETO/apps/status-api:1.0.0

# implanta o serviço
terraform apply -var "image=us-central1-docker.pkg.dev/SEU_PROJETO/apps/status-api:1.0.0"
```

Chamar o serviço privado com um token de identidade:

```bash
URL=$(terraform output -raw service_url)
curl -H "Authorization: Bearer $(gcloud auth print-identity-token)" "$URL/"
# {"service":"status-api","revision":"status-api-00001-abc","version":"1.0.0","uptimeSeconds":12,"greetingConfigured":true}
```

Rodar a aplicação e os testes localmente:

```bash
cd app
npm test
PORT=8080 node server.js
```

## O que aprendi na implantação

- **O `/healthz` não responde de fora.** O Cloud Run reserva os caminhos de URL que terminam em `z`, então uma chamada a `$URL/healthz` recebe uma página 404 do Google, não da aplicação. As checagens de inicialização e de vida continuam funcionando, porque chamam o contêiner direto. Para uma checagem externa, seria preciso um caminho como `/health`.
- **O build do Docker criou três versões no registro.** O Docker recente acrescenta anexos de proveniência, então um único push guardou uma imagem com tag e duas entradas sem tag. A regra "manter as 5 mais recentes" protege essas versões por enquanto; `docker build --provenance=false` gera um só manifesto e deixa o repositório limpo.

## Custo

O nível gratuito do Cloud Run cobre 2 milhões de requisições e 180 mil vCPU-segundo por mês, e o serviço escala até zero quando não há uso. O Artifact Registry inclui 0,5 GB de armazenamento gratuito, e as regras de limpeza mantêm o repositório pequeno. O Secret Manager tem cotas mensais gratuitas de versões ativas e acessos. As cotas gratuitas são compartilhadas pela conta de faturamento; o orçamento do [Lab 04](../04-monitoring-alerts/README.pt-BR.md) avisa se algo crescer.

## Limpeza

```powershell
terraform destroy
gcloud secrets delete lab05-app-greeting   # só se o segredo tiver ficado para trás
```

## Checklist

- [x] Terraform escrito, com implantação em duas etapas e acesso público opcional
- [x] Aplicação com testes (`npm test`) e Dockerfile com usuário sem root
- [x] `terraform fmt`, `validate` e Checkov aprovados localmente e no CI
- [x] Implantado, chamado com token de identidade e injeção do segredo confirmada (`greetingConfigured: true`) em 21/11/2026; sem token o serviço responde 403
