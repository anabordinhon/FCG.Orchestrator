$root = $PSScriptRoot
Set-Location $root

# --- Paths para manifests (k8s/) ---
$catalogK8s      = Resolve-Path (Join-Path $root "..\FCG.CatalogAPI\FCG.Catalog\k8s")
$usersK8s        = Resolve-Path (Join-Path $root "..\FCG.UsersAPI\FCG.Users\k8s")
$paymentsK8s     = Resolve-Path (Join-Path $root "..\FCG.PaymentsAPI\FCG.Payments\k8s")
$notificationsK8s = Resolve-Path (Join-Path $root "..\FCG.NotificationsAPI\FCG.Notifications\k8s")

# --- Paths para build ---
$catalogRoot       = Resolve-Path (Join-Path $root "..\FCG.CatalogAPI\FCG.Catalog")
$usersRoot         = Resolve-Path (Join-Path $root "..\FCG.UsersAPI\FCG.Users")
$paymentsRoot      = Resolve-Path (Join-Path $root "..\FCG.PaymentsAPI\FCG.Payments")
$notificationsRoot = Resolve-Path (Join-Path $root "..\FCG.NotificationsAPI\FCG.Notifications")

# --- Dockerfiles ---
$catalogDockerfile       = Resolve-Path (Join-Path $catalogRoot "FCG.Catalog.API\Dockerfile")
$usersDockerfile         = Resolve-Path (Join-Path $usersRoot "FCG.Users.API\Dockerfile")
$paymentsDockerfile      = Resolve-Path (Join-Path $paymentsRoot "FCG.Payments.EventProcessor\Dockerfile")
$notificationsDockerfile = Resolve-Path (Join-Path $notificationsRoot "FCG.Notifications.EventProcessor\Dockerfile")

Write-Host "=== Build imagens (Catalog) ==="
docker build -t catalogapi:latest --target runtime -f $catalogDockerfile $catalogRoot
docker build -t catalogapi-migrations:latest --target migrations -f $catalogDockerfile $catalogRoot

Write-Host "=== Build imagens (Users) ==="
docker build -t usersapi:latest --target runtime -f $usersDockerfile $usersRoot
docker build -t usersapi-migrations:latest --target migrations -f $usersDockerfile $usersRoot

Write-Host "=== Build imagem (Payments Worker) ==="
docker build -t fcgpayments-worker:latest -f $paymentsDockerfile $paymentsRoot

Write-Host "=== Build imagem (Notifications Worker) ==="
docker build -t notifications-event-processor:latest -f $notificationsDockerfile $notificationsRoot

Write-Host "=== Criando secrets (infra) ==="
kubectl apply -f (Join-Path $root "sqlserver-secret.yaml")
kubectl apply -f (Join-Path $root "rabbitmq-secret.yaml")

Write-Host "=== Subindo infra (SQL Server) ==="
kubectl apply -f (Join-Path $root "infrastructure-sqlserver.yaml")
kubectl wait --for=condition=ready pod -l app=sqlserver --timeout=600s

Write-Host "=== Subindo infra (RabbitMQ) ==="
kubectl apply -f (Join-Path $root "infrastructure-rabbitmq.yaml")
kubectl wait --for=condition=ready pod -l app=rabbitmq --timeout=300s
Start-Sleep -Seconds 10

Write-Host "=== Aplicando Catalog (/k8s) ==="
kubectl apply -f $catalogK8s
kubectl wait --for=condition=ready pod -l app=catalogapi --timeout=600s

Write-Host "=== Aplicando Users (/k8s) ==="
kubectl apply -f $usersK8s
kubectl wait --for=condition=ready pod -l app=users-api --timeout=600s

Write-Host "=== Aplicando Payments Worker (k8s/payments) ==="
kubectl apply -f $paymentsK8s
kubectl wait --for=condition=ready pod -l app=payments-worker --timeout=300s

Write-Host "=== Aplicando Notifications Worker (/k8s) ==="
kubectl apply -f $notificationsK8s
kubectl wait --for=condition=ready pod -l app=notifications-processor --timeout=300s

kubectl get pods
kubectl get services

Write-Host "=== Port-forward (Swagger) ==="
# Catalog Swagger -> http://localhost:8080/swagger
Start-Process powershell -ArgumentList `
  "kubectl port-forward service/catalogapi-service 8080:80"

# Users Swagger -> http://localhost:8081/swagger
Start-Process powershell -ArgumentList `
  "kubectl port-forward service/users-api 8081:80"