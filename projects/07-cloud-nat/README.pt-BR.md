# Lab 07 - Cloud NAT para a VM privada

[English](README.md) | [Português (Brasil)](README.pt-BR.md)

**Situação:** implantado, testado e destruído em 21/11/2026 (o NAT ficou no ar por cerca de 2 minutos). O código fica pronto para ligar de novo quando a VM precisar de atualização.

A VM do [Lab 02](../02-secure-compute-engine/README.pt-BR.md) não tem IP público. O IAP me dá um caminho de **entrada** para administrá-la, mas não dá à VM um caminho de **saída**: sem rota para a internet, ela não consegue nem rodar `apt update`. Este lab cria esse caminho de saída com Cloud NAT, sem dar IP público à VM e sem abrir nenhuma porta de entrada.

## Como funciona

```text
lab02-secure-vm (10.20.0.2, sem IP público)
   │  conexão de saída (por exemplo, apt update)
   ▼
Cloud Router "lab07-nat-router" + Cloud NAT "lab07-nat"  (us-central1)
   │  troca o IP interno por um IP externo gerenciado pelo Google
   ▼
Internet  ── a resposta volta pela mesma tradução; ninguém consegue iniciar conexão de fora
```

## O que é criado

| Recurso | Detalhe |
| --- | --- |
| Cloud Router `lab07-nat-router` | Em `us-central1`, na `portfolio-vpc`. Sem BGP: só hospeda a configuração do NAT |
| Cloud NAT `lab07-nat` | IP externo automático (`AUTO_ONLY`), só para a sub-rede `lab02-iowa-subnet`, com log apenas de erros |

A VPC e a sub-rede são lidas por data source. Este lab não mexe no state dos labs 01 e 02.

## Decisões que tomei

- **Só a sub-rede que precisa.** `LIST_OF_SUBNETWORKS` em vez de "todas as sub-redes da região". Se outra sub-rede for criada em Iowa, ela não ganha saída para a internet por acidente.
- **IP automático, não reservado.** Com `AUTO_ONLY`, o Google cuida do IP e ele some junto com o NAT no `destroy`. Um IP reservado e esquecido continua sendo cobrado.
- **Log só de erros.** `ERRORS_ONLY` registra, por exemplo, falta de portas, que é o que serve para diagnosticar problemas, com volume de log mínimo.
- **Saída não é entrada.** O NAT só traduz conexões que a VM inicia. O firewall de entrada do Lab 02 continua igual: SSH só pelo IAP.
- **Ligar só quando precisar.** O NAT cobra por hora enquanto existe (veja Custo). Como está tudo no Terraform, criar, usar e destruir são três comandos.

## Checkov

Nenhum alerta. O Checkov 3.4.6 não tem checagens para Cloud Router e Cloud NAT, e a varredura de todos os labs continua com 0 falhas (72 aprovadas, 9 aceitas com justificativa nos outros labs).

## Como rodar

É preciso `roles/compute.networkAdmin` (ou dono do projeto) para criar o Cloud Router e o NAT.

```powershell
cd projects/07-cloud-nat
Copy-Item terraform.tfvars.example terraform.tfvars   # defina project_id
terraform init -lockfile=readonly
terraform plan
terraform apply
```

## Como testar

Antes do `apply`, a VM não sai para a internet:

```powershell
gcloud compute ssh lab02-secure-vm --zone=us-central1-a --tunnel-through-iap --command="curl -sS -m 10 -o /dev/null -w '%{http_code}' https://deb.debian.org/"
# curl: (28) Connection timed out ... -> 000
```

Depois do `apply`, o mesmo comando deve responder `200`, e `sudo apt-get update` deve funcionar.

## Custo

O Cloud NAT cobra enquanto existe, mesmo parado:

- uma taxa por hora do gateway para cada VM que usa o NAT;
- o IP externo que o NAT usa, cobrado por hora;
- cada GB processado pelo NAT.

Para uma VM, isso dá alguns dólares por mês se o NAT ficar ligado o mês inteiro. Pela minha meta de gastar menos de US$ 10 por mês, o plano é ligar o NAT só para atualizar a VM e depois rodar `terraform destroy`. Confira os valores atuais nas páginas de preço do [Cloud NAT](https://cloud.google.com/nat/pricing) e dos [endereços IP](https://cloud.google.com/vpc/network-pricing#ipaddress). O orçamento do [Lab 04](../04-monitoring-alerts/README.pt-BR.md) avisa se algo crescer.

## Limpeza

```powershell
terraform destroy
```

Como o IP é automático, nada fica para trás.

## Checklist

- [x] Terraform escrito (`versions.tf`, `variables.tf`, `main.tf`, `outputs.tf`, `backend.tf`)
- [x] `terraform fmt`, `validate` e Checkov aprovados localmente
- [x] Linha de base registrada: sem NAT, a VM não sai para a internet (`curl` com timeout, 21/11/2026)
- [x] Implantado e saída testada da VM em 21/11/2026: `curl` 200, `apt-get update` baixou 2,4 MB, IP de saída gerenciado pelo Google; 2 pacotes atualizáveis, nenhum de segurança
- [x] Destruído depois do teste: nenhum Cloud Router nem IP sobrando, e a VM voltou a dar timeout (`curl` 000)
