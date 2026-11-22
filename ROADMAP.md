# Roadmap

O meu plano de estudos de Google Cloud. Só marco um item como feito quando existe prova publicada: o README de um lab com o teste registrado ou uma execução do CI.

## Feito

- [x] Rede e computação: VPC ([lab 01](projects/01-vpc-network/README.md)) e VM privada com IAP e OS Login ([lab 02](projects/02-secure-compute-engine/README.md))
- [x] Terraform com state remoto, versionado e com trava ([lab 03](projects/03-terraform-backend/README.md))
- [x] Monitoramento, alertas e orçamento testados ([lab 04](projects/04-monitoring-alerts/README.md))
- [x] Aplicação em contêiner no Cloud Run com segredo no Secret Manager ([lab 05](projects/05-cloud-run-app/README.md))
- [x] CI sem chave guardada, com `terraform plan` em cada pull request ([lab 06](projects/06-workload-identity-federation/README.md))
- [x] Saída para a internet da VM privada com Cloud NAT, ligado só quando preciso ([lab 07](projects/07-cloud-nat/README.md))
- [x] Scripts de auditoria de segurança e de custos, com os achados corrigidos ([scripts](scripts/README.md))

## Próximo

1. Cloud SQL com acesso privado para a aplicação do Cloud Run, implantado e destruído no mesmo dia para caber no orçamento.
2. Módulos reutilizáveis de Terraform.
3. Certificação Associate Cloud Engineer ([como estou estudando](dicas/estudando-para-ace.md)).

## Registro

- **18/11/2026:** labs 01 e 02 com o CI aprovado. VM implantada em Iowa e acesso SSH pelo IAP testado.
- **20/11/2026:** lab 03 implantado e state dos labs 01 e 02 migrado para o bucket, sem nenhuma mudança no `plan`. CI unificado com Checkov.
- **21/11/2026:** labs 04, 05 e 06 implantados e testados. A auditoria de segurança achou SSH e RDP abertos na rede `default` e o papel Editor na conta de serviço padrão: os três foram corrigidos, e a auditoria agora termina com 0 alertas.
- **21/11/2026:** lab 07 implantado, testado e destruído em cerca de 2 minutos.
