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
go mod tidy
go install .
go list -mod=mod -json all
go build
```

### 4 Run
```bash
sh server_start.sh
```

```bash
sh client_start.sh
```

