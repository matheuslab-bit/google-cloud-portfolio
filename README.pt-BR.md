# Portfólio Google Cloud

Meus labs de Google Cloud, feitos com Terraform e implantados no meu próprio projeto.

[English](README.md) | [Português (Brasil)](README.pt-BR.md)

[![Terraform CI](https://github.com/matheuslab-bit/google-cloud-portfolio/actions/workflows/terraform-ci.yml/badge.svg)](https://github.com/matheuslab-bit/google-cloud-portfolio/actions/workflows/terraform-ci.yml)

Sou analista de infraestrutura. Trabalho com TI desde 2014, com Windows Server, Active Directory, Hyper-V e suporte N2 em telecom e VoIP. Este repositório é onde eu aprendo Google Cloud montando peças pequenas e reais, colocando no ar e anotando o que fiz e por quê.

É um portfólio de estudo, não experiência com nuvem em produção.

Meus labs de infraestrutura Microsoft ficam em [microsoft-infra-labs](https://github.com/matheuslab-bit/microsoft-infra-labs). Perfil: [github.com/matheuslab-bit](https://github.com/matheuslab-bit).

## Labs

1. [Rede VPC](projects/01-vpc-network/README.pt-BR.md): uma VPC em modo personalizado com uma sub-rede em São Paulo. Implantado.
2. [VM privada](projects/02-secure-compute-engine/README.pt-BR.md): uma VM Debian em Iowa, sem IP público. SSH só pelo IAP com OS Login. Implantado, com acesso testado em 18/11/2026.
3. [Bucket de state do Terraform](projects/03-terraform-backend/README.pt-BR.md): um bucket do Cloud Storage bem protegido que guarda o state do Terraform dos labs 1 e 2. Implantado em 20/11/2026.

## Como as peças se encaixam

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
- Escolhi Iowa (`us-central1`) porque a região pode entrar no nível gratuito (Free Tier). Isso não garante custo zero.

## Como trabalho neste repositório

- Todo recurso está no Terraform. O provider do Google está fixado na versão `7.46.2` e os lock files estão no Git.
- Entradas como ID do projeto, faixas CIDR e nome do bucket são validadas antes de qualquer chamada à API.
- O state fica num bucket GCS com versionamento e lock, um prefixo por lab.
- O GitHub Actions roda `terraform fmt`, `init -backend=false` e `validate` em cada lab, além de uma análise de segurança com o Checkov. O CI não tem credenciais de nuvem.
- Quando aceito um alerta do Checkov, escrevo o motivo num comentário `#checkov:skip` ao lado do recurso.
- Sem IP público, SSH só pelo IAP, OS Login, Shielded VM e contas de serviço sem chave e sem papéis no projeto.
- Cada README de lab diz o que está planejado, o que passou na validação e o que está de fato implantado, com datas e pull requests.

## Estrutura

```text
.
├── .github/workflows/terraform-ci.yml   # validação por lab + Checkov
├── projects/
│   ├── 01-vpc-network/
│   ├── 02-secure-compute-engine/
│   ├── 03-terraform-backend/
│   └── archive/                         # meu primeiro protótipo, guardado como referência
└── ROADMAP.md / ROADMAP.pt-BR.md        # o que vou estudar a seguir
```

## Próximos passos

- Workload Identity Federation, para o GitHub Actions rodar `terraform plan` sem chave
- Um lab de monitoramento e logs (Cloud Monitoring, Cloud Logging, VPC Flow Logs e alertas de orçamento)
- Uma aplicação no Cloud Run com Artifact Registry e Secret Manager
- A certificação Associate Cloud Engineer (ACE)

O plano completo está no [roadmap](ROADMAP.pt-BR.md).

## Contato

[LinkedIn](https://linkedin.com/in/matheus-s-ti) · [matheus.silva.gcp@gmail.com](mailto:matheus.silva.gcp@gmail.com)

---

São exercícios de estudo, não hospedagem de produção.
