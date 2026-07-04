import * as assert from 'assert';
import { isEtcdDiscovery, SVC_DISC_NAME, ETCD_KEY } from '../src/lib/etcd_discovery';

describe('EtcdDiscovery', () => {
    const origDiscovery = process.env.GRPC_HELLO_DISCOVERY;

    afterEach(() => {
        if (origDiscovery === undefined) delete process.env.GRPC_HELLO_DISCOVERY;
        else process.env.GRPC_HELLO_DISCOVERY = origDiscovery;
    });

    describe('isEtcdDiscovery()', () => {
        it('returns false when env var is unset', () => {
            delete process.env.GRPC_HELLO_DISCOVERY;
            assert.strictEqual(isEtcdDiscovery(), false);
        });

        it('returns true when env var is "etcd"', () => {
            process.env.GRPC_HELLO_DISCOVERY = 'etcd';
            assert.strictEqual(isEtcdDiscovery(), true);
        });

        it('returns false when env var is other value', () => {
            process.env.GRPC_HELLO_DISCOVERY = 'dns';
            assert.strictEqual(isEtcdDiscovery(), false);
        });
    });

    describe('constants', () => {
        it('SVC_DISC_NAME is hello-grpc', () => {
            assert.strictEqual(SVC_DISC_NAME, 'hello-grpc');
        });

        it('ETCD_KEY is /etcd/hello-grpc', () => {
            assert.strictEqual(ETCD_KEY, '/etcd/hello-grpc');
        });
    });
});
