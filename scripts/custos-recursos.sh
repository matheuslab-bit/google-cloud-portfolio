#!/usr/bin/env bash
# ------------------------------------------------------------
# custos-recursos.sh
# Procura recursos esquecidos que continuam gerando cobranca:
#   - discos sem nenhuma VM usando
#   - IPs estaticos reservados e sem uso (sao cobrados parados)
#   - VMs paradas (a VM nao cobra, mas o disco dela sim)
#   - snapshots com mais de 90 dias
#   - VMs ligadas e o tipo de cada uma
#
# Uso:  ./custos-recursos.sh [PROJECT_ID]
# So le: nao apaga nada. A decisao de remover e sempre manual.
# Se uma consulta falhar, aparece [ERRO] em vez de "nada encontrado".
# ------------------------------------------------------------
set -uo pipefail

PROJECT="${1:-$(gcloud config get-value project 2> /dev/null)}"
if [ -z "$PROJECT" ]; then
    echo "Informe o projeto: ./custos-recursos.sh PROJECT_ID" >&2
    exit 2
fi

ERROS=0
titulo() { echo; echo "== $1"; }

# Mostra o resultado de uma consulta, "nada encontrado" quando vazia, ou [ERRO] quando falha.
# Os avisos do gcloud (stderr) ficam fora da saida; o \r do Windows e removido.
ERRO_TMP=$(mktemp)
trap 'rm -f "$ERRO_TMP"' EXIT
mostrar() {
    local vazio="$1" saida
    shift
    if saida=$(gcloud "$@" --project "$PROJECT" 2> "$ERRO_TMP"); then
        saida=$(printf '%s' "$saida" | tr -d '\r')
        if [ -n "$saida" ]; then echo "$saida"; else echo "  (nada encontrado) $vazio"; fi
    else
        echo "  [ERRO] Consulta falhou: $(grep -m1 -E 'ERROR|error' "$ERRO_TMP" || head -n1 "$ERRO_TMP")"
        ERROS=$((ERROS + 1))
    fi
}

echo "Recursos que podem estar custando sem necessidade no projeto: $PROJECT"

titulo "Discos sem VM (cobrados por GB, mesmo sem uso)"
mostrar "Nenhum disco solto." compute disks list --filter="-users:*" \
    --format="table(name,zone.basename(),sizeGb,type.basename(),creationTimestamp.date('%Y-%m-%d'))"

titulo "IPs estaticos reservados e sem uso"
mostrar "Nenhum IP parado." compute addresses list --filter="status=RESERVED" \
    --format="table(name,region.basename(),address,addressType)"

titulo "VMs paradas (o disco continua sendo cobrado)"
mostrar "Nenhuma VM parada." compute instances list --filter="status=TERMINATED" \
    --format="table(name,zone.basename(),machineType.basename(),lastStopTimestamp.date('%Y-%m-%d'))"

titulo "Snapshots com mais de 90 dias"
mostrar "Nenhum snapshot antigo." compute snapshots list --filter="creationTimestamp<-P90D" \
    --format="table(name,diskSizeGb,creationTimestamp.date('%Y-%m-%d'))"

titulo "VMs ligadas agora"
mostrar "Nenhuma VM ligada." compute instances list --filter="status=RUNNING" \
    --format="table(name,zone.basename(),machineType.basename(),scheduling.provisioningModel)"

echo
echo "Dica: para ver o gasto real por servico, use Faturamento > Relatorios no console,"
echo "ou exporte o faturamento para o BigQuery e consulte por label."
[ "$ERROS" -eq 0 ]
