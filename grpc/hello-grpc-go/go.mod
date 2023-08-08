module hello-grpc

go 1.20

require (
	// https://github.com/google/uuid/tags
	github.com/google/uuid v1.3.0
	// https://github.com/sirupsen/logrus/tags
	github.com/sirupsen/logrus v1.9.3
	// https://pkg.go.dev/golang.org/x/net
	golang.org/x/net v0.11.0
	// https://github.com/grpc/grpc-go/tags
	google.golang.org/grpc v1.56.1
	// https://github.com/protocolbuffers/protobuf-go/tags
	google.golang.org/protobuf v1.31.0
)

require github.com/stretchr/testify v1.7.0

require (
	github.com/davecgh/go-spew v1.1.1 // indirect
	github.com/golang/protobuf v1.5.3 // indirect
	github.com/pmezard/go-difflib v1.0.0 // indirect
	golang.org/x/sys v0.9.0 // indirect
	golang.org/x/text v0.10.0 // indirect
	google.golang.org/genproto v0.0.0-20230410155749-daa745c078e1 // indirect
	gopkg.in/yaml.v3 v3.0.0-20200313102051-9f266ea9e77c // indirect
)
