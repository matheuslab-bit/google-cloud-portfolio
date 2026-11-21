# gcloud essencial

Os comandos que eu mais uso, por tarefa. Tudo funciona no Cloud Shell, que já vem com o `gcloud` instalado e autenticado.

## Configuração e contexto

```bash
gcloud auth login                              # login da pessoa (console e gcloud)
gcloud auth application-default login          # credencial que o Terraform e as bibliotecas usam
gcloud config set project MEU_PROJETO
gcloud config list                             # projeto, conta e região ativos

# vários projetos: uma configuração para cada, e troca rápida
gcloud config configurations create lab
gcloud config configurations activate lab
```

`gcloud auth login` e `gcloud auth application-default login` são credenciais diferentes. O Terraform usa a segunda. Muito "permission denied" no Terraform é só isso.

## Compute Engine

```bash
gcloud compute instances list
gcloud compute instances describe VM --zone us-central1-a --format="value(status,networkInterfaces[0].networkIP)"
gcloud compute instances stop VM --zone us-central1-a
gcloud compute instances get-serial-port-output VM --zone us-central1-a   # boot travado? começa por aqui

# SSH sem IP público, pelo IAP
gcloud compute ssh VM --zone us-central1-a --tunnel-through-iap

# túnel para qualquer porta (por exemplo RDP numa VM Windows privada)
gcloud compute start-iap-tunnel VM 3389 --local-host-port=localhost:13389 --zone us-central1-a
```

## Rede

```bash
gcloud compute networks list
gcloud compute networks subnets list --network portfolio-vpc
gcloud compute firewall-rules list --format="table(name,direction,priority,sourceRanges.list(),allowed[].map().firewall_rule().list())"

# regras abertas para a internet
gcloud compute firewall-rules list --filter="sourceRanges=('0.0.0.0/0')"
```

Repare no filtro: `sourceRanges:0.0.0.0/0` dá erro de expressão inválida. O formato que funciona é `sourceRanges=('0.0.0.0/0')`.

## IAM

```bash
# quem tem qual papel no projeto, uma linha por pessoa
gcloud projects get-iam-policy MEU_PROJETO --flatten="bindings[].members" \
  --format="table(bindings.role,bindings.members)"

# o que um papel permite
gcloud iam roles describe roles/compute.viewer

gcloud iam service-accounts list
gcloud iam service-accounts keys list --iam-account CONTA@MEU_PROJETO.iam.gserviceaccount.com --managed-by=user
```

## Cloud Storage

```bash
gcloud storage ls
gcloud storage ls --all-versions gs://BUCKET/caminho/arquivo   # versões antigas (com versionamento ligado)
gcloud storage buckets describe gs://BUCKET --format="value(public_access_prevention,versioning_enabled)"
gcloud storage cp arquivo.txt gs://BUCKET/
```

## Logs

```bash
# erros das últimas 2 horas
gcloud logging read 'severity>=ERROR' --freshness=2h --limit=20

# quem mexeu em permissões
gcloud logging read 'protoPayload.methodName="SetIamPolicy"' --freshness=7d \
  --format="table(timestamp,protoPayload.authenticationInfo.principalEmail,resource.type)"
```

## Truques de saída

- `--format="value(campo)"` devolve só o valor, sem cabeçalho, ótimo para usar em script.
- `--format=json` mostra tudo; a partir dele é fácil descobrir o nome exato de cada campo.
- `--filter` roda no servidor quando possível, então é mais rápido que filtrar com `grep`.
- No Windows, a saída vem com quebra de linha CRLF. Em script bash, passe por `tr -d '\r'` antes de comparar texto. Eu só descobri isso quando o meu script de auditoria começou a classificar errado.
