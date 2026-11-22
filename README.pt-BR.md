# Portfólio Google Cloud

Meus labs de Google Cloud, feitos com Terraform no meu próprio projeto, junto com os scripts e anotações que vou guardando pelo caminho.

[English](README.md) | [Português (Brasil)](README.pt-BR.md)

[![Terraform CI](https://github.com/matheuslab-bit/google-cloud-portfolio/actions/workflows/terraform-ci.yml/badge.svg)](https://github.com/matheuslab-bit/google-cloud-portfolio/actions/workflows/terraform-ci.yml)

Sou analista de infraestrutura. Trabalho com TI desde 2014, com Windows Server, Active Directory, Hyper-V e suporte N2 em telecom e VoIP. Este repositório é onde eu aprendo Google Cloud montando peças pequenas e reais, colocando no ar e anotando o que fiz e por quê.

É um portfólio de estudo, não experiência com nuvem em produção. Cada lab diz claramente o que está implantado e o que é só código validado.

Meus labs de infraestrutura Microsoft ficam em [microsoft-infra-labs](https://github.com/matheuslab-bit/microsoft-infra-labs). Perfil: [github.com/matheuslab-bit](https://github.com/matheuslab-bit).

## O que tem aqui

```text
projects/   7 labs de Terraform: 6 implantados e 1 ligado só quando preciso (Cloud NAT)
scripts/    scripts com gcloud para auditar segurança e achar custos esquecidos
dicas/      dicas: gcloud, Terraform, segurança, custos, erros comuns e estudo para a ACE
```

## Labs

| # | Lab | O que mostra | Situação |
| --- | --- | --- | --- |
| 01 | [Rede VPC](projects/01-vpc-network/README.pt-BR.md) | VPC em modo personalizado com uma sub-rede planejada em São Paulo | **Implantado** |
| 02 | [VM privada](projects/02-secure-compute-engine/README.pt-BR.md) | VM Debian sem IP público, SSH só pelo IAP com OS Login, Shielded VM, ordem do firewall | **Implantado**, acesso testado em 18/11/2026 |
| 03 | [Bucket de state do Terraform](projects/03-terraform-backend/README.pt-BR.md) | Backend GCS protegido, com versionamento, Soft Delete, lock e procedimento de recuperação | **Implantado** em 20/11/2026, guarda o state dos labs 01 e 02 |
| 04 | [Monitoramento e orçamento](projects/04-monitoring-alerts/README.pt-BR.md) | Alertas de CPU, VM parada e mudança de IAM; orçamento mensal com alerta de previsão | **Implantado** em 21/11/2026, alertas testados |
| 05 | [Aplicação no Cloud Run](projects/05-cloud-run-app/README.pt-BR.md) | Contêiner no Artifact Registry, serviço privado no Cloud Run, segredo lido do Secret Manager | **Implantado** em 21/11/2026, chamado com token de identidade |
| 06 | [Workload Identity Federation](projects/06-workload-identity-federation/README.pt-BR.md) | GitHub Actions acessando o Google Cloud sem chave guardada, com condição de confiança fixada | **Implantado** em 21/11/2026 |
| 07 | [Cloud NAT](projects/07-cloud-nat/README.pt-BR.md) | Saída para a internet da VM privada, sem IP público e sem porta de entrada | **Testado** em 21/11/2026 e destruído (ligado só quando preciso) |

## Como os labs implantados se encaixam

```text
Lab 03: bucket de state (us-central1)  <-- state remoto do Lab 01 e do Lab 02

Lab 01: portfolio-vpc (global, modo personalizado)
  ├── portfolio-subnet    southamerica-east1   10.10.0.0/24
  └── lab02-iowa-subnet   us-central1          10.20.0.0/24   (do Lab 02)
        └── lab02-secure-vm   e2-micro, sem IP externo

Eu -> IAP (35.235.240.0/20) -> TCP 22 (regra de firewall prioridade 900) -> VM
```

- O Lab 01 cuida da VPC e da sub-rede de São Paulo.
- O Lab 02 lê a VPC por um data source e cuida só da própria sub-rede, das regras de firewall, da conta de serviço e da VM.
- O Lab 03 é o ponto de partida: o state dele fica local, e ele guarda o state dos labs 1 e 2 em prefixos separados (`labs/01-vpc-network` e `labs/02-secure-compute-engine`).
- Os labs 04 a 06 são independentes e vão usar o mesmo bucket, cada um no seu prefixo.
- Escolhi Iowa (`us-central1`) porque a região pode entrar no nível gratuito (Free Tier). Isso não garante custo zero.

## Scripts

[Dois scripts com `gcloud`, só de leitura](scripts/README.md):

- `auditoria-seguranca.sh` procura VMs públicas, regras de firewall abertas para a internet, chaves de conta de serviço criadas por usuário, buckets públicos, papéis básicos em contas de serviço e VMs usando a conta de serviço padrão.
- `custos-recursos.sh` lista o que continua cobrando sem ninguém usar: discos soltos, IPs estáticos parados, VMs desligadas e snapshots antigos.

Quando rodei a auditoria neste projeto, ela achou três configurações que o Google cria sozinho (SSH e RDP abertos na rede `default` e Editor na conta de serviço padrão do Compute). Corrigi as três em 21/11/2026, e a auditoria agora termina com 0 alertas. A história e a correção estão em [`dicas/seguranca.md`](dicas/seguranca.md).

## Como trabalho neste repositório

- Todo recurso está no Terraform. O provider do Google está fixado na versão `7.46.2` e os lock files estão no Git.
- Entradas como ID do projeto, faixas CIDR, e-mail e conta de faturamento são validadas antes de qualquer chamada à API.
- O state fica num bucket GCS com versionamento e lock, um prefixo por lab.
- O GitHub Actions roda `terraform fmt`, `init -backend=false` e `validate` em cada lab, a análise do Checkov, os testes da aplicação do Cloud Run e o ShellCheck nos scripts. Pull requests que mexem em `projects/` também rodam um `terraform plan` sem chave nos labs 01 e 02 (Lab 06).
- Quando aceito um alerta do Checkov, escrevo o motivo num comentário `#checkov:skip` ao lado do recurso. Quando o Checkov tem razão, corrijo o código: no Lab 06 ele apontou o papel Viewer, e troquei por papéis de leitura específicos.
- Sem IP público, SSH só pelo IAP, OS Login, Shielded VM e contas de serviço sem chave e sem papéis no projeto.

## Estrutura

```text
.
├── .github/workflows/terraform-ci.yml   # validação por lab, Checkov, testes da aplicação, ShellCheck
├── projects/
│   ├── 01-vpc-network/
│   ├── 02-secure-compute-engine/
│   ├── 03-terraform-backend/
│   ├── 04-monitoring-alerts/
│   ├── 05-cloud-run-app/                 # Terraform + app/ (Node.js, Dockerfile, testes)
│   ├── 06-workload-identity-federation/  # Terraform + examples/ (workflow sem chave)
│   ├── 07-cloud-nat/                     # Cloud Router + NAT, ligado só quando preciso
│   └── archive/                          # meu primeiro protótipo, guardado como referência
├── scripts/                              # scripts de auditoria e custo com gcloud
├── dicas/                                # dicas
└── ROADMAP.md / ROADMAP.pt-BR.md
```

## Próximos passos

- Cloud SQL com acesso privado para a aplicação do Cloud Run
- A certificação Associate Cloud Engineer (ACE)

O plano completo está no [roadmap](ROADMAP.pt-BR.md).

## Contato

[LinkedIn](https://linkedin.com/in/matheus-s-ti) · [matheus.silva.gcp@gmail.com](mailto:matheus.silva.gcp@gmail.com)

---

São exercícios de estudo, não hospedagem de produção.
