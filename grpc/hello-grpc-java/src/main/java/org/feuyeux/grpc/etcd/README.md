# etcd

```sh
$ brew install etcd

$ etcd -version
etcd Version: 3.5.9
Git SHA: bdbbde998
Go Version: go1.20.4
Go OS/Arch: darwin/amd64

$ etcd -advertise-client-urls http://0.0.0.0:2379

$ etcdctl member list
$ etcdctl lease list
```

```sh
$ http GET http://127.0.0.1:2379/version

$ export HOST="$(ipconfig getifaddr en0)"
$ http GET "http://${HOST}:2379/version"
HTTP/1.1 200 OK
Access-Control-Allow-Headers: accept, content-type, authorization
Access-Control-Allow-Methods: POST, GET, OPTIONS, PUT, DELETE
Access-Control-Allow-Origin: *
Content-Length: 44
Content-Type: application/json
Date: Mon, 14 Aug 2023 09:41:28 GMT

{
    "etcdcluster": "3.5.0",
    "etcdserver": "3.5.9"
}
```
