const { invoke } = window.__TAURI__ ? window.__TAURI__.core : { invoke: () => Promise.reject('Tauri not available') };

// Generate random ID like Flutter's Utils.randomId
function generateRandomId(length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    let result = '';
    for (let i = 0; i < length; i++) {
        result += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return result;
}

// Function to get local IP address
async function getLocalIP() {
    try {
        // Try to get local IP using Tauri command first
        const localIP = await invoke('get_local_ip');
        return localIP;
    } catch (error) {
        console.log('Failed to get local IP from Tauri, using fallback method');
        
        // Fallback method using WebRTC
        return new Promise((resolve) => {
            const pc = new RTCPeerConnection({
                iceServers: []
            });
            
            pc.createDataChannel('');
            pc.createOffer().then(offer => pc.setLocalDescription(offer));
            
            pc.onicecandidate = (ice) => {
                if (!ice || !ice.candidate || !ice.candidate.candidate) return;
                const myIP = /([0-9]{1,3}(\.[0-9]{1,3}){3}|[a-f0-9]{1,4}(:[a-f0-9]{1,4}){7})/.exec(ice.candidate.candidate)[1];
                pc.onicecandidate = () => {};
                resolve(myIP);
            };
            
            // Fallback to localhost if no IP found within 2 seconds
            setTimeout(() => {
                resolve('localhost');
            }, 2000);
        });
    }
}

// Check if running in web mode
function isWebMode() {
    return !window.__TAURI__;
}

// Get platform info for web mode
function getWebPlatformInfo() {
    const userAgent = navigator.userAgent;
    if (userAgent.includes('Mac')) {
        return 'macOS Web';
    } else if (userAgent.includes('Win')) {
        return 'Windows Web';
    } else if (userAgent.includes('Linux')) {
        return 'Linux Web';
    }
    return 'Web';
}

document.addEventListener('DOMContentLoaded', async function() {
    const hostInput = document.getElementById('host');
    const portInput = document.getElementById('port');
    const testBtn = document.getElementById('test-btn');
    const resultsContainer = document.getElementById('results');
    const currentConfig = document.getElementById('current-config');
    const configTitle = document.querySelector('.config-title');
    const modeRadios = document.querySelectorAll('input[name="mode"]');

    let webMode = isWebMode();
    let streamResponses = [];
    
    // Set default mode based on platform
    if (webMode) {
        document.querySelector('input[value="web"]').checked = true;
        document.querySelector('input[value="grpc"]').disabled = true;
    }

    // Initialize with local IP
    try {
        let localIP = 'localhost';
        if (!webMode) {
            localIP = await getLocalIP();
        }
        hostInput.value = localIP;
        updateCurrentConfig();
    } catch (error) {
        console.log('Failed to get local IP, using localhost');
        hostInput.value = 'localhost';
        updateCurrentConfig();
    }

    // Get system information and update title
    try {
        let systemInfo = 'Unknown';
        if (webMode) {
            systemInfo = getWebPlatformInfo();
        } else {
            const platform = await invoke('get_platform_info');
            const arch = await invoke('get_arch_info');
            systemInfo = `${platform} ${arch}`;
        }
        configTitle.textContent = `gRPC Server Configuration --  ${systemInfo}`;
    } catch (error) {
        // Fallback if system info commands don't exist
        const fallbackInfo = webMode ? getWebPlatformInfo() : 'Tauri';
        configTitle.textContent = `gRPC Server Configuration --  ${fallbackInfo}`;
    }

    // Set up event listeners for streaming responses (only for native mode)
    async function setupStreamingListeners() {
        if (webMode) return; // Skip for web mode
        
        try {
            // Listen for streaming responses
            await window.__TAURI__.event.listen('streaming-response', (event) => {
                const response = event.payload.response;
                streamResponses.push(response);
                console.log('Received streaming response:', response);
            });

            // Listen for streaming completion
            await window.__TAURI__.event.listen('streaming-complete', (event) => {
                console.log('Streaming complete:', event.payload.message);
            });

            // Listen for streaming errors
            await window.__TAURI__.event.listen('streaming-error', (event) => {
                addResultCard(`Error: ${event.payload.error}`, 'error');
            });
        } catch (error) {
            console.log('Failed to set up streaming listeners:', error);
        }
    }

    // Initialize streaming listeners
    if (!webMode) {
        await setupStreamingListeners();
    }

    // Update current config display
    function updateCurrentConfig() {
        const host = hostInput.value || 'localhost';
        const port = portInput.value || '9996';
        currentConfig.textContent = `${host}:${port}`;
    }

    // Listen for input changes
    hostInput.addEventListener('input', updateCurrentConfig);
    portInput.addEventListener('input', updateCurrentConfig);

    // Test button click handler - support both native and web modes
    testBtn.addEventListener('click', async function() {
        const host = hostInput.value || 'localhost';
        const port = parseInt(portInput.value) || 9996;
        const selectedMode = document.querySelector('input[name="mode"]:checked').value;
        const useWebMode = webMode || selectedMode === 'web';
        
        // Clear previous results
        resultsContainer.innerHTML = '';
        streamResponses = [];
        
        // Add host info - match Flutter format
        addResultCard(`host:${host},port:${port}`, 'status-host');
        
        // Add begin timestamp - match Flutter format exactly
        const now = new Date();
        const timestamp = now.toISOString().substring(2, 19).replace('T', ' ');
        addResultCard(`==BEGIN(${timestamp})==`, 'status-begin');

        // Add platform info - match Flutter format
        const platformInfo = useWebMode ? 'Web Platform - Using HTTP simulation for gRPC' : 'Native Platform - Using direct gRPC';
        addResultCard(platformInfo, 'status-platform');

        try {
            if (useWebMode) {
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
        // Connect to server first
        await invoke('connect_to_server', {
            settings: {
                host: host,
                port: port,
                use_tls: false,
                timeout_seconds: 30
            }
        });

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
