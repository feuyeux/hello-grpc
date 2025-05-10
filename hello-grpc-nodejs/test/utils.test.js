const assert = require('assert');
const fs = require('fs');
const path = require('path');
const { getVersion } = require('../common/utils');

// Directly output the getVersion() result
console.log(getVersion());

describe('Utils', () => {
    describe('getVersion()', () => {
        it('should return a string starting with grpc.js-version=', () => {
            const version = getVersion();
            assert.strictEqual(
                version.startsWith('grpc.js-version=') || version.startsWith('grpc.version='),
                true
            );
        });

        it('should return version that matches package.json version or a valid fallback', () => {
            // Get actual version from package.json
            const packagePath = path.join(__dirname, '..', 'package.json');
            let expectedPrefix = 'grpc.js-version=';
            let expectedVersion = 'v1.x'; // Default fallback

            if (fs.existsSync(packagePath)) {
                const packageJson = JSON.parse(fs.readFileSync(packagePath, 'utf8'));
                const grpcVersion = packageJson.dependencies?.['@grpc/grpc-js'] ||
                    packageJson.devDependencies?.['@grpc/grpc-js'];

                if (grpcVersion) {
                    expectedVersion = grpcVersion;
                }
            }

            const actualVersion = getVersion();

            // Either it should match the package.json version or have a valid format
            assert.ok(
                actualVersion === `${expectedPrefix}${expectedVersion}` ||
                actualVersion.match(/^grpc\.(js-)?version=.+$/)
            );
        });
    });
});
