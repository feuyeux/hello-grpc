package register

import (
	"context"
	"hello-grpc/etcd/discover"
	"time"

	log "github.com/sirupsen/logrus"
	clientv3 "go.etcd.io/etcd/client/v3"
)

type EtcdRegister struct {
	etcdCli *clientv3.Client // etcd连接
	leaseId clientv3.LeaseID // 租约ID
	ctx     context.Context
	cancel  context.CancelFunc
}

// CreateLease 创建租约
// expire 有效期(秒)
func (r *EtcdRegister) CreateLease(expire int64) error {
	res, err := r.etcdCli.Grant(r.ctx, expire)
	if err != nil {
		log.Errorf("createLease failed,error %v \n", err)
		return err
	}
	r.leaseId = res.ID
	return nil
}

// BindLease 绑定租约
// 将租约和对应的KEY-VALUE绑定
func (r *EtcdRegister) BindLease(key string, value string) error {
	res, err := r.etcdCli.Put(r.ctx, key, value, clientv3.WithLease(r.leaseId))
	if err != nil {
		log.Errorf("bindLease failed,error %v \n", err)
		return err
	}
	log.Infof("bindLease success %v \n", res)
	return nil
}

// KeepAlive 续租 发送心跳，表明服务正常
func (r *EtcdRegister) KeepAlive() (<-chan *clientv3.LeaseKeepAliveResponse, error) {
	resChan, err := r.etcdCli.KeepAlive(r.ctx, r.leaseId)
	if err != nil {
		log.Errorf("keepAlive failed,error %v \n", resChan)
		return resChan, err
	}
	return resChan, nil
}

func (r *EtcdRegister) Watcher(key string, resChan <-chan *clientv3.LeaseKeepAliveResponse) {
	for {
		select {
		case l := <-resChan:
			log.Infof("续约成功,val:%+v \n", l)
		case <-r.ctx.Done():
			log.Infof("续约关闭")
			return
		}
	}
}

func (r *EtcdRegister) Close() error {
	r.cancel()
	log.Infof("closed...\n")
	// 撤销租约
	_, err := r.etcdCli.Revoke(r.ctx, r.leaseId)
	if err != nil {
		return err
	}
	return r.etcdCli.Close()
}

func NewEtcdRegister() (*EtcdRegister, error) {
	endpoint := discover.GetDiscoveryEndpoint()
	log.Infof("ectd endpoint %s", endpoint)
	client, err := clientv3.New(clientv3.Config{
		Endpoints:   []string{endpoint},
		DialTimeout: 5 * time.Second,
	})
	if err != nil {
		log.Printf("new etcd client failed,error %v \n", err)
		return nil, err
	}
	ctx, cancelFunc := context.WithCancel(context.Background())
	svr := &EtcdRegister{
		etcdCli: client,
		ctx:     ctx,
		cancel:  cancelFunc,
	}
	return svr, nil
}

// RegisterServer 注册服务
// expire 过期时间
func (r *EtcdRegister) RegisterServer(serviceName, addr string, expire int64) (err error) {
	// 创建租约
	err = r.CreateLease(expire)
	if err != nil {
		return err
	}

	// 绑定租约
	err = r.BindLease(serviceName, addr)
	if err != nil {
		return err
	}

	// 续租
	keepAliveChan, err := r.KeepAlive()
	if err != nil {
		return err
	}

	// 监听续约
	go r.Watcher(serviceName, keepAliveChan)

	return nil
}
