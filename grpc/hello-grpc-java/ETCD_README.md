# etcd

## install

### macos

```sh
brew install etcd
```

### windows

```sh
scoop install etcd
```

```sh
$ etcd -version
etcd Version: 3.5.9
Git SHA: bdbbde998
Go Version: go1.20.4
Go OS/Arch: darwin/amd64
```

```sh
export HOST="$(ipconfig getifaddr en0)"
etcd -advertise-client-urls "http://${HOST}:2379" -listen-client-urls http://0.0.0.0:2379
#
etcd -advertise-client-urls http://192.168.0.105:2379 -listen-client-urls http://0.0.0.0:2379
```

```sh
$ etcdctl member list
$ etcdctl lease list
```

```sh
http GET http://127.0.0.1:2379/version

export HOST="$(ipconfig getifaddr en0)"
http GET "http://${HOST}:2379/version"

export GRPC_HELLO_DISCOVERY_ENDPOINT=http://${HOST}:2379
export GRPC_HELLO_DISCOVERY=etcd
```
