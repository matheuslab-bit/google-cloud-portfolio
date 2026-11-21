# Lab 04 - Monitoramento, alertas e orçamento

[English](README.md) | [Português (Brasil)](README.pt-BR.md)

**Situação:** implantado em 21/11/2026 (9 recursos, `terraform plan` sem mudanças depois). Alertas disparados num teste no mesmo dia; falta conferir a chegada dos e-mails.

VM que ninguém monitora só recebe atenção quando o usuário reclama. Este lab cria os alertas que eu gostaria de ter desde o primeiro dia: a VM do Lab 02 com CPU alta ou parada, um alerta de segurança quando alguém muda permissões no IAM e um orçamento mensal que avisa antes de a fatura assustar.

## O que é criado

| Recurso | O que faz |
| --- | --- |
| Canal de notificação (e-mail) | Para onde vão todos os alertas e avisos de orçamento |
| Alerta: CPU alta | Abre um incidente quando a `lab02-secure-vm` fica acima de 80% de CPU por 5 minutos |
| Alerta: VM em silêncio | Abre um incidente quando a VM para de enviar a métrica de uptime por 5 minutos (desligada ou travada) |
| Métrica de log + alerta | Conta as chamadas `SetIamPolicy` nos logs de auditoria e alerta em qualquer mudança de acesso |
| Orçamento mensal | Avisa em 50%, 90% e 100% do valor, e também quando a **previsão** passa de 100% |
| APIs | Ativa Monitoring, Logging e Billing Budgets (e mantém ativas se o lab for destruído) |

Cada alerta traz uma nota curta dizendo a quem recebe o que verificar primeiro.

## Por que fiz assim

- **CPU sem agente.** A métrica de CPU vem do hipervisor, então funciona sem instalar o Ops Agent na VM. Memória e disco precisariam do agente; deixei isso para quando a VM rodar uma carga de verdade.
- **"Ausente" em vez de "abaixo de".** Quando a VM para, as métricas simplesmente deixam de chegar, e um limite comum nunca dispara sem dados. O `condition_absent` transforma esse silêncio em alerta.
- **Alerta de segurança de graça.** Os logs de auditoria Admin Activity estão sempre ligados e não custam nada. Transformá-los em métrica é um jeito barato de saber quando permissões mudam, uma das primeiras coisas que um invasor faz.
- **Gasto previsto.** O orçamento nunca para a cobrança, só avisa. A regra de previsão avisa enquanto ainda dá tempo de agir.
- **Créditos promocionais não escondem o gasto.** O orçamento desconta o Free Tier e os descontos automáticos, mas não os créditos promocionais (trial e créditos mensais). Se descontasse tudo, o gasto apareceria como zero enquanto os créditos pagam a conta, e o aviso só chegaria quando eles acabassem. Minha meta é gastar menos de US$ 10 por mês; como a conta de faturamento é em reais, o orçamento é de R$ 50, um pouco abaixo da meta.
- **Variáveis conferidas antes de qualquer chamada à API:** ID do projeto, e-mail, formato da conta de faturamento, moeda e limite de CPU.

## Checkov

Nenhum alerta. Os recursos deste lab são objetos de monitoramento e faturamento, que o Checkov não aponta.

## Como rodar

É preciso o ID da conta de faturamento do projeto e o papel `roles/billing.costsManager` (ou Administrador da conta de faturamento) para criar o orçamento, além de `roles/monitoring.editor` e `roles/logging.configWriter` no projeto.

A API Cloud Resource Manager precisa estar ativa antes do primeiro `plan`. O Terraform lê o número do projeto por ela (o orçamento só aceita `projects/<número>`), e essa leitura acontece antes de qualquer API ser ativada pelo próprio lab. Sem ela, o `plan` falha com erro 403 `SERVICE_DISABLED`. A ativação é gratuita:

```powershell
gcloud services enable cloudresourcemanager.googleapis.com --project=SEU_PROJETO
```

```powershell
cd projects/04-monitoring-alerts
Copy-Item terraform.tfvars.example terraform.tfvars
# defina project_id, alert_email, billing_account, monthly_budget e currency_code
terraform init -lockfile=readonly
terraform plan
```

O state vai para o bucket do Lab 03, no prefixo `labs/04-monitoring-alerts` ([`backend.tf`](backend.tf)).

Para validar sem credenciais, como o CI faz:

```powershell
terraform fmt -check -recursive
terraform init -backend=false -lockfile=readonly -input=false
terraform validate
```

## Como testar depois de implantar

- Confirme o canal de e-mail (o Google manda uma mensagem de verificação).
- Conceda e remova qualquer papel no IAM: o alerta de segurança deve chegar em poucos minutos.
- Desligue a VM: o alerta "VM em silêncio" deve abrir em cerca de 5 minutos e fechar quando ela voltar.
- Em Faturamento > Orçamentos, confira se o orçamento mostra o projeto e os limites.

## Custo

Políticas de alerta, canais de notificação, orçamentos e uma métrica de log de baixo volume ficam dentro das cotas gratuitas de monitoramento e logs. A VM monitorada é a do Lab 02, então este lab não gera cobrança nova.

## Checklist

- [x] Terraform escrito (`versions.tf`, `variables.tf`, `main.tf`, `outputs.tf`, `backend.tf`)
- [x] `terraform fmt`, `validate` e Checkov aprovados localmente e no CI
- [x] Implantado em 21/11/2026
- [x] Alertas disparados em 21/11/2026: IAM (a métrica de log contou 2 chamadas `SetIamPolicy` depois de conceder e remover `roles/viewer`) e VM em silêncio (VM desligada por cerca de 7 minutos, lacuna na métrica de uptime confirmada); orçamento conferido no faturamento
- [ ] E-mails dos alertas conferidos na caixa de entrada
