package common

import (
	"math/rand"
	"sync"

	log "github.com/sirupsen/logrus"
	"google.golang.org/grpc/balancer"
	"google.golang.org/grpc/balancer/base"
)

const WeightLoadBalance = "weight_load_balance"
const MaxWeight = 10 // 可设置的最大权重
const MinWeight = 1  // 可设置的最小权重

// newBuilder 注册自定义权重负载均衡器
func newBuilder() balancer.Builder {
	return base.NewBalancerBuilder(WeightLoadBalance, &weightPikerBuilder{}, base.Config{HealthCheck: true})
}

func init() {
	balancer.Register(newBuilder())
}

type weightPikerBuilder struct {
}

// Build 根据负载均衡策略 生成重复的连接
func (p *weightPikerBuilder) Build(info base.PickerBuildInfo) balancer.Picker {
	log.Infof("weightPikerBuilder build called...")
	// 没有可用的连接
	if len(info.ReadySCs) == 0 {
		return base.NewErrPicker(balancer.ErrNoSubConnAvailable)
	}
	// 此处有坑，为什么长度给0,而不是1???
	scs := make([]balancer.SubConn, 0, len(info.ReadySCs))
	for subConn, subConnInfo := range info.ReadySCs {
		v := subConnInfo.Address.Attributes.Value(WeightAttributeKey{})
		w := v.(WeightAddrInfo).Weight
		// 限制可以设置的最大最小权重，防止设置过大创建连接数太多
		if w < MinWeight {
			w = MinWeight
		}
		if w > MaxWeight {
			w = MaxWeight
		}
		// 根据权重 创建多个重复的连接 权重越高个数越多
		for i := 0; i < w; i++ {
			scs = append(scs, subConn)
		}
	}

	return &weightPiker{
		scs: scs,
	}
}

type weightPiker struct {
	scs []balancer.SubConn
	mu  sync.Mutex
}

// Pick 从build方法生成的连接数中选择一个连接返回
func (p *weightPiker) Pick(_ balancer.PickInfo) (balancer.PickResult, error) {
	// 随机选择一个返回，权重越大，生成的连接个数越多，因此，被选中的概率也越大
	log.Println("weightPiker Pick called...")
	p.mu.Lock()
	index := rand.Intn(len(p.scs))
	sc := p.scs[index]
	p.mu.Unlock()
	return balancer.PickResult{SubConn: sc}, nil
}

type WeightAttributeKey struct{}

type WeightAddrInfo struct {
	Weight int
}
