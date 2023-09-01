#!/usr/bin/env bash
set -e
SCRIPT_PATH="$(
  cd "$(dirname "$0")" >/dev/null 2>&1 || exit
  pwd -P
)"
cd "$SCRIPT_PATH" || exit
#$(Get-NetIPConfiguration -InterfaceAlias 以太网2023 | grep IPv4Address |  awk '{print $3}')
#$(gip -InterfaceAlias 以太网2023 | grep IPv4Address |  awk '{print $3}')
export HostIP=192.168.0.105
echo "${HostIP}"
docker run -d -v "$HOME"/ca-certificates/:/etc/ssl/certs -p 4001:4001 -p 2380:2380 -p 2379:2379 \
 --name etcd quay.io/coreos/etcd:v2.3.8 \
 -name etcd0 \
 -advertise-client-urls http://"${HostIP}":2379,http://"${HostIP}":4001 \
 -listen-client-urls http://0.0.0.0:2379,http://0.0.0.0:4001 \
 -initial-advertise-peer-urls http://"${HostIP}":2380 \
 -listen-peer-urls http://0.0.0.0:2380 \
 -initial-cluster-token etcd-cluster-1 \
 -initial-cluster etcd0=http://"${HostIP}":2380 \
 -initial-cluster-state new