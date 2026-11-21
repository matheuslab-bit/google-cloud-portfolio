# Erros comuns e o que fazer

## API não ativada

```text
Error 403: Compute Engine API has not been used in project ... before or it is disabled.
```

Toda API vem desligada num projeto novo:

```bash
gcloud services enable compute.googleapis.com
```

No Terraform, `google_project_service` com `disable_on_destroy = false` liga a API e não desliga no `destroy`. Desligar uma API usada por outros recursos quebra tudo.

## Permissão negada

```text
Error 403: Required 'compute.instances.create' permission for 'projects/...'
```

1. Confira quem está rodando: `gcloud auth list` e, para o Terraform, `gcloud auth application-default login`.
2. Descubra qual papel tem a permissão: na documentação de IAM, procure o nome da permissão (`compute.instances.create`).
3. Peça o papel mais restrito que a contém, e não Owner.

## SSH pelo IAP não conecta

```text
Error while connecting [4033: 'not authorized'] ou [4003: 'failed to connect to backend']
```

| Código | Causa | O que conferir |
| --- | --- | --- |
| 4033 | Falta permissão | Papel `roles/iap.tunnelResourceAccessor` para quem conecta |
| 4003 | O IAP não chega na VM | Regra de firewall liberando TCP 22 para `35.235.240.0/20`; o SSH está rodando dentro da VM |
| Permission denied (publickey) | OS Login | Papel `roles/compute.osLogin` (ou `osAdminLogin` para sudo) |

## Quota

```text
Quota 'CPUS' exceeded. Limit: 8.0 in region us-central1.
```

Projetos novos têm limites baixos. Em IAM e administrador > Cotas, peça aumento, ou use outra região.

## Recurso já existe

```text
Error 409: The resource 'projects/.../networks/portfolio-vpc' already exists
```

Alguém criou pelo console ou o state se perdeu. Não apague: use um bloco `import` (veja [terraform.md](terraform.md)).

## Lock do state

```text
Error acquiring the state lock
```

Outra execução está rodando, ou uma anterior morreu no meio. Espere ou, com certeza de que não há ninguém rodando, use `terraform force-unlock ID`.

## Orçamento não aceito

```text
Error 400: Budget currency does not match the billing account currency
```

A moeda do orçamento tem que ser a mesma da conta de faturamento (BRL ou USD, por exemplo). E a API de orçamentos precisa de `user_project_override = true` e `billing_project` no provider, senão devolve 403.

## Cloud Run não sobe

```text
The user-provided container failed to start and listen on the port defined provided by the PORT=8080
```

A aplicação precisa escutar em `0.0.0.0` na porta da variável `$PORT`. Escutar em `localhost` ou numa porta fixa diferente derruba a revisão. Os logs da revisão no Cloud Logging mostram o erro real da aplicação.
