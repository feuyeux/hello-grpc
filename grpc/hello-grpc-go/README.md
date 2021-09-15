## grpc golang demo

### 1 Setup

```bash
sh init.sh
```

### 2 Generate

```bash
sh proto2go.sh
```

### 3 Build
```bash
go get .
go list -mod=mod -json all
go build
```

### 4 Run
```bash
sh test_server.sh
```

```bash
sh test_client.sh
```

