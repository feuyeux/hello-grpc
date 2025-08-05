/*!
 * Web gRPC Client Module
 * 
 * This module provides HTTP-based gRPC communication for web browsers
 * that cannot directly connect to gRPC servers. It simulates gRPC calls
 * by communicating with an HTTP gateway server.
 * 
 * Supported Operations:
 * - talk(): Unary RPC (single request → single response)
 * - talkOneAnswerMore(): Server streaming (single request → multiple responses)
 * - talkMoreAnswerOne(): Client streaming (multiple requests → single response)
 * - talkBidirectional(): Bidirectional streaming (multiple ↔ multiple)
 * 
 * Architecture:
 * Browser → HTTP Gateway (port 9997) → gRPC Server (port 9996)
 */

/// Web gRPC Client for HTTP Gateway communication
/// 
/// Provides gRPC-like functionality over HTTP for browser environments.
/// Connects to an HTTP gateway server that translates HTTP requests
/// to gRPC calls and vice versa.
class WebGrpcClient {
    /// Initialize the web gRPC client
    /// 
    /// @param {string} host - Server hostname (gRPC server host)
    /// @param {number} port - Server port (gRPC server port, gateway uses port+1)
    constructor(host, port) {
        // Connect to HTTP gateway server (typically gRPC port + 1)
        this.baseUrl = `http://${host}:9997`;
    }

    /// Execute unary RPC call (single request → single response)
    /// 
    /// Sends a single request to the server and receives a single response.
    /// This is the simplest gRPC operation pattern.
    /// 
    /// @param {Object} request - Request object with data and meta fields
    /// @param {string} request.data - Request data payload
    /// @param {string} request.meta - Request metadata
    /// @returns {Promise<Object>} Server response object
    /// @throws {Error} HTTP error if request fails
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
