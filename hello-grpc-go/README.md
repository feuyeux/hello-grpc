# grpc golang demo

## 1 Setup

```bash
sh init.sh
```

## 2 Generate

```bash
sh proto2go.sh
```

## 3 Build

```bash
sh build.sh
```

## 4 Run

```bash
export GRPC_HELLO_SECURE=Y
sh server_start.sh
```

```bash
export GRPC_HELLO_SECURE=Y
sh client_start.sh
```
