/**
 * UI Manager Module
 * Handles all UI interactions and state management
 */

export class UIManager {
  constructor() {
    this.currentTab = 'settings';
    this.elements = {};
    this.validators = new Map();
    this.setupValidators();
  }

  /**
   * Initialize UI elements and event listeners
   */
  initialize() {
    this.cacheElements();
    this.setupEventListeners();
    this.setupFormValidation();
  }

  /**
   * Cache frequently used DOM elements
   */
  cacheElements() {
    this.elements = {
      // Navigation
      tabButtons: document.querySelectorAll('.tab-button'),
      tabContents: document.querySelectorAll('.tab-content'),
      
      // Forms
      connectionForm: document.querySelector('#connection-form'),
      serverInput: document.querySelector('#server-input'),
      portInput: document.querySelector('#port-input'),
      timeoutInput: document.querySelector('#timeout-input'),
      tlsCheckbox: document.querySelector('#tls-checkbox'),
      requestData: document.querySelector('#request-data'),
      requestMeta: document.querySelector('#request-meta'),
      
      // Status
      connectionIndicator: document.querySelector('#connection-indicator'),
      connectionText: document.querySelector('#connection-text'),
      messagesSent: document.querySelector('#messages-sent'),
      messagesReceived: document.querySelector('#messages-received'),
      
      // Controls
      rpcButtons: document.querySelectorAll('.rpc-button'),
      streamingControls: document.querySelector('#streaming-controls'),
      sendMessageBtn: document.querySelector('#send-message-btn'),
      stopStreamingBtn: document.querySelector('#stop-streaming-btn'),
      clearResultsBtn: document.querySelector('#clear-results-btn'),
      
      // Results
      resultsContainer: document.querySelector('#results-container'),
      
      // Overlays
      loadingOverlay: document.querySelector('#loading-overlay'),
      loadingText: document.querySelector('.loading-text'),
      successToast: document.querySelector('#success-toast'),
      errorToast: document.querySelector('#error-toast'),
      resultModal: document.querySelector('#result-modal'),
      modalTitle: document.querySelector('#modal-title'),
      modalContent: document.querySelector('#modal-content')
    };
  }

  /**
   * Setup event listeners
   */
  setupEventListeners() {
    // Tab navigation
    this.elements.tabButtons.forEach(button => {
      button.addEventListener('click', (e) => {
        this.switchTab(e.target.dataset.tab);
      });
    });

    // Modal close handlers
    document.addEventListener('click', (e) => {
      if (e.target === this.elements.resultModal) {
        this.closeModal();
      }
    });

    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape') {
        this.closeModal();
        this.hideAllToasts();
      }
    });

    // Touch-friendly interactions
    this.setupTouchInteractions();
  }

  /**
   * Setup touch-friendly interactions
   */
  setupTouchInteractions() {
    // Add touch feedback to buttons
    const buttons = document.querySelectorAll('button, .rpc-button');
    buttons.forEach(button => {
      button.addEventListener('touchstart', () => {
        button.style.transform = 'scale(0.98)';
      });
      
      button.addEventListener('touchend', () => {
        setTimeout(() => {
          button.style.transform = '';
        }, 100);
      });
    });

    // Prevent zoom on double tap for form inputs
    const inputs = document.querySelectorAll('input');
    inputs.forEach(input => {
      input.addEventListener('touchend', (e) => {
        e.preventDefault();
        input.focus();
      });
    });
  }

  /**
   * Setup form validation
   */
  setupFormValidation() {
    // Real-time validation
    this.elements.serverInput.addEventListener('blur', () => {
      this.validateField('server');
    });
    
    this.elements.portInput.addEventListener('blur', () => {
      this.validateField('port');
    });
    
    this.elements.timeoutInput.addEventListener('blur', () => {
      this.validateField('timeout');
    });
  }

  /**
   * Setup validation rules
   */
  setupValidators() {
    this.validators.set('server', {
      required: true,
      pattern: /^[a-zA-Z0-9.-]+$/,
      message: 'Invalid server address format'
    });
    
    this.validators.set('port', {
      required: true,
      min: 1,
      max: 65535,
      message: 'Port must be between 1 and 65535'
    });
    
    this.validators.set('timeout', {
      required: true,
      min: 1,
      max: 300,
      message: 'Timeout must be between 1 and 300 seconds'
    });
  }

  /**
   * Validate a specific field
   */
  validateField(fieldName) {
    const validator = this.validators.get(fieldName);
    if (!validator) return true;

    const input = this.elements[`${fieldName}Input`];
    const errorElement = document.querySelector(`#${fieldName}-error`);
    const value = input.value.trim();

    // Clear previous error
    errorElement.textContent = '';
    input.classList.remove('error');

    // Required validation
    if (validator.required && !value) {
      this.showFieldError(input, errorElement, `${fieldName} is required`);
      return false;
    }

    // Pattern validation
    if (validator.pattern && !validator.pattern.test(value)) {
      this.showFieldError(input, errorElement, validator.message);
      return false;
    }

    // Numeric range validation
    if (validator.min !== undefined || validator.max !== undefined) {
      const numValue = parseInt(value);
      if (isNaN(numValue) || 
          (validator.min !== undefined && numValue < validator.min) ||
          (validator.max !== undefined && numValue > validator.max)) {
        this.showFieldError(input, errorElement, validator.message);
        return false;
      }
    }

    return true;
  }

  /**
   * Show field validation error
   */
  showFieldError(input, errorElement, message) {
    input.classList.add('error');
    errorElement.textContent = message;
  }

  /**
   * Validate entire form
   */
  validateForm() {
    const fields = ['server', 'port', 'timeout'];
    return fields.every(field => this.validateField(field));
  }

  /**
   * Switch between tabs
   */
  switchTab(tabName) {
    if (this.currentTab === tabName) return;

    // Update tab buttons
    this.elements.tabButtons.forEach(btn => {
      btn.classList.remove('active');
    });
    document.querySelector(`[data-tab="${tabName}"]`).classList.add('active');

    // Update tab content with animation
    this.elements.tabContents.forEach(content => {
      content.classList.remove('active');
    });
    
    const targetTab = document.querySelector(`#${tabName}-tab`);
    targetTab.classList.add('active');

    this.currentTab = tabName;
  }

  /**
   * Update connection status indicator
   */
  updateConnectionStatus(connected, connecting = false) {
    const indicator = this.elements.connectionIndicator;
    const text = this.elements.connectionText;

    if (connecting) {
      indicator.className = 'status-indicator status-connecting';
      text.textContent = 'Connecting...';
    } else if (connected) {
      indicator.className = 'status-indicator status-connected';
      text.textContent = 'Connected';
    } else {
      indicator.className = 'status-indicator status-disconnected';
      text.textContent = 'Disconnected';
    }
  }

  /**
   * Update RPC button selection
   */
  selectRpcButton(rpcType) {
    this.elements.rpcButtons.forEach(btn => {
      btn.classList.remove('active');
    });
    
    const targetButton = document.querySelector(`[data-rpc="${rpcType}"]`);
    if (targetButton) {
      targetButton.classList.add('active');
    }

    // Show/hide streaming controls
    const isStreaming = rpcType.includes('streaming') || rpcType === 'bidirectional';
    if (isStreaming) {
      this.elements.streamingControls.classList.remove('hidden');
    } else {
      this.elements.streamingControls.classList.add('hidden');
    }
  }

  /**
   * Update streaming counters
   */
  updateStreamingCounters(sent, received) {
    if (this.elements.messagesSent) {
      this.elements.messagesSent.textContent = sent;
    }
    if (this.elements.messagesReceived) {
      this.elements.messagesReceived.textContent = received;
    }
  }

  /**
   * Show loading overlay
   */
  showLoading(message = 'Processing...') {
    this.elements.loadingText.textContent = message;
    this.elements.loadingOverlay.classList.remove('hidden');
  }

  /**
   * Hide loading overlay
   */
  hideLoading() {
    this.elements.loadingOverlay.classList.add('hidden');
  }

  /**
   * Show toast notification
   */
  showToast(type, message, duration = 5000) {
    const toast = type === 'success' ? this.elements.successToast : this.elements.errorToast;
    const messageElement = toast.querySelector('.toast-message');
    
    messageElement.textContent = message;
    toast.classList.remove('hidden');
    
    // Auto-hide
    setTimeout(() => {
      this.hideToast(type);
    }, duration);
  }

  /**
   * Hide specific toast
   */
  hideToast(type) {
    const toast = type === 'success' ? this.elements.successToast : this.elements.errorToast;
    toast.classList.add('hidden');
  }

  /**
   * Hide all toasts
   */
  hideAllToasts() {
    this.elements.successToast.classList.add('hidden');
    this.elements.errorToast.classList.add('hidden');
  }

  /**
   * Show result modal
   */
  showModal(title, content) {
    this.elements.modalTitle.textContent = title;
    this.elements.modalContent.textContent = typeof content === 'string' ? 
      content : JSON.stringify(content, null, 2);
    this.elements.resultModal.classList.remove('hidden');
  }

  /**
   * Close modal
   */
  closeModal() {
    this.elements.resultModal.classList.add('hidden');
  }

  /**
   * Get form data
   */
  getConnectionSettings() {
    return {
      server: this.elements.serverInput.value.trim(),
      port: parseInt(this.elements.portInput.value),
      useTls: this.elements.tlsCheckbox.checked,
      timeout: parseInt(this.elements.timeoutInput.value)
    };
  }

  /**
   * Set form data
   */
  setConnectionSettings(settings) {
    this.elements.serverInput.value = settings.server || 'localhost';
    this.elements.portInput.value = settings.port || 9996;
    this.elements.tlsCheckbox.checked = settings.useTls || false;
    this.elements.timeoutInput.value = settings.timeout || 30;
  }

  /**
   * Get request data
   */
  getRequestData() {
    return {
      data: this.elements.requestData.value || "0",
      meta: this.elements.requestMeta.value || "tauri"
    };
  }

  /**
   * Enable/disable streaming controls
   */
  setStreamingControlsEnabled(enabled) {
    this.elements.sendMessageBtn.disabled = !enabled;
    this.elements.stopStreamingBtn.disabled = !enabled;
  }
}

export default UIManager;