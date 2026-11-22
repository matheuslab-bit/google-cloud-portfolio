# Custos sem susto

Os meus labs rodam dentro do nível gratuito, mas "gratuito" tem regras. O que eu aprendi:

## O nível gratuito tem pegadinhas

- **Região importa.** A `e2-micro` gratuita vale só em `us-central1`, `us-west1` e `us-east1`. A mesma VM em São Paulo é cobrada. Por isso a VM do Lab 02 está em Iowa.
- **É uma por conta de faturamento, não por projeto.** Duas `e2-micro` em projetos diferentes da mesma conta: uma é cobrada.
- **Disco padrão, não SSD.** São 30 GB de `pd-standard`. Um `pd-balanced` ou SSD sai da cota.
- **IP externo é cobrado.** Uma VM sem IP público, acessada pelo IAP, foge desse custo e ainda é mais segura.
- **Tráfego de saída** para a internet, entre regiões e entre continentes é cobrado à parte.

## O que costuma ficar esquecido

| Recurso | Por que cobra |
| --- | --- |
| Disco de VM apagada | O disco pode ter sido criado sem `auto_delete` |
| IP estático reservado | Cobrado justamente quando **não** está em uso |
| VM desligada | A VM não cobra, mas o disco e o IP dela sim |
| Snapshots antigos | Ficam acumulando |
| Imagens antigas no Artifact Registry | Cada versão ocupa espaço |

O [`custos-recursos.sh`](../scripts/custos-recursos.sh) lista tudo isso num comando.

## O que eu faço

- **Orçamento com alerta desde o primeiro dia**, incluindo o alerta de gasto **previsto** ([Lab 04](../projects/04-monitoring-alerts/README.md)). Lembrando: orçamento avisa, mas não bloqueia.
- **Escalar até zero.** Cloud Run com `min_instance_count = 0` não custa nada parado.
- **Limite máximo de instâncias.** Protege a fatura se o serviço receber tráfego inesperado.
- **Regras de ciclo de vida.** No bucket de state, versões antigas saem depois de 90 dias. No Artifact Registry, ficam só as 5 imagens mais recentes.
- **Labels em tudo** (`ambiente=lab`, `dono=matheus`), para separar o custo por projeto nos relatórios.
- **Exportar o faturamento para o BigQuery** quando o gasto ficar sério: dá para consultar com SQL o custo por serviço, por label e por dia.

## Para economizar de verdade em produção

- **VMs Spot** para cargas que aguentam interrupção (processamento em lote, CI): bem mais baratas que as normais.
- **Descontos por uso contínuo** aparecem sozinhos para VMs ligadas boa parte do mês.
- **Compromisso de uso** (1 ou 3 anos) para a carga base que nunca desliga.
- **Ajustar o tamanho da máquina.** O console mostra recomendações de redimensionamento a partir do uso real de CPU e memória.
