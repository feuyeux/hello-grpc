go env -w GOPROXY=https://mirrors.aliyun.com/goproxy,direct
go mod tidy
go install .
go list -mod=mod -json all
go build