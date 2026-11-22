# Estudando para a Associate Cloud Engineer

A ACE cobra o dia a dia de quem opera o Google Cloud: criar recursos, dar acesso, manter rodando e controlar custo. Estou estudando montando os labs deste repositório, porque cada tópico da prova vira algo que eu precisei fazer de verdade.

## Os tópicos da prova e onde pratiquei

| Área da prova | Onde pratiquei |
| --- | --- |
| Configurar o ambiente: projetos, faturamento, APIs, orçamentos | Projeto próprio, APIs pelo Terraform e orçamento no [Lab 04](../projects/04-monitoring-alerts/README.md) |
| Planejar e configurar: Compute, rede, armazenamento | VPC no [Lab 01](../projects/01-vpc-network/README.md), VM no [Lab 02](../projects/02-secure-compute-engine/README.md), bucket no [Lab 03](../projects/03-terraform-backend/README.md) |
| Implantar e implementar: VMs, Cloud Run, Terraform | Labs 02 e [05](../projects/05-cloud-run-app/README.md), todos com Terraform |
| Garantir a operação: monitoramento, logs, recuperação | Alertas no Lab 04, recuperação de state no Lab 03 |
| Configurar acesso e segurança: IAM, contas de serviço | Contas dedicadas em todos os labs, IAP e OS Login no Lab 02, Workload Identity no [Lab 06](../projects/06-workload-identity-federation/README.md) |

## O que costuma confundir (e cai na prova)

- **Papel básico, predefinido e personalizado.** Owner, Editor e Viewer são básicos e amplos demais. Os predefinidos (como `roles/compute.viewer`) são a escolha certa na maioria das questões.
- **Conta de serviço é identidade e também recurso.** Dar `roles/iam.serviceAccountUser` em uma conta permite agir como ela, o que é muito poder.
- **Classes de armazenamento:** Standard, Nearline (30 dias), Coldline (90 dias) e Archive (365 dias). A prova cobra a escolha pelo padrão de acesso, e o tempo mínimo de cobrança.
- **Load balancers:** global ou regional, externo ou interno, HTTP(S) ou TCP/UDP. Montar a tabela de quando usar cada um ajuda muito.
- **Quem cobra o quê na rede:** entrada é grátis; saída para a internet e entre regiões é cobrada.
- **`gcloud` de cabeça:** a prova mostra comandos. Saber a estrutura `gcloud GRUPO RECURSO VERBO` resolve muitas questões.

## Como estou estudando

1. O guia oficial da prova, item por item.
2. Para cada item, um lab pequeno no meu projeto, sempre com Terraform e com o custo conferido.
3. Uma anotação curta do que deu errado, que vira dica nesta pasta.
4. Simulados no fim de cada área, revendo os erros.
