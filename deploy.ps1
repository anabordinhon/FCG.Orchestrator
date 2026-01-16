$root = $PSScriptRoot
Set-Location $root

# --- Paths para manifests (k8s/) ---
$catalogK8s      = Join-Path $root "..\FCG.CatalogAPI\FCG.Catalog\k8s"
$usersK8s        = Join-Path $root "..\FCG.UsersAPI\FCG.Users\k8s"
$paymentsK8s     = Join-Path $root "k8s\payments"
$notificationsK8s = Join-Path $root "..\FCG.NotificationsAPI\FCG.Notifications\k8s"

# --- Paths para build ---
$catalogRoot       = Join-Path $root "..\FCG.CatalogAPI\FCG.Catalog"
$usersRoot         = Join-Path $root "..\FCG.UsersAPI\FCG.Users"
$paymentsRoot      = Join-Path $root "..\FCG.PaymentsAPI\FCG.Payments"
$notificationsRoot = Join-Path $root "..\FCG.NotificationsAPI\FCG.Notifications"

# Dockerfiles
$catalogDockerfile       = Join-Path $catalogRoot "FCG.Catalog.API\Dockerfile"
$usersDockerfile         = Join-Path $usersRoot   "FCG.Users.API\Dockerfile"
$paymentsDockerfile      = Join-Path $paymentsRoot "FCG.Payments.EventProcessor\Dockerfile"
$notificationsDockerfile = Join-Path $notificationsRoot "FCG.Notifications.EventProcessor\Dockerfile"

Write-Host "=== Build imagens (Catalog) ===" -ForegroundColor Cyan
docker build -t catalogapi:latest --target runtime -f $catalogDockerfile $catalogRoot
docker build -t catalogapi-migrations:latest --target migrations -f $catalogDockerfile $catalogRoot

Write-Host "=== Build imagens (Users) ===" -ForegroundColor Cyan
docker build -t usersapi:latest --target runtime -f $usersDockerfile $usersRoot
docker build -t usersapi-migrations:latest --target migrations -f $usersDockerfile $usersRoot

Write-Host "=== Build imagem (Payments Worker) ===" -ForegroundColor Cyan
docker build -t fcgpayments-worker:latest -f $paymentsDockerfile $paymentsRoot

Write-Host "=== Build imagem (Notifications Worker) ===" -ForegroundColor Cyan
# Nome da imagem sincronizado com seu deployment.yaml
docker build -t notifications-event-processor:latest -f $notificationsDockerfile $notificationsRoot

Write-Host "=== Subindo infra (SQL Server) ===" -ForegroundColor Yellow
kubectl apply -f (Join-Path $root "infrastructure-sqlserver.yaml")
kubectl wait --for=condition=ready pod -l app=sqlserver --timeout=600s

Write-Host "=== Subindo infra (RabbitMQ) ===" -ForegroundColor Yellow
kubectl apply -f (Join-Path $root "infrastructure-rabbitmq.yaml")
kubectl wait --for=condition=ready pod -l app=rabbitmq --timeout=300s

Start-Sleep -Seconds 10

Write-Host "=== Aplicando Catalog (/k8s) ===" -ForegroundColor Green
kubectl apply -f $catalogK8s
kubectl wait --for=condition=ready pod -l app=catalogapi --timeout=600s

Write-Host "=== Aplicando Users (/k8s) ===" -ForegroundColor Green
kubectl apply -f $usersK8s
kubectl wait --for=condition=ready pod -l app=usersapi --timeout=600s

Write-Host "=== Aplicando Payments Worker (k8s/payments) ===" -ForegroundColor Green
kubectl apply -f $paymentsK8s
kubectl wait --for=condition=ready pod -l app=payments-worker --timeout=300s

Write-Host "=== Aplicando Notifications Worker (/k8s) ===" -ForegroundColor Green
kubectl apply -f $notificationsK8s
# Label sincronizado com seu deployment.yaml (notifications-processor)
kubectl wait --for=condition=ready pod -l app=notifications-processor --timeout=300s

kubectl get pods
kubectl get services

Write-Host "=== Port-forward (Swagger) ===" -ForegroundColor Magenta

# Catalog Swagger -> http://localhost:8080/swagger
Start-Process powershell -ArgumentList `
  "kubectl port-forward service/catalogapi-service 8080:80"

# Users Swagger -> http://localhost:8081/swagger
Start-Process powershell -ArgumentList `
  "kubectl port-forward service/users-api 8081:80"

Write-Host "=== DEPLOY FINALIZADO COM SUCESSO ===" -ForegroundColor Green