const { invoke } = window.__TAURI__.core;

// Application state
let appState = {
  connectionSettings: {
    server: 'localhost',
    port: 9996,
    useTls: false,
    timeout: 30
  },
  isConnected: false,
  results: []
};

// DOM elements
let elements = {};

// Initialize the application
window.addEventListener("DOMContentLoaded", async () => {
  // Get DOM elements
  elements = {
    serverInput: document.querySelector('#server-input'),
    portInput: document.querySelector('#port-input'),
    testAllBtn: document.querySelector('#test-all-btn'),
    clearResultsBtn: document.querySelector('#clear-results-btn'),
    resultsContainer: document.querySelector('#results-container'),
    connectionIndicator: document.querySelector('#connection-indicator'),
    connectionText: document.querySelector('#connection-text'),
    currentConfig: document.querySelector('#current-config'),
    loadingOverlay: document.querySelector('#loading-overlay'),
    toast: document.querySelector('#toast')
  };

  // Setup event listeners
  setupEventListeners();

  // Initialize configuration manager
  await initializeConfig();

  // Update UI
  updateConnectionStatus();
  updateCurrentConfig();
});

// Setup all event listeners
function setupEventListeners() {
  // Test all button
  elements.testAllBtn.addEventListener('click', runAllTests);

  // Clear results button
  elements.clearResultsBtn.addEventListener('click', clearResults);

  // Server config change
  elements.serverInput.addEventListener('input', updateCurrentConfig);
  elements.portInput.addEventListener('input', updateCurrentConfig);
}

// Initialize configuration manager
async function initializeConfig() {
  try {
    await invoke('init_config_manager');
    const settings = await invoke('load_connection_settings');

    if (settings) {
      appState.connectionSettings = settings;
      elements.serverInput.value = settings.server;
      elements.portInput.value = settings.port;
    }
  } catch (error) {
    console.error('Failed to initialize config:', error);
  }
}

// Update current configuration display
function updateCurrentConfig() {
  const server = elements.serverInput.value || 'localhost';
  const port = elements.portInput.value || '9996';
  elements.currentConfig.textContent = `${server}:${port}`;
}

// Update connection status
function updateConnectionStatus() {
  if (appState.isConnected) {
    elements.connectionIndicator.className = 'status-indicator status-connected';
    elements.connectionText.textContent = 'Connected';
  } else {
    elements.connectionIndicator.className = 'status-indicator status-disconnected';
    elements.connectionText.textContent = 'Disconnected';
  }
}

// Show loading
function showLoading() {
  elements.loadingOverlay.classList.remove('hidden');
}

// Hide loading
function hideLoading() {
  elements.loadingOverlay.classList.add('hidden');
}

// Show toast message
function showToast(message, isError = false) {
  const toast = elements.toast;
  const messageEl = toast.querySelector('.toast-message');

  messageEl.textContent = message;
  toast.className = `toast ${isError ? 'toast-error' : 'toast-success'}`;
  toast.classList.remove('hidden');

  setTimeout(() => {
    toast.classList.add('hidden');
  }, 3000);
}

// Hide toast
function hideToast() {
  elements.toast.classList.add('hidden');
}

// Add result to display
function addResult(message, type = 'info') {
  const resultDiv = document.createElement('div');
  resultDiv.className = `result-item result-${type}`;
  resultDiv.textContent = message;

  // Remove placeholder if it exists
  const placeholder = elements.resultsContainer.querySelector('.placeholder');
  if (placeholder) {
    placeholder.remove();
  }

  elements.resultsContainer.appendChild(resultDiv);
  elements.resultsContainer.scrollTop = elements.resultsContainer.scrollHeight;
}

// Clear all results
function clearResults() {
  elements.resultsContainer.innerHTML = `
    <div class="placeholder">
      <div class="placeholder-icon">📊</div>
      <p>Test results will appear here...</p>
      <p class="placeholder-hint">Click the test button to run all gRPC tests</p>
    </div>
  `;
  appState.results = [];
}

// Update connection settings
async function updateConnectionSettings() {
  const server = elements.serverInput.value.trim();
  const port = parseInt(elements.portInput.value);

  if (!server || !port || port <= 0 || port > 65535) {
    showToast('Please enter valid server and port', true);
    return false;
  }

  appState.connectionSettings.server = server;
  appState.connectionSettings.port = port;

  try {
    await invoke('save_connection_settings', { settings: appState.connectionSettings });
    return true;
  } catch (error) {
    console.error('Failed to save settings:', error);
    showToast('Failed to save settings', true);
    return false;
  }
}

// Connect to server
async function connectToServer() {
  try {
    await invoke('connect_to_server', { settings: appState.connectionSettings });
    appState.isConnected = true;
    updateConnectionStatus();
    return true;
  } catch (error) {
    console.error('Connection failed:', error);
    showToast(`Connection failed: ${error}`, true);
    return false;
  }
}

// Disconnect from server
async function disconnectFromServer() {
  try {
    await invoke('disconnect_from_server');
    appState.isConnected = false;
    updateConnectionStatus();
  } catch (error) {
    console.error('Disconnect failed:', error);
  }
}

// Generate random ID (similar to Flutter implementation)
function randomId(length) {
  const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  let result = '';
  for (let i = 0; i < length; i++) {
    result += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return result;
}

// Run all gRPC tests (similar to Flutter's askRPC)
async function runAllTests() {
  if (!await updateConnectionSettings()) {
    return;
  }

  showLoading();
  clearResults();

  const dateTime = new Date();
  addResult(`host:${appState.connectionSettings.server},port:${appState.connectionSettings.port}`, 'info');
  addResult(`==BEGIN(${dateTime.toISOString().substring(2, 19)})==`, 'info');

  try {
    // Connect to server
    if (!await connectToServer()) {
      return;
    }

    // Test 1: Unary RPC
    addResult('Testing Unary RPC...', 'info');
    try {
      const request = {
        data: randomId(5),
        meta: 'TAURI'
      };
      const response = await invoke('unary_rpc', { request });
      addResult('Request/Response', 'success');
      addResult(JSON.stringify(response, null, 2), 'data');
    } catch (error) {
      addResult(`Unary RPC failed: ${error}`, 'error');
    }

    // Test 2: Server Streaming RPC
    addResult('Testing Server Streaming RPC...', 'info');
    try {
      const request = {
        data: `${randomId(5)},${randomId(5)},${randomId(5)}`,
        meta: 'TAURI'
      };

      await invoke('server_streaming_rpc', { request });
      // Note: Responses will be handled by event listeners if implemented
      addResult('Server Streaming started', 'success');
    } catch (error) {
      addResult(`Server Streaming failed: ${error}`, 'error');
    }

    // Test 3: Client Streaming RPC
    addResult('Testing Client Streaming RPC...', 'info');
    try {
      await invoke('client_streaming_rpc');
      addResult('Client Streaming completed', 'success');
    } catch (error) {
      addResult(`Client Streaming failed: ${error}`, 'error');
    }

    // Test 4: Bidirectional Streaming RPC
    addResult('Testing Bidirectional Streaming RPC...', 'info');
    try {
      await invoke('bidirectional_streaming_rpc');
      addResult('Bidirectional Streaming completed', 'success');
    } catch (error) {
      addResult(`Bidirectional Streaming failed: ${error}`, 'error');
    }

  } catch (error) {
    addResult(`Test failed: ${error}`, 'error');
  } finally {
    await disconnectFromServer();
    addResult('====END====', 'info');
    hideLoading();
  }
}
handleStreamingResponse(event.payload);
    });

// Listen for streaming completion
await listen('streaming-complete', (event) => {
  handleStreamingComplete(event.payload);
});

// Listen for streaming errors
await listen('streaming-error', (event) => {
  handleStreamingError(event.payload);
});

// Listen for connection status changes
await listen('connection-status', (event) => {
  updateConnectionStatus(event.payload.connected);
});
  } catch (error) {
  console.warn('Failed to setup Tauri event listeners:', error);
}
}

// Tab switching functionality
function switchTab(tabName) {
  // Update tab buttons
  document.querySelectorAll('.tab-button').forEach(btn => {
    btn.classList.remove('active');
  });
  document.querySelector(`[data-tab="${tabName}"]`).classList.add('active');

  // Update tab content
  document.querySelectorAll('.tab-content').forEach(content => {
    content.classList.remove('active');
  });
  document.querySelector(`#${tabName}-tab`).classList.add('active');
}

// Handle connection form submission
async function handleConnectionForm(e) {
  e.preventDefault();

  if (!uiManager.validateForm()) {
    return;
  }

  uiManager.showLoading('Saving connection settings...');

  try {
    appState.connectionSettings = uiManager.getConnectionSettings();

    // Save settings via Tauri command
    await invoke("save_connection_settings", {
      settings: appState.connectionSettings
    });

    uiManager.hideLoading();
    uiManager.showToast('success', 'Connection settings saved successfully');

    // Test connection
    await testConnection();

    // Switch to testing tab
    uiManager.switchTab('testing');

  } catch (error) {
    uiManager.hideLoading();
    uiManager.showToast('error', `Failed to save settings: ${error}`);
    resultsManager.addResult('error', `Failed to save settings: ${error}`);
  }
}

// Load connection settings
async function loadConnectionSettings() {
  try {
    const settings = await invoke("load_connection_settings");
    appState.connectionSettings = { ...appState.connectionSettings, ...settings };
    uiManager.setConnectionSettings(appState.connectionSettings);
  } catch (error) {
    console.warn('Failed to load connection settings:', error);
    // Use default settings
    uiManager.setConnectionSettings(appState.connectionSettings);
  }
}

// Test connection
async function testConnection() {
  try {
    uiManager.updateConnectionStatus(false, true); // Show connecting
    const result = await grpcClient.testConnection(appState.connectionSettings);
    appState.isConnected = result.connected;
    uiManager.updateConnectionStatus(result.connected);

    if (result.connected) {
      resultsManager.addResult('success', 'Successfully connected to gRPC server');
    } else {
      resultsManager.addResult('warning', 'Connection test completed but server may not be available');
    }
  } catch (error) {
    appState.isConnected = false;
    uiManager.updateConnectionStatus(false);
    resultsManager.addResult('error', `Connection test failed: ${error}`);
  }
}



// RPC type selection
function selectRpcType(rpcType) {
  appState.currentRpcType = rpcType;
  uiManager.selectRpcButton(rpcType);
}

// Execute RPC test
async function executeRpcTest(rpcType) {
  const requestData = uiManager.getRequestData();

  uiManager.showLoading(`Executing ${rpcType.replace('-', ' ')} RPC...`);

  try {
    switch (rpcType) {
      case 'unary':
        await testUnaryRpc(requestData);
        break;
      case 'server-streaming':
        await testServerStreaming(requestData);
        break;
      case 'client-streaming':
        await testClientStreaming(requestData);
        break;
      case 'bidirectional':
        await testBidirectional(requestData);
        break;
    }
  } catch (error) {
    uiManager.hideLoading();
    resultsManager.addResult('error', `${rpcType} RPC Error: ${error}`);
    uiManager.showToast('error', `RPC test failed: ${error}`);
  }
}

// Test unary RPC
async function testUnaryRpc(requestData) {
  try {
    const result = await grpcClient.unaryCall(requestData);
    uiManager.hideLoading();
    resultsManager.addResult('success', 'Unary RPC completed successfully', result, {
      type: 'unary',
      duration: 'N/A'
    });
    uiManager.showToast('success', 'Unary RPC completed');
    uiManager.switchTab('results');
  } catch (error) {
    uiManager.hideLoading();
    throw error;
  }
}

// Test server streaming RPC
async function testServerStreaming(requestData) {
  try {
    appState.streamingActive = true;
    appState.messagesReceived = 0;
    uiManager.updateStreamingCounters(0, 0);
    uiManager.setStreamingControlsEnabled(true);

    await grpcClient.startServerStreaming(requestData);
    uiManager.hideLoading();
    resultsManager.addResult('info', 'Server streaming RPC started - waiting for responses...', requestData);
    uiManager.switchTab('results');
  } catch (error) {
    appState.streamingActive = false;
    uiManager.setStreamingControlsEnabled(false);
    uiManager.hideLoading();
    throw error;
  }
}

// Test client streaming RPC
async function testClientStreaming(requestData) {
  try {
    appState.streamingActive = true;
    appState.messagesSent = 0;
    uiManager.updateStreamingCounters(0, 0);
    uiManager.setStreamingControlsEnabled(true);

    await grpcClient.startClientStreaming();
    uiManager.hideLoading();
    resultsManager.addResult('info', 'Client streaming RPC started - use controls to send messages');
    uiManager.switchTab('results');

    // Send initial message
    setTimeout(() => sendStreamingMessage(), 500);
  } catch (error) {
    appState.streamingActive = false;
    uiManager.setStreamingControlsEnabled(false);
    uiManager.hideLoading();
    throw error;
  }
}

// Test bidirectional streaming RPC
async function testBidirectional(requestData) {
  try {
    appState.streamingActive = true;
    appState.messagesSent = 0;
    appState.messagesReceived = 0;
    uiManager.updateStreamingCounters(0, 0);
    uiManager.setStreamingControlsEnabled(true);

    await grpcClient.startBidirectionalStreaming();
    uiManager.hideLoading();
    resultsManager.addResult('info', 'Bidirectional streaming RPC started');
    uiManager.switchTab('results');

    // Send initial message
    setTimeout(() => sendStreamingMessage(), 500);
  } catch (error) {
    appState.streamingActive = false;
    uiManager.setStreamingControlsEnabled(false);
    uiManager.hideLoading();
    throw error;
  }
}

// Send streaming message
async function sendStreamingMessage() {
  if (!appState.streamingActive) return;

  const requestData = uiManager.getRequestData();

  try {
    await grpcClient.sendStreamingMessage(requestData);
    appState.messagesSent++;
    uiManager.updateStreamingCounters(appState.messagesSent, appState.messagesReceived);
    resultsManager.addResult('info', `Sent streaming message #${appState.messagesSent}`, requestData, {
      messageNumber: appState.messagesSent,
      direction: 'sent'
    });
  } catch (error) {
    resultsManager.addResult('error', `Failed to send streaming message: ${error}`);
  }
}

// Stop streaming
async function stopStreaming() {
  if (!appState.streamingActive) return;

  try {
    await grpcClient.stopStreaming(appState.currentRpcType);
    appState.streamingActive = false;
    uiManager.setStreamingControlsEnabled(false);
    resultsManager.addResult('info', 'Streaming stopped by user');
    uiManager.showToast('info', 'Streaming stopped');
  } catch (error) {
    resultsManager.addResult('error', `Failed to stop streaming: ${error}`);
  }
}

// Handle streaming response
function handleStreamingResponse(response) {
  appState.messagesReceived++;
  uiManager.updateStreamingCounters(appState.messagesSent, appState.messagesReceived);
  resultsManager.addResult('success', `Received streaming response #${appState.messagesReceived}`, response, {
    messageNumber: appState.messagesReceived,
    direction: 'received'
  });
}

// Handle streaming completion
function handleStreamingComplete(data) {
  appState.streamingActive = false;
  uiManager.setStreamingControlsEnabled(false);
  resultsManager.addResult('info', 'Streaming completed', data, {
    totalSent: appState.messagesSent,
    totalReceived: appState.messagesReceived
  });
  uiManager.showToast('success', 'Streaming completed');
}

// Handle streaming error
function handleStreamingError(error) {
  appState.streamingActive = false;
  uiManager.setStreamingControlsEnabled(false);
  resultsManager.addResult('error', `Streaming error: ${error}`);
  uiManager.showToast('error', `Streaming error: ${error}`);
}

// Update connection status
function updateConnectionStatus(connected) {
  appState.isConnected = connected;
  uiManager.updateConnectionStatus(connected);
}

// Global functions for HTML onclick handlers
window.hideToast = function (toastId) {
  const toast = document.querySelector(`#${toastId}`);
  toast.classList.add('hidden');
};

window.closeModal = function () {
  uiManager.closeModal();
};
