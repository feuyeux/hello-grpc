$env:GRPC_HELLO_SECURE = 'Y'
$env:CERT_BASE_PATH = 'D:\coding\hello-grpc\docker\tls\server_certs'
$env:GRPC_SERVER_PORT = '9996'

Write-Host "Starting Dart gRPC Server with TLS..."
Write-Host "GRPC_HELLO_SECURE=$env:GRPC_HELLO_SECURE"
Write-Host "CERT_BASE_PATH=$env:CERT_BASE_PATH"
Write-Host "GRPC_SERVER_PORT=$env:GRPC_SERVER_PORT"

dart run server.dart
