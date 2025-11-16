$env:GRPC_HELLO_SECURE = 'Y'
$env:CERT_BASE_PATH = 'D:\coding\hello-grpc\docker\tls\client_certs'
$env:GRPC_SERVER = '127.0.0.1'
$env:GRPC_SERVER_PORT = '9996'

Write-Host "Starting Dart gRPC Client with TLS..."
Write-Host "GRPC_HELLO_SECURE=$env:GRPC_HELLO_SECURE"
Write-Host "CERT_BASE_PATH=$env:CERT_BASE_PATH"
Write-Host "GRPC_SERVER=$env:GRPC_SERVER"

dart run client.dart
