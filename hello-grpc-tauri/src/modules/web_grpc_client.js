// Web gRPC Client for HTTP Gateway communication
// Similar to Flutter's WebGrpcClient

class WebGrpcClient {
    constructor(host, port) {
        this.baseUrl = `http://${host}:9997`; // Connect to HTTP gateway
    }

    async talk(request) {
        const response = await fetch(`${this.baseUrl}/api/talk`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                data: request.data,
                meta: request.meta
            })
        });

        if (response.ok) {
            const data = await response.json();
            return this._buildTalkResponseFromJson(data);
        } else {
            throw new Error(`HTTP ${response.status}: ${await response.text()}`);
        }
    }

    async* talkOneAnswerMore(request) {
        const response = await fetch(`${this.baseUrl}/api/talkOneAnswerMore`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                data: request.data,
                meta: request.meta
            })
        });

        if (response.ok) {
            const data = await response.json();
            const results = data.results || [];
            for (const result of results) {
                yield this._buildTalkResponseFromJson(result);
            }
        } else {
            throw new Error(`HTTP ${response.status}: ${await response.text()}`);
        }
    }

    async talkMoreAnswerOne(requests) {
        const requestList = [];
        for await (const request of requests) {
            requestList.push({
                data: request.data,
                meta: request.meta
            });
        }

        const response = await fetch(`${this.baseUrl}/api/talkMoreAnswerOne`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ requests: requestList })
        });

        if (response.ok) {
            const data = await response.json();
            return this._buildTalkResponseFromJson(data);
        } else {
            throw new Error(`HTTP ${response.status}: ${await response.text()}`);
        }
    }

    async* talkBidirectional(requests) {
        const requestList = [];
        for await (const request of requests) {
            requestList.push({
                data: request.data,
                meta: request.meta
            });
        }

        const response = await fetch(`${this.baseUrl}/api/talkBidirectional`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ requests: requestList })
        });

        if (response.ok) {
            const data = await response.json();
            const results = data.results || [];
            for (const result of results) {
                yield this._buildTalkResponseFromJson(result);
            }
        } else {
            throw new Error(`HTTP ${response.status}: ${await response.text()}`);
        }
    }

    _buildTalkResponseFromJson(data) {
        // Create a response object that matches the expected format
        return {
            id: data.id,
            status: data.status || 200,
            results: data.results || data.kv || data
        };
    }
}

// Export for use in main.js
window.WebGrpcClient = WebGrpcClient;
