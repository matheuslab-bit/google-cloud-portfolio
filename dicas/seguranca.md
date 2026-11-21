# Segurança no Google Cloud

## O que a auditoria achou no meu próprio projeto

Quando terminei o [script de auditoria](../scripts/auditoria-seguranca.sh), rodei no projeto destes labs. Ele achou três coisas que eu não tinha criado:

```text
[ALERTA] default-allow-rdp (rede default) libera 'tcp:3389' para qualquer IP.
[ALERTA] default-allow-ssh (rede default) libera 'tcp:22' para qualquer IP.
[ALERTA] serviceAccount:...-compute@developer.gserviceaccount.com (conta padrao do Compute) tem roles/editor.
```

As três vêm de fábrica: ao ativar a API do Compute, o Google cria a rede `default` com SSH e RDP abertos para a internet e dá papel de Editor à conta de serviço padrão. Os meus labs usam a `portfolio-vpc` e contas dedicadas, então nada estava exposto. Mesmo assim, é o tipo de configuração que fica esquecida até alguém criar uma VM na rede errada.

Para corrigir:

```bash
# remover as regras abertas (ou a rede default inteira, se não for usada)
gcloud compute firewall-rules delete default-allow-ssh default-allow-rdp
gcloud compute networks delete default        # apaga antes as regras restantes da rede

# tirar o Editor da conta padrão
gcloud projects remove-iam-policy-binding MEU_PROJETO \
  --member="serviceAccount:NUMERO-compute@developer.gserviceaccount.com" --role="roles/editor"
```

Em organizações, a política `iam.automaticIamGrantsForDefaultServiceAccounts` impede esse Editor automático em projetos novos.

## Checklist que eu uso

- **Sem IP público em VM.** Administração pelo IAP (`--tunnel-through-iap`), com firewall liberando só `35.235.240.0/20`.
- **Sem chave de conta de serviço.** Chave JSON vaza em repositório, em e-mail, em print. Para CI, Workload Identity Federation ([Lab 06](../projects/06-workload-identity-federation/README.pt-BR.md)). Para VMs e Cloud Run, a conta anexada ao recurso.
- **Uma conta de serviço por carga, com o mínimo de papéis.** Nunca a conta padrão do Compute.
- **Nada de Owner/Editor para contas de serviço.** Papéis básicos são amplos demais. O Checkov aponta isso (`CKV_GCP_117`).
- **Bucket com `public_access_prevention = enforced` e acesso uniforme.** Impede que um `allUsers` esquecido deixe dados públicos.
- **Segredo no Secret Manager**, nunca em variável de ambiente fixa no código ou no Terraform.
- **OS Login nas VMs**, em vez de chaves SSH espalhadas nos metadados do projeto.
- **Alerta de mudança de IAM.** Os logs de auditoria Admin Activity são gratuitos e sempre ligados ([Lab 04](../projects/04-monitoring-alerts/README.pt-BR.md)).

## Prioridade de firewall no GCP

Número menor ganha. Regras com prioridade igual, bloqueio ganha de liberação. No Lab 02, a liberação do IAP está em 900 e o bloqueio do resto em 901: as duas passam na frente das regras comuns de prioridade 1000, que alguém pode criar depois sem perceber o efeito.

## Onde investigar um incidente

- **Quem fez o quê:** Logs Explorer, filtrando por `protoPayload.authenticationInfo.principalEmail`.
- **Mudanças de permissão:** `protoPayload.methodName="SetIamPolicy"`.
- **Acessos a dados** (leitura de objetos, por exemplo): só aparecem se os logs Data Access estiverem ligados para o serviço. Eles vêm desligados por padrão, porque têm custo.
