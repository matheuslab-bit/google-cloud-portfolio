# Projetos

[English](README.md) | [Português (Brasil)](README.pt-BR.md)

Meus labs de Google Cloud. Em cada um, anoto separadamente o que passou na validação do código, o que está implantado e o que eu testei.

## Labs

**[01: Rede VPC](01-vpc-network/README.pt-BR.md)**
VPC em modo personalizado (`portfolio-vpc`) e uma sub-rede (`10.10.0.0/24`) em São Paulo (`southamerica-east1`).
Implantado. CI aprovado no [PR #1](https://github.com/matheuslab-bit/matheuslab-bit/pull/1). State migrado para o GCS em 20/11/2026 sem nenhuma mudança no `terraform plan`, e `backend.tf` adicionado no [PR #10](https://github.com/matheuslab-bit/matheuslab-bit/pull/10).

**[02: VM privada](02-secure-compute-engine/README.pt-BR.md)**
Debian 12 `e2-micro` em Iowa (`us-central1-a`) com sub-rede própria (`10.20.0.0/24`), SSH só pelo IAP, OS Login, Shielded VM e regras de firewall com prioridade `900`/`901`.
Configuração de Iowa integrada no [PR #4](https://github.com/matheuslab-bit/matheuslab-bit/pull/4). Implantado e SSH pelo IAP testado em 18/11/2026. State migrado para o GCS em 20/11/2026 sem mudanças, `backend.tf` no [PR #10](https://github.com/matheuslab-bit/matheuslab-bit/pull/10).

**[03: Bucket de state do Terraform](03-terraform-backend/README.pt-BR.md)**
Bucket do Cloud Storage em Iowa (`us-central1`) com versionamento de objetos, Soft Delete de 7 dias, regra de 90 dias para versões antigas, acesso uniforme, acesso público bloqueado e proteção contra exclusão.
Implantado em 20/11/2026 ([PR #9](https://github.com/matheuslab-bit/matheuslab-bit/pull/9)). Guarda o state atual dos labs 01 e 02.

**[04: Monitoramento, alertas e orçamento](04-monitoring-alerts/README.pt-BR.md)**
Canal de e-mail, alertas de CPU acima de 80%, VM em silêncio por 5 minutos e qualquer mudança de política de IAM (a partir dos logs de auditoria gratuitos), mais um orçamento mensal com alerta de previsão.
Implantado e alertas disparados num teste em 21/11/2026.

**[05: Aplicação no Cloud Run](05-cloud-run-app/README.pt-BR.md)**
API de status em Node.js num contêiner, Artifact Registry com regras de limpeza, serviço privado no Cloud Run com conta de serviço própria e um segredo no Secret Manager cujo valor nunca passa pelo Terraform.
Validado no CI (fmt, validate, Checkov, testes da aplicação). Ainda não implantado.

**[06: Workload Identity Federation](06-workload-identity-federation/README.pt-BR.md)**
O GitHub Actions recebe credenciais de vida curta sem nenhuma chave guardada. A condição de confiança fixa o repositório e o campo `sub`, e a identidade do CI tem só papéis de leitura específicos.
Validado no CI (fmt, validate, Checkov). Ainda não implantado.

## Observações

- O Lab 02 lê a `portfolio-vpc` do Lab 01 por um data source e cuida só da própria sub-rede em Iowa.
- Os labs 04 a 06 são independentes entre si e dos labs 01 a 03, e vão usar prefixos próprios no mesmo bucket.
- Os labs 01 e 02 guardam o state no bucket do Lab 03, cada um no seu prefixo, com lock. O Lab 03 mantém o próprio state local (mais um backup separado, fora do repositório), porque um bucket não consegue guardar o próprio state com segurança.
- Custo: a VM `e2-micro`, o disco `pd-standard` de 10 GB e o bucket (cerca de 24 KB de state) cabem no nível gratuito mensal. Cotas compartilhadas, tráfego de saída e outros serviços ainda podem gerar cobrança.

## Arquivo

[GCP Secure Infrastructure (arquivado)](archive/gcp-secure-infrastructure/README.md): minha primeira tentativa, um Terraform grande com computação, segurança e monitoramento juntos. Troquei pelos labs 01 a 03 e mantive pelas ideias de monitoramento.

## Planejado

- Cloud NAT para saída controlada da VM privada
- Cloud SQL com acesso privado para a aplicação do Cloud Run
- Módulos reutilizáveis de Terraform

O que está planejado só entra na lista acima quando existir.

Nunca coloque segredos, state do Terraform ou credenciais no Git. Este é um portfólio de estudo, não um serviço de produção.
