# Scripts

Scripts com `gcloud` para olhar um projeto do Google Cloud rapidamente. Os dois só leem: não alteram nem apagam nada.

## `auditoria-seguranca.sh`

Revisão rápida dos problemas de segurança que mais aparecem em projetos de verdade:

- VM com IP público
- regra de firewall aberta para a internet (`0.0.0.0/0`), com destaque para SSH (22) e RDP (3389)
- chave de conta de serviço criada por usuário, com a data de criação
- bucket público ou sem *public access prevention*
- papel Owner ou Editor concedido direto, principalmente para conta de serviço
- VM usando a conta de serviço padrão do Compute

```bash
./auditoria-seguranca.sh meu-projeto
```

Mostra `[OK]`, `[INFO]` ou `[ALERTA]` em cada item e termina com código 1 se encontrar algum alerta. Dá para usar no CI ou numa rotina agendada.

## `custos-recursos.sh`

Procura o que continua cobrando sem ninguém usar:

- discos sem nenhuma VM
- IPs estáticos reservados e parados (cobrados justamente por estarem parados)
- VMs desligadas, cujo disco continua sendo cobrado
- snapshots com mais de 90 dias
- VMs ligadas e o tipo de máquina de cada uma

```bash
./custos-recursos.sh meu-projeto
```

## Permissões

`roles/viewer` e `roles/iam.securityReviewer` no projeto bastam para os dois. No Cloud Shell eles já rodam direto, porque o `gcloud` vem instalado e autenticado.

## Qualidade

Os dois passam pelo ShellCheck no CI a cada mudança.
