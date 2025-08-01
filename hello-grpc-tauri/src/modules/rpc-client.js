/**
 * gRPC Client Module
 * Handles all gRPC communication patterns
 */

export class GrpcClient {
  constructor() {
    this.isConnected = false;
    this.activeStreams = new Map();
  }

  /**
   * Test connection to gRPC server
   */
  async testConnection(settings) {
    try {
      const { invoke } = window.__TAURI__.core;
      const result = await invoke("test_connection", { settings });
      this.isConnected = result.connected;
      return result;
    } catch (error) {
      this.isConnected = false;
      throw error;
    }
  }

  /**
   * Execute unary RPC call
   */
  async unaryCall(request) {
    const { invoke } = window.__TAURI__.core;
    return await invoke("unary_rpc", { request });
  }

  /**
   * Start server streaming RPC
   */
  async startServerStreaming(request) {
    const { invoke } = window.__TAURI__.core;
    const streamId = await invoke("server_streaming_rpc", { request });
    this.activeStreams.set('server-streaming', streamId);
    return streamId;
  }

  /**
   * Start client streaming RPC
   */
  async startClientStreaming() {
    const { invoke } = window.__TAURI__.core;
    const streamId = await invoke("client_streaming_rpc");
    this.activeStreams.set('client-streaming', streamId);
    return streamId;
  }

  /**
   * Start bidirectional streaming RPC
   */
  async startBidirectionalStreaming() {
    const { invoke } = window.__TAURI__.core;
    const streamId = await invoke("bidirectional_streaming_rpc");
    this.activeStreams.set('bidirectional', streamId);
    return streamId;
  }

  /**
   * Send message in streaming RPC
   */
  async sendStreamingMessage(request) {
    const { invoke } = window.__TAURI__.core;
    return await invoke("send_streaming_message", { request });
  }

  /**
   * Stop active streaming
   */
  async stopStreaming(streamType = null) {
    const { invoke } = window.__TAURI__.core;
    
    if (streamType) {
      await invoke("stop_streaming", { streamType });
      this.activeStreams.delete(streamType);
    } else {
      // Stop all active streams
      await invoke("stop_all_streaming");
      this.activeStreams.clear();
    }
  }

  /**
   * Get active streams
   */
  getActiveStreams() {
    return Array.from(this.activeStreams.keys());
  }

  /**
   * Check if streaming is active
   */
  isStreamingActive(streamType = null) {
    if (streamType) {
      return this.activeStreams.has(streamType);
    }
    return this.activeStreams.size > 0;
  }
}

export default GrpcClient;