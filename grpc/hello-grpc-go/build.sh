go mod tidy
go install .
go list -mod=mod -json all
go build