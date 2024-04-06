module hello-grpc

go 1.22

require (
	// https://github.com/google/uuid/tags
	github.com/google/uuid v1.6.0

	// Golang gRPC Middlewares: interceptor chaining, auth, logging, retries and more.
	// https://github.com/grpc-ecosystem/go-grpc-middleware/tags
	github.com/grpc-ecosystem/go-grpc-middleware v1.4.0
	// https://github.com/sirupsen/logrus/tags
	github.com/sirupsen/logrus v1.9.3
	// https://github.com/stretchr/testify/tags
	github.com/stretchr/testify v1.9.0
	// https://pkg.go.dev/go.etcd.io/etcd/client/v3?tab=versions
	go.etcd.io/etcd/client/v3 v3.5.13
	// https://pkg.go.dev/go.uber.org/ratelimit?tab=versions
	go.uber.org/ratelimit v0.3.1
	// https://pkg.go.dev/golang.org/x/net
	golang.org/x/net v0.24.0
	// https://github.com/grpc/grpc-go/tags
	google.golang.org/grpc v1.62.1
)

require (
	github.com/benbjohnson/clock v1.3.0 // indirect
	github.com/coreos/go-semver v0.3.0 // indirect
	github.com/coreos/go-systemd/v22 v22.3.2 // indirect
	github.com/davecgh/go-spew v1.1.1 // indirect
	github.com/gogo/protobuf v1.3.2 // indirect
	github.com/golang/protobuf v1.5.4 // indirect
	github.com/pmezard/go-difflib v1.0.0 // indirect
	go.etcd.io/etcd/api/v3 v3.5.13 // indirect
	go.etcd.io/etcd/client/pkg/v3 v3.5.13 // indirect
	go.uber.org/atomic v1.7.0 // indirect
	go.uber.org/multierr v1.6.0 // indirect
	go.uber.org/zap v1.18.1 // indirect
	golang.org/x/sys v0.19.0 // indirect
	golang.org/x/text v0.14.0 // indirect
	google.golang.org/genproto v0.0.0-20240123012728-ef4313101c80 // indirect
	google.golang.org/genproto/googleapis/api v0.0.0-20240123012728-ef4313101c80 // indirect
	google.golang.org/genproto/googleapis/rpc v0.0.0-20240123012728-ef4313101c80 // indirect
	// https://github.com/protocolbuffers/protobuf-go/tags
	google.golang.org/protobuf v1.33.0 // indirect
	gopkg.in/yaml.v3 v3.0.1 // indirect
)
