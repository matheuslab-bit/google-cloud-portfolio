#!/usr/bin/env bash
# ------------------------------------------------------------
# auditoria-seguranca.sh
# Revisao rapida de seguranca de um projeto do Google Cloud.
# Procura os problemas que mais aparecem em projeto de verdade:
#   - VM com IP publico
#   - regra de firewall aberta para a internet (0.0.0.0/0)
#   - chave de conta de servico criada por usuario (e a idade dela)
#   - bucket com acesso publico ou sem "public access prevention"
#   - papel Owner/Editor concedido diretamente
#   - VM usando a conta de servico padrao do Compute
#
# Uso:  ./auditoria-seguranca.sh [PROJECT_ID]
# Precisa: gcloud autenticado e papel de leitura no projeto
# (roles/viewer + roles/iam.securityReviewer bastam).
# So le: nao altera nada no projeto.
#
# Se uma consulta falhar (API desligada, falta de permissao), o
# item aparece como [ERRO]. Falha nunca e tratada como [OK].
# ------------------------------------------------------------
set -uo pipefail

PROJECT="${1:-$(gcloud config get-value project 2> /dev/null)}"
if [ -z "$PROJECT" ]; then
    echo "Informe o projeto: ./auditoria-seguranca.sh PROJECT_ID" >&2
    exit 2
fi

ALERTAS=0
ERROS=0
alerta() { echo "  [ALERTA] $1"; ALERTAS=$((ALERTAS + 1)); }
ok() { echo "  [OK] $1"; }
info() { echo "  [INFO] $1"; }
titulo() { echo; echo "== $1"; }

# Roda o gcloud e guarda a saida em RESULTADO. Se falhar, mostra o erro e devolve 1.
# Os avisos (stderr) ficam fora do resultado, e o \r e removido porque o gcloud
# no Windows devolve quebras de linha CRLF.
ERRO_TMP=$(mktemp)
trap 'rm -f "$ERRO_TMP"' EXIT
consultar() {
    local saida
    if saida=$(gcloud "$@" --project "$PROJECT" 2> "$ERRO_TMP"); then
        RESULTADO=$(printf '%s' "$saida" | tr -d '\r')
        return 0
    fi
    echo "  [ERRO] Consulta falhou: $(grep -m1 -E 'ERROR|error' "$ERRO_TMP" || head -n1 "$ERRO_TMP")"
    ERROS=$((ERROS + 1))
    RESULTADO=""
    return 1
}

echo "Auditoria de seguranca do projeto: $PROJECT"

titulo "VMs com IP publico"
if consultar compute instances list \
    --filter="networkInterfaces[].accessConfigs[].natIP:*" \
    --format="value(name,zone.basename())"; then
    if [ -n "$RESULTADO" ]; then
        while read -r nome zona; do
            alerta "$nome ($zona) tem IP externo. Prefira IAP para administrar."
        done <<< "$RESULTADO"
    else
        ok "Nenhuma VM com IP externo."
    fi
fi

titulo "Firewall aberto para a internet (0.0.0.0/0)"
if consultar compute firewall-rules list \
    --filter="direction=INGRESS AND disabled=false AND sourceRanges=('0.0.0.0/0')" \
    --format="value(name,network.basename(),allowed[].map().firewall_rule().list())"; then
    abertas=0
    while read -r nome rede portas; do
        # Regras so de bloqueio (deny) nao tem "allowed" e ficam de fora.
        [ -z "${portas:-}" ] && continue
        abertas=$((abertas + 1))
        case ",$portas," in
            *",tcp:22,"*|*",tcp:3389,"*|*",all,"*|*",tcp,"*|*"tcp:0-65535"*)
                alerta "$nome (rede $rede) libera '$portas' para qualquer IP." ;;
            *)
                info "$nome (rede $rede) libera '$portas' para qualquer IP. Confira se e um servico publico de proposito." ;;
        esac
    done <<< "$RESULTADO"
    [ "$abertas" -eq 0 ] && ok "Nenhuma regra de entrada liberando a internet."
fi

titulo "Chaves de conta de servico criadas por usuario"
if consultar iam service-accounts list --format="value(email)"; then
    contas="$RESULTADO"
    chaves=0
    falhas=0
    for conta in $contas; do
        if ! consultar iam service-accounts keys list --iam-account "$conta" --managed-by=user \
            --format="value(name.basename(),validAfterTime)"; then
            falhas=$((falhas + 1))
            continue
        fi
        while read -r chave criada; do
            [ -z "$chave" ] && continue
            chaves=$((chaves + 1))
            alerta "$conta tem a chave $chave criada em ${criada%%T*}. Prefira Workload Identity Federation."
        done <<< "$RESULTADO"
    done
    [ "$chaves" -eq 0 ] && [ "$falhas" -eq 0 ] && ok "Nenhuma chave criada por usuario."
fi

titulo "Buckets do Cloud Storage"
if consultar storage buckets list --format="value(name)"; then
    buckets="$RESULTADO"
    [ -z "$buckets" ] && ok "Nenhum bucket no projeto."
    for bucket in $buckets; do
        if consultar storage buckets get-iam-policy "gs://$bucket" --format=json; then
            if echo "$RESULTADO" | grep -qE '"allUsers"|"allAuthenticatedUsers"'; then
                alerta "gs://$bucket esta publico (allUsers ou allAuthenticatedUsers no IAM)."
            fi
        fi
        if consultar storage buckets describe "gs://$bucket" --format="value(public_access_prevention)"; then
            if [ "$RESULTADO" = "enforced" ]; then
                ok "gs://$bucket com public access prevention."
            else
                alerta "gs://$bucket nao tem public access prevention ativado."
            fi
        fi
    done
fi

titulo "Papeis Owner e Editor"
if consultar projects get-iam-policy "$PROJECT" --flatten="bindings[].members" \
    --filter="bindings.role:(roles/owner OR roles/editor)" \
    --format="value(bindings.role,bindings.members)"; then
    while read -r papel membro; do
        [ -z "${membro:-}" ] && continue
        case "$membro" in
            serviceAccount:*-compute@developer.gserviceaccount.com)
                alerta "$membro (conta padrao do Compute) tem $papel. O Google concede isso por padrao; remova e use contas dedicadas." ;;
            serviceAccount:*)
                alerta "$membro tem $papel. Conta de servico com papel basico e risco alto." ;;
            *)
                info "$membro tem $papel. Confira se ainda precisa." ;;
        esac
    done <<< "$RESULTADO"
fi

titulo "VMs usando a conta de servico padrao do Compute"
if consultar compute instances list \
    --filter="serviceAccounts.email~-compute@developer.gserviceaccount.com" \
    --format="value(name)"; then
    if [ -n "$RESULTADO" ]; then
        for vm in $RESULTADO; do alerta "$vm usa a conta padrao, que costuma ter Editor no projeto."; done
    else
        ok "Nenhuma VM com a conta de servico padrao."
    fi
fi

echo
echo "Fim da auditoria: $ALERTAS alerta(s), $ERROS consulta(s) com erro."
[ "$ALERTAS" -eq 0 ] && [ "$ERROS" -eq 0 ]
