package discover

import (
	"context"
	log "github.com/sirupsen/logrus"
	"go.etcd.io/etcd/client/v3"
	"google.golang.org/grpc/attributes"
	"google.golang.org/grpc/resolver"
	"hello-grpc/common"
	"sync"
)

type etcdResolver struct {
	ctx        context.Context
	cancel     context.CancelFunc
	cc         resolver.ClientConn
	etcdClient *clientv3.Client
	scheme     string
	ipPool     sync.Map
}

func (e *etcdResolver) ResolveNow(resolver.ResolveNowOptions) {
	log.Infoln("etcd resolver resolve now")
}

func (e *etcdResolver) Close() {
	log.Infoln("etcd resolver close")
	e.cancel()
}

func (e *etcdResolver) watcher() {
	watchChan := e.etcdClient.Watch(context.Background(), "/"+e.scheme, clientv3.WithPrefix())
	for {
		select {
		case val := <-watchChan:
			for _, event := range val.Events {
				switch event.Type {
				case 0: // 0 是有数据增加
					e.store(event.Kv.Key, event.Kv.Value)
					log.Infoln("put:", string(event.Kv.Key))
					e.updateState()
				case 1: // 1是有数据减少
					log.Infoln("del:", string(event.Kv.Key))
					e.del(event.Kv.Key)
					e.updateState()
				}
			}
		case <-e.ctx.Done():
			return
		}
	}
}

func (e *etcdResolver) store(k, v []byte) {
	e.ipPool.Store(string(k), string(v))
}

func (e *etcdResolver) del(key []byte) {
	e.ipPool.Delete(string(key))
}

func (e *etcdResolver) updateState() {
	var addrList resolver.State
	// 模拟权重设置
	log.Infoln("etcdResolver updateSate called...")
	var i = 1
	e.ipPool.Range(func(k, v interface{}) bool {
		tA, ok := v.(string)
		if !ok {
			return false
		}
		log.Infof("conn.UpdateState key[%v];val[%v]\n", k, v)
		// 模拟设置权重
		addr := resolver.Address{
			BalancerAttributes: attributes.New(common.WeightAttributeKey{}, common.WeightAddrInfo{
				Weight: i,
			}),
			Addr: tA,
		}
		addrList.Addresses = append(addrList.Addresses, addr)
		i++
		return true
	})
	err := e.cc.UpdateState(addrList)
	if err != nil {
		return
	}
}
