/*!
 * Hello gRPC Tauri Frontend Application
 * 
 * This is the main frontend JavaScript module that handles:
 * 1. Platform detection (native Tauri vs web browser)
 * 2. UI interaction and event handling
 * 3. Dual-mode gRPC communication:
 *    - Native Mode: Direct Tauri commands to Rust backend
 *    - Web Mode: HTTP gateway simulation via WebGrpcClient
 * 
 * Architecture Flow:
 * UI Events → Mode Detection → Native (Tauri Commands) | Web (HTTP) → Results Display
 */

// Tauri API access with fallback for web mode
const { invoke } = window.__TAURI__ ? window.__TAURI__.core : { invoke: () => Promise.reject('Tauri not available') };

// ============================================================================
// Utility Functions
// ============================================================================

/// Generate random ID for request tracking (matches Flutter's Utils.randomId)
/// 
/// Creates a random alphanumeric string of specified length for use in
/// gRPC request metadata and stream identification.
/// 
/// @param {number} length - Length of the random string to generate
/// @returns {string} Random alphanumeric string
function generateRandomId(length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    let result = '';
    for (let i = 0; i < length; i++) {
        result += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return result;
}

/// Get local IP address with fallback to localhost
/// 
/// Attempts to retrieve the local IP address using Tauri command.
/// Falls back to 'localhost' if running in web mode or if the
/// command fails (e.g., network unavailable).
/// 
/// @returns {Promise<string>} Local IP address or 'localhost'
async function getLocalIP() {
    try {
        return await invoke('get_local_ip');
    } catch (error) {
        return 'localhost';
    }
}

/// Check if running in web mode (browser) vs native mode (Tauri)
/// 
/// Detects the execution environment by checking for Tauri API availability.
/// This determines which communication method to use.
/// 
/// @returns {boolean} True if running in web browser, false if native Tauri
function isWebMode() {
    return !window.__TAURI__;
}

/// Platform detection for web environments
/// 
/// Analyzes the user agent string to determine the operating system
/// when running in web browser mode.
/// 
/// @returns {string} Platform identifier (e.g., 'macOS Web', 'Windows Web')
function getWebPlatformInfo() {
    const userAgent = navigator.userAgent;
    if (userAgent.includes('Mac')) return 'macOS Web';
    if (userAgent.includes('Win')) return 'Windows Web';
    if (userAgent.includes('Linux')) return 'Linux Web';
    return 'Web';
}

/// Get system information with fallback for web mode
/// 
/// Attempts to retrieve the system information using Tauri command.
/// Falls back to web platform detection if running in web mode.
/// 
/// @returns {Promise<string>} System info like 'macOS', 'Windows', etc.
async function getSystemInfo() {
    try {
        return await invoke('get_system_info');
    } catch (error) {
        return getWebPlatformInfo().replace(' Web', '');
    }
}

// ============================================================================
// Application Initialization and Event Handling
// ============================================================================

/// Main application initialization
/// 
/// Sets up the UI, detects the execution mode, initializes event listeners,
/// and configures the application based on the detected platform.
/// 
/// Initialization Flow:
/// 1. Mode detection (native vs web)
/// 2. Default configuration setup
/// 3. Platform info display
/// 4. Event listener registration
/// 5. UI state initialization
document.addEventListener('DOMContentLoaded', async function () {
    // DOM element references
    const hostInput = document.getElementById('host');
    const portInput = document.getElementById('port');
    const askBtn = document.getElementById('ask-btn');
    const resultsContainer = document.getElementById('results');
    const currentConfig = document.getElementById('current-config');
    const configTitle = document.querySelector('.config-title');

    // Application state
    let webMode = isWebMode();
    let streamResponses = [];

    // Initialize with local IP or fallback to localhost
    const localIP = webMode ? 'localhost' : await getLocalIP();
    hostInput.value = localIP;
    updateCurrentConfig();

    // Update title with platform info
    const systemInfo = webMode ? getWebPlatformInfo() : await getSystemInfo();
    configTitle.textContent = `gRPC Server Configuration -- ${systemInfo}`;

    // Set up event listeners for streaming (native mode only)
    /// 
    /// Registers event listeners for streaming operations in native mode.
    /// These events are emitted by the Rust backend during streaming operations.
    if (!webMode) {
        try {
            await window.__TAURI__.event.listen('streaming-response', (event) => {
                streamResponses.push(event.payload.response);
            });
            await window.__TAURI__.event.listen('streaming-error', (event) => {
                addResultCard(`Error: ${event.payload.error}`, 'error');
            });
        } catch (error) {
            console.log('Failed to set up streaming listeners:', error);
        }
    }

    // ========================================================================
    // UI Event Handlers
    // ========================================================================

    /// Update the current configuration display
    /// 
    /// Reflects the current host and port settings in the UI
    /// whenever the user modifies the input fields.
    function updateCurrentConfig() {
        const host = hostInput.value || 'localhost';
        const port = portInput.value || '9996';
        currentConfig.textContent = `${host}:${port}`;
    }

    // Listen for input changes to update config display
    hostInput.addEventListener('input', updateCurrentConfig);
    portInput.addEventListener('input', updateCurrentConfig);

    /// Main test execution handler
    /// 
    /// Simplified execution that automatically uses the appropriate mode
    /// based on platform detection, matching Flutter's behavior.
    askBtn.addEventListener('click', async function () {
        // Extract configuration
        const host = hostInput.value || 'localhost';
        const port = parseInt(portInput.value) || 9996;

        // Clear previous results and initialize state
        resultsContainer.innerHTML = '';
        streamResponses = [];

        // Add session header with timestamp (Flutter-compatible format)
        addResultCard(`host:${host},port:${port}`, 'status-host');

        const now = new Date();
        const timestamp = now.toISOString().substring(2, 19).replace('T', ' ');
        addResultCard(`==BEGIN(${timestamp})==`, 'status-begin');

        try {
            // 根据平台自动选择通信方式 - 与 Flutter 保持一致
            if (webMode) {
                await executeWebMode(host, port);
            } else {
                await executeNativeMode(host, port);
            }

            // Add end marker - match Flutter format
            addResultCard('====END====', 'status-end');

        } catch (error) {
            console.error('Error:', error);
            addResultCard(`Error: ${error}`, 'error');
            addResultCard('====END====', 'status-end');
        }
    });

    // Web mode execution - match Flutter's WebGrpcClient behavior
    async function executeWebMode(host, port) {
        const webClient = new window.WebGrpcClient(host, port);

        try {
            // 1. Talk (Unary RPC) - match Flutter's talkWeb()
            const talkRequest = {
                data: generateRandomId(5),
                meta: "TAURI_WEB"
            };
            const talkResponse = await webClient.talk(talkRequest);
            addResultCard('Web Request/Response', 'status-request');
            addResultCard(formatGrpcResponse(talkResponse), 'default');

            // 2. TalkOneAnswerMore (Server Streaming) - match Flutter's talkOneAnswerMoreWeb()
            const serverStreamRequest = {
                data: `${generateRandomId(5)},${generateRandomId(5)},${generateRandomId(5)}`,
                meta: "TAURI_WEB"
            };

            for await (const response of webClient.talkOneAnswerMore(serverStreamRequest)) {
                addResultCard('Web Server Streaming', 'status-request');
                addResultCard(formatGrpcResponse(response), 'default');
            }

            // 3. TalkMoreAnswerOne (Client Streaming) - match Flutter's talkMoreAnswerOneWeb()
            const clientRequests = async function* () {
                for (let i = 0; i < 3; i++) {
                    yield {
                        data: generateRandomId(5),
                        meta: "TAURI_WEB"
                    };
                    await new Promise(resolve => setTimeout(resolve, 100 + Math.random() * 100));
                }
            };

            const clientResponse = await webClient.talkMoreAnswerOne(clientRequests());
            addResultCard('Web Client Streaming', 'status-request');
            addResultCard(formatGrpcResponse(clientResponse), 'default');

            // 4. TalkBidirectional (Bidirectional Streaming) - match Flutter's talkBidirectionalWeb()
            const bidirectionalRequests = async function* () {
                for (let i = 0; i < 3; i++) {
                    yield {
                        data: generateRandomId(5),
                        meta: "TAURI_WEB"
                    };
                    await new Promise(resolve => setTimeout(resolve, 10));
                }
            };

            for await (const response of webClient.talkBidirectional(bidirectionalRequests())) {
                addResultCard('Web Bidirectional Streaming', 'status-request');
                addResultCard(formatGrpcResponse(response), 'default');
            }

        } catch (error) {
            addResultCard(`Web Error: ${error}`, 'error');
            console.error('Web mode error:', error);
        }
    }

    // Native mode execution - match original Tauri behavior
    async function executeNativeMode(host, port) {
        try {
            // First initialize the config manager if not already done
            await invoke('init_config_manager');
        } catch (error) {
            console.log('Config manager already initialized or failed to initialize:', error);
        }

        // Update the connection settings
        await invoke('save_connection_settings', {
            settings: {
                server: host,
                port: port,
                use_tls: false,
                timeout_seconds: 30
            }
        });

        // Connect to server
        await invoke('connect_to_server');

        // 1. Talk (Unary RPC) - match Flutter's talk()
        const talkRequest = {
            data: generateRandomId(5),
            meta: "TAURI"
        };
        const talkResponse = await invoke('unary_rpc', { request: talkRequest });
        addResultCard('Request/Response', 'status-request');
        addResultCard(formatGrpcResponse(talkResponse), 'default');

        // 2. TalkOneAnswerMore (Server Streaming) - match Flutter's talkOneAnswerMore()
        const serverStreamRequest = {
            data: `${generateRandomId(5)},${generateRandomId(5)},${generateRandomId(5)}`,
            meta: "TAURI"
        };

        streamResponses = [];
        await invoke('server_streaming_rpc', {
            request: serverStreamRequest,
            streamId: 'server-stream-' + Date.now()
        });

        // Wait for responses
        await new Promise(resolve => setTimeout(resolve, 2000));

        // Display all server streaming responses
        for (const response of streamResponses) {
            addResultCard('Server Streaming', 'status-request');
            addResultCard(formatGrpcResponse(response), 'default');
        }

        // 3. TalkMoreAnswerOne (Client Streaming) - match Flutter's talkMoreAnswerOne()
        streamResponses = [];
        const clientRequests = [];
        for (let i = 0; i < 3; i++) {
            clientRequests.push({
                data: generateRandomId(5),
                meta: "TAURI"
            });
        }

        await invoke('client_streaming_rpc', {
            requests: clientRequests,
            streamId: 'client-stream-' + Date.now()
        });

        // Wait for response
        await new Promise(resolve => setTimeout(resolve, 2000));

        // Display client streaming response
        if (streamResponses.length > 0) {
            addResultCard('Client Streaming', 'status-request');
            addResultCard(formatGrpcResponse(streamResponses[streamResponses.length - 1]), 'default');
        }

        // 4. TalkBidirectional (Bidirectional Streaming) - match Flutter's talkBidirectional()
        streamResponses = [];
        const bidirectionalRequests = [];
        for (let i = 0; i < 3; i++) {
            bidirectionalRequests.push({
                data: generateRandomId(5),
                meta: "TAURI"
            });
        }

        await invoke('bidirectional_streaming_rpc', {
            requests: bidirectionalRequests,
            streamId: 'bidirectional-stream-' + Date.now()
        });

        // Wait for responses
        await new Promise(resolve => setTimeout(resolve, 2000));

        // Display all bidirectional streaming responses
        for (const response of streamResponses) {
            addResultCard('Bidirectional Streaming', 'status-request');
            addResultCard(formatGrpcResponse(response), 'default');
        }
    }

    // Format gRPC response to match Flutter's exact format
    function formatGrpcResponse(response) {
        // If response is already a string, return as is
        if (typeof response === 'string') {
            return response;
        }

        const lines = [];
        lines.push('status: 200');
        lines.push('results: {');

        // Helper function to format nested objects
        function formatValue(key, value, indent = '') {
            const lines = [];

            if (typeof value === 'object' && value !== null) {
                if (Array.isArray(value)) {
                    // Handle arrays - extract first object if exists
                    if (value.length > 0 && typeof value[0] === 'object') {
                        const obj = value[0];
                        Object.entries(obj).forEach(([subKey, subValue]) => {
                            if (typeof subValue === 'object' && subValue !== null) {
                                // Nested object - format each field
                                Object.entries(subValue).forEach(([nestedKey, nestedValue]) => {
                                    lines.push(`${indent}kv: {${nestedKey} : ${nestedValue}}`);
                                });
                            } else {
                                lines.push(`${indent}kv: {${subKey} : ${subValue}}`);
                            }
                        });
                    }
                } else {
                    // Handle objects - format each field
                    Object.entries(value).forEach(([subKey, subValue]) => {
                        lines.push(`${indent}kv: {${subKey} : ${subValue}}`);
                    });
                }
            } else {
                lines.push(`${indent}kv: {${key} : ${value}}`);
            }

            return lines;
        }

        // Add id field first if it exists
        if (response.id) {
            lines.push(`id: ${response.id}`);
        }

        // Add kv entries for all other fields
        Object.entries(response).forEach(([key, value]) => {
            if (key !== 'id') {
                const formattedLines = formatValue(key, value);
                lines.push(...formattedLines);
            }
        });

        lines.push('}');
        return lines.join('\n');
    }

    // Add result card to the UI
    function addResultCard(message, type = 'default') {
        const card = document.createElement('div');
        card.className = 'result-card';

        const text = document.createElement('div');
        text.className = `result-text ${type}`;
        text.textContent = message;

        card.appendChild(text);
        resultsContainer.appendChild(card);

        // Scroll to bottom
        card.scrollIntoView({ behavior: 'smooth' });
    }

    // Initialize
    updateCurrentConfig();
});
