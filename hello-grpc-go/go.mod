module hello-grpc

go 1.24.0

require (
	// https://github.com/google/uuid/tags
	github.com/google/uuid v1.6.0

	// Golang gRPC Middlewares: interceptor chaining, auth, logging, retries and more.
	// https://github.com/grpc-ecosystem/go-grpc-middleware/tags
	github.com/grpc-ecosystem/go-grpc-middleware v1.4.0
	// https://github.com/sirupsen/logrus/tags
	github.com/sirupsen/logrus v1.9.4
	// https://github.com/stretchr/testify/tags
	github.com/stretchr/testify v1.11.1
	// https://pkg.go.dev/go.etcd.io/etcd/client/v3?tab=versions
	go.etcd.io/etcd/client/v3 v3.6.8
	// https://pkg.go.dev/go.uber.org/ratelimit?tab=versions
	go.uber.org/ratelimit v0.3.1
	// https://pkg.go.dev/golang.org/x/net
	golang.org/x/net v0.48.0 // indirect
	// https://github.com/grpc/grpc-go/tags
	google.golang.org/grpc v1.79.1
	// https://github.com/protocolbuffers/protobuf-go/tags
	google.golang.org/protobuf v1.36.10 // indirect
)

require github.com/prometheus/client_golang v1.23.2

require (
	github.com/benbjohnson/clock v1.3.0 // indirect
	github.com/beorn7/perks v1.0.1 // indirect
	github.com/cespare/xxhash/v2 v2.3.0 // indirect
	github.com/coreos/go-semver v0.3.1 // indirect
	github.com/coreos/go-systemd/v22 v22.5.0 // indirect
	github.com/davecgh/go-spew v1.1.1 // indirect
	github.com/gogo/protobuf v1.3.2 // indirect
	github.com/golang/protobuf v1.5.4 // indirect
	github.com/grpc-ecosystem/grpc-gateway/v2 v2.26.3 // indirect
	github.com/munnerz/goautoneg v0.0.0-20191010083416-a7dc8b61c822 // indirect
	github.com/pmezard/go-difflib v1.0.0 // indirect
	github.com/prometheus/client_model v0.6.2 // indirect
	github.com/prometheus/common v0.66.1 // indirect
	github.com/prometheus/procfs v0.16.1 // indirect
	go.etcd.io/etcd/api/v3 v3.6.8 // indirect
	go.etcd.io/etcd/client/pkg/v3 v3.6.8 // indirect
	go.uber.org/multierr v1.11.0 // indirect
	go.uber.org/zap v1.27.0 // indirect
	go.yaml.in/yaml/v2 v2.4.2 // indirect
	golang.org/x/sys v0.39.0 // indirect
	golang.org/x/text v0.32.0 // indirect
	google.golang.org/genproto/googleapis/api v0.0.0-20251202230838-ff82c1b0f217 // indirect
	google.golang.org/genproto/googleapis/rpc v0.0.0-20251202230838-ff82c1b0f217 // indirect
	gopkg.in/yaml.v3 v3.0.1 // indirect
)
