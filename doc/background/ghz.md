## [ghz](https://github.com/bojand/ghz)

```bash
brew install ghz
```

## Benchmark Scripts

This repository includes two ghz-based benchmark scripts for cross-language performance comparison:

### Single-server benchmark: `scripts/benchmark/ghz_benchmark.sh`

Runs ghz against a single server with configurable concurrency and total requests.

```bash
# Basic unary call benchmark
./scripts/benchmark/ghz_benchmark.sh localhost 9996

# High-load benchmark
./scripts/benchmark/ghz_benchmark.sh localhost 9996 -n 5000 -c 50

# Test bidirectional streaming
./scripts/benchmark/ghz_benchmark.sh localhost 9996 -r bidi -n 200 -c 5

# TLS benchmark
./scripts/benchmark/ghz_benchmark.sh localhost 9996 -t
```

Results are saved as JSON to `scripts/benchmark/results/`.

### Multi-language benchmark: `scripts/benchmark/run_all.sh`

Iterates over all language server Docker images, starts each server, runs ghz benchmark, and produces a summary table comparing RPS and latency percentiles.

```bash
# Benchmark all languages with defaults (1000 requests, 10 concurrent)
./scripts/benchmark/run_all.sh

# Higher load
./scripts/benchmark/run_all.sh -n 5000 -c 50

# Benchmark a single language
./scripts/benchmark/run_all.sh -l go -n 10000

# Test server streaming for all languages
./scripts/benchmark/run_all.sh -r server-stream -n 500 -c 20
```

A summary JSON file and per-language JSON results are saved to `scripts/benchmark/results/`.

---

https://ghz.sh/docs/examples

### A simple insecure unary call:

```bash
ghz --insecure \
 --proto grpc/proto/landing.proto \
 --call org.feuyeux.grpc.LandingService/Talk \
 -d '{
"data": "0",
"meta": "grpcurl"
}' \
 localhost:9996
```

### Server reflection

```bash
ghz --insecure \
 --call org.feuyeux.grpc.LandingService/Talk \
 -d '{
"data": "0",
"meta": "grpcurl"
}' \
 localhost:9996
```

### Custom parameters

#### Client streaming

```bash
ghz --insecure \
 --call org.feuyeux.grpc.LandingService/TalkMoreAnswerOne \
 -d '[{"data": "0","meta": "grpcurl"},{"data": "1","meta": "grpcurl"},{"data": "2","meta": "grpcurl"}]' \
 localhost:9996
```

#### Custom number of requests/concurrency/connections

```bash
ghz --insecure \
 --call org.feuyeux.grpc.LandingService/Talk \
 -d '{
"data": "0",
"meta": "grpcurl"
}' \
-n 2000 \
-c 20 \
--connections=10 \
localhost:9996
```

#### TLS

```bash
ghz --cname=hello.grpc.io \
--cert="/var/hello_grpc/client_certs/full_chain.pem" \
--key="/var/hello_grpc/client_certs/private.pkcs8.key" \
--cacert="/var/hello_grpc/client_certs/full_chain.pem" \
--call org.feuyeux.grpc.LandingService/Talk \
 -d '{
"data": "0",
"meta": "grpcurl"
}' \
 localhost:9996
```
