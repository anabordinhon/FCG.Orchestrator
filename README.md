# FCG.Orchestrator

Este repositório contém scripts e manifests para orquestrar os serviços do projeto (APIs e workers), além de infra (RabbitMQ e SQL Server). O script principal de implantação é o `deploy.ps1`, que constrói as imagens Docker, aplica manifests Kubernetes e faz o port-forward para os Swagger UIs. Também há um `docker-compose.yml` para levantar a stack via Docker Compose.

## Visão geral rápida
- `deploy.ps1` (PowerShell) — constrói imagens, cria secrets, sobe SQL Server e RabbitMQ no Kubernetes, aplica os manifests das aplicações e faz port-forward dos Swagger.
- `docker-compose.yml` — alternativa para subir containers localmente via Docker Compose.
- Secrets/templates: `sqlserver-secret.yaml`, `rabbitmq-secret.yaml`, `sqlserver-secret-template.yaml`, `rabbitmq-secret-template.yaml`
- Arquivos de configuração de ambiente: `.env` e `.env.template`

## Pré-requisitos
- Windows com PowerShell (ou PowerShell Core)
- Docker Desktop (com Kubernetes habilitado se for usar k8s)
- kubectl instalado e configurado para o cluster desejado
- Git (opcional)
- Permissões para executar scripts PowerShell

## Como usar

1. Preparar variáveis de ambiente e secrets
   - Copie e edite o template `.env.template` para `.env` se necessário.
   - Ajuste os templates de secrets (`sqlserver-secret-template.yaml`, `rabbitmq-secret-template.yaml`) e gere os arquivos finais `sqlserver-secret.yaml` e `rabbitmq-secret.yaml` conforme sua infraestrutura/segredos.

2. Deploy via Kubernetes (script principal)
   - Abra PowerShell no diretório do repositório (onde está `deploy.ps1`).
   - Rode:
     ```
     .\deploy.ps1
     ```
   - O script:
     - Constrói imagens Docker (ex.: `catalogapi:latest`, `catalogapi-migrations:latest`, `usersapi:latest`, `usersapi-migrations:latest`, `fcgpayments-worker:latest`, `notifications-event-processor:latest`)
     - Aplica secrets (`sqlserver-secret.yaml`, `rabbitmq-secret.yaml`)
     - Aplica infra de SQL Server e RabbitMQ (`infrastructure-sqlserver.yaml`, `infrastructure-rabbitmq.yaml`) e aguarda pods prontos
     - Aplica manifests das aplicações (pastas `k8s` das APIs/Workers) e aguarda readiness dos pods
     - Executa `kubectl get pods` e `kubectl get services`
     - Executa port-forward para os Swagger UIs:
       - Catalog Swagger: http://localhost:8080/swagger
       - Users Swagger:  http://localhost:8081/swagger

3. Levantar via Docker Compose
   - Para uma execução local sem Kubernetes:
     ```
     docker-compose up --build -d
     ```
   - Para parar:
     ```
     docker-compose down
     ```

## Comandos úteis
- Ver pods e serviços: