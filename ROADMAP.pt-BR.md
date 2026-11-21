# Roadmap

[English](ROADMAP.md) | [Português (Brasil)](ROADMAP.pt-BR.md)

Meu plano de estudos de Google Cloud. É um plano, não uma lista do que eu já domino. Só marco um item quando existe algo publicado que comprove (README de lab, pull request ou execução do CI).

## Progresso

- [ ] Fundamentos de nuvem e redes
- [ ] Lab de fundamentos de Linux
- [x] Primeiro projeto no GCP com proteções de cobrança (orçamento e alertas implantados e testados no [Lab 04](projects/04-monitoring-alerts/README.pt-BR.md))
- [x] Compute Engine e VPC: [Lab 01](projects/01-vpc-network/README.pt-BR.md) e [Lab 02](projects/02-secure-compute-engine/README.pt-BR.md)
- [ ] Lab de IAM e segurança (parte já coberta no Lab 02: conta de serviço dedicada, IAP, OS Login)
- [ ] Aplicação publicada no Cloud Run (código pronto no [Lab 05](projects/05-cloud-run-app/README.pt-BR.md))
- [ ] Lab de monitoramento e logs (código pronto no [Lab 04](projects/04-monitoring-alerts/README.pt-BR.md))
- [x] Projeto com Terraform: labs 01 a 03 com state remoto no GCS
- [x] Três projetos documentados no portfólio: [índice de projetos](projects/README.pt-BR.md)
- [ ] Preparação para a prova Associate Cloud Engineer

## Registro

- **18/11/2026:** Lab 01 (VPC) e Lab 02 (VM privada com IAP e OS Login) integrados com o CI aprovado. Lab 02 implantado em Iowa e acesso SSH testado.
- **20/11/2026:** Lab 03 (state remoto no GCS) implantado. O state dos labs 01 e 02 foi migrado para o GCS, e o `terraform plan` não mostrou nenhuma mudança.
- **20/11/2026:** CI unificado num único workflow do Terraform com análise do Checkov. Os riscos aceitos ficaram anotados ao lado de cada recurso.
- **21/11/2026:** Labs 04 (monitoramento e orçamento), 05 (Cloud Run) e 06 (Workload Identity Federation) escritos e validados no CI. Scripts de auditoria e de custos testados neste projeto; a auditoria achou SSH e RDP abertos na rede `default` e Editor na conta de serviço padrão do Compute.
- **21/11/2026:** Achados da auditoria corrigidos (primeiro o backup, depois as duas regras da rede `default` apagadas e o Editor removido da conta de serviço padrão do Compute). A auditoria agora termina com 0 alertas.
- **21/11/2026:** Lab 04 implantado: canal de e-mail, três alertas (CPU, VM em silêncio, mudança de IAM) e um orçamento de R$ 50 por mês que desconta o Free Tier, mas não os créditos promocionais, para manter o gasto abaixo de US$ 10 por mês. Faltava ativar a API Cloud Resource Manager (agora está no README do lab).

## Próximos passos

1. Implantar o Lab 06 e ligar o `terraform plan` sem chave nos pull requests.
2. Implantar os labs 04 e 05 e marcar os checklists.
3. Cloud NAT para a VM privada e depois Cloud SQL com acesso privado.

## O que ainda quero estudar

**Base do Google Cloud:** organizações, pastas e projetos; IAM e contas de serviço; Compute Engine e Cloud Storage; VPC, rotas e firewall; Cloud DNS, Cloud SQL e Cloud Run; balanceamento de carga.

**Operação e segurança:** Cloud Logging e Monitoring; alertas e logs de auditoria; Secret Manager e Cloud KMS; backup e recuperação.

**Automação:** módulos de Terraform; Docker; noções de Kubernetes e GKE; Cloud Build, Artifact Registry e GitHub Actions; Bash e Python.

**Certificação:** Associate Cloud Engineer, com labs de prática e revisão dos meus pontos fracos.

Minha rotina é de cerca de 10 horas por semana, divididas entre estudo, labs guiados, refazer as coisas sozinho e escrever a documentação.
