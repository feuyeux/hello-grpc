/**
 * Results Manager Module
 * Handles result display and management
 */

export class ResultsManager {
  constructor(container) {
    this.container = container;
    this.results = [];
    this.maxResults = 100; // Limit results for performance
  }

  /**
   * Add a new result
   */
  addResult(type, message, data = null, metadata = {}) {
    const result = {
      id: this.generateId(),
      type,
      message,
      data,
      metadata,
      timestamp: new Date()
    };

    this.results.unshift(result); // Add to beginning for newest first

    // Limit results
    if (this.results.length > this.maxResults) {
      this.results = this.results.slice(0, this.maxResults);
    }

    this.renderResult(result);
    this.scrollToTop();
  }

  /**
   * Generate unique ID for result
   */
  generateId() {
    return `result-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
  }

  /**
   * Render a single result
   */
  renderResult(result) {
    // Remove placeholder if it exists
    this.removePlaceholder();

    const resultElement = this.createResultElement(result);
    
    // Insert at the top
    this.container.insertBefore(resultElement, this.container.firstChild);
  }

  /**
   * Create result DOM element
   */
  createResultElement(result) {
    const element = document.createElement('div');
    element.className = `result result-${result.type}`;
    element.dataset.resultId = result.id;

    const timeString = result.timestamp.toLocaleTimeString();
    const dateString = result.timestamp.toLocaleDateString();

    let dataHtml = '';
    if (result.data) {
      const dataStr = this.formatData(result.data);
      dataHtml = `<div class="result-data">${dataStr}</div>`;
    }

    let metadataHtml = '';
    if (result.metadata && Object.keys(result.metadata).length > 0) {
      const metaStr = Object.entries(result.metadata)
        .map(([key, value]) => `${key}: ${value}`)
        .join(' | ');
      metadataHtml = `<div class="result-metadata">${metaStr}</div>`;
    }

    element.innerHTML = `
      <div class="result-header">
        <div class="result-type-info">
          <span class="result-type">${result.type.toUpperCase()}</span>
          ${this.getTypeIcon(result.type)}
        </div>
        <div class="result-timestamp">
          <span class="result-time">${timeString}</span>
          <span class="result-date">${dateString}</span>
        </div>
      </div>
      <div class="result-content">
        <div class="result-message">${this.escapeHtml(result.message)}</div>
        ${metadataHtml}
        ${dataHtml}
      </div>
    `;

    // Add click handler for detailed view
    if (result.data) {
      element.addEventListener('click', () => {
        this.showDetailedView(result);
      });
      element.classList.add('clickable');
    }

    // Add animation
    element.style.opacity = '0';
    element.style.transform = 'translateY(-10px)';
    
    requestAnimationFrame(() => {
      element.style.transition = 'all 0.3s ease';
      element.style.opacity = '1';
      element.style.transform = 'translateY(0)';
    });

    return element;
  }

  /**
   * Get icon for result type
   */
  getTypeIcon(type) {
    const icons = {
      success: '✅',
      error: '❌',
      warning: '⚠️',
      info: 'ℹ️',
      streaming: '📡'
    };
    return `<span class="result-icon">${icons[type] || 'ℹ️'}</span>`;
  }

  /**
   * Format data for display
   */
  formatData(data) {
    if (typeof data === 'string') {
      return this.escapeHtml(data);
    }
    
    try {
      return this.escapeHtml(JSON.stringify(data, null, 2));
    } catch (error) {
      return this.escapeHtml(String(data));
    }
  }

  /**
   * Escape HTML to prevent XSS
   */
  escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
  }

  /**
   * Show detailed view of result
   */
  showDetailedView(result) {
    const event = new CustomEvent('showResultDetail', {
      detail: {
        title: `${result.type.toUpperCase()}: ${result.message}`,
        content: result.data,
        timestamp: result.timestamp
      }
    });
    document.dispatchEvent(event);
  }

  /**
   * Remove placeholder
   */
  removePlaceholder() {
    const placeholder = this.container.querySelector('.placeholder');
    if (placeholder) {
      placeholder.remove();
    }
  }

  /**
   * Show placeholder
   */
  showPlaceholder() {
    if (this.container.querySelector('.placeholder')) return;

    const placeholder = document.createElement('div');
    placeholder.className = 'placeholder';
    placeholder.innerHTML = `
      <div class="placeholder-icon">📊</div>
      <p>Test results will appear here...</p>
      <p class="placeholder-hint">Run a gRPC test to see results</p>
    `;
    
    this.container.appendChild(placeholder);
  }

  /**
   * Clear all results
   */
  clear() {
    this.results = [];
    this.container.innerHTML = '';
    this.showPlaceholder();
  }

  /**
   * Scroll to top of results
   */
  scrollToTop() {
    this.container.scrollTop = 0;
  }

  /**
   * Scroll to bottom of results
   */
  scrollToBottom() {
    this.container.scrollTop = this.container.scrollHeight;
  }

  /**
   * Filter results by type
   */
  filterByType(type) {
    const results = this.container.querySelectorAll('.result');
    results.forEach(result => {
      if (type === 'all' || result.classList.contains(`result-${type}`)) {
        result.style.display = 'block';
      } else {
        result.style.display = 'none';
      }
    });
  }

  /**
   * Search results
   */
  search(query) {
    if (!query.trim()) {
      this.clearSearch();
      return;
    }

    const results = this.container.querySelectorAll('.result');
    const searchTerm = query.toLowerCase();

    results.forEach(result => {
      const message = result.querySelector('.result-message').textContent.toLowerCase();
      const data = result.querySelector('.result-data')?.textContent.toLowerCase() || '';
      
      if (message.includes(searchTerm) || data.includes(searchTerm)) {
        result.style.display = 'block';
        this.highlightSearchTerm(result, searchTerm);
      } else {
        result.style.display = 'none';
      }
    });
  }

  /**
   * Clear search highlighting
   */
  clearSearch() {
    const results = this.container.querySelectorAll('.result');
    results.forEach(result => {
      result.style.display = 'block';
      this.removeHighlighting(result);
    });
  }

  /**
   * Highlight search term in result
   */
  highlightSearchTerm(result, term) {
    // Simple highlighting - in production, use a more robust solution
    const messageEl = result.querySelector('.result-message');
    const dataEl = result.querySelector('.result-data');
    
    [messageEl, dataEl].forEach(el => {
      if (!el) return;
      
      const text = el.textContent;
      const regex = new RegExp(`(${term})`, 'gi');
      const highlighted = text.replace(regex, '<mark>$1</mark>');
      el.innerHTML = highlighted;
    });
  }

  /**
   * Remove highlighting from result
   */
  removeHighlighting(result) {
    const messageEl = result.querySelector('.result-message');
    const dataEl = result.querySelector('.result-data');
    
    [messageEl, dataEl].forEach(el => {
      if (!el) return;
      
      // Remove mark tags and restore original text
      el.innerHTML = el.textContent;
    });
  }

  /**
   * Export results to JSON
   */
  exportToJson() {
    const exportData = {
      exportDate: new Date().toISOString(),
      totalResults: this.results.length,
      results: this.results.map(result => ({
        ...result,
        timestamp: result.timestamp.toISOString()
      }))
    };

    return JSON.stringify(exportData, null, 2);
  }

  /**
   * Get results statistics
   */
  getStatistics() {
    const stats = {
      total: this.results.length,
      byType: {}
    };

    this.results.forEach(result => {
      stats.byType[result.type] = (stats.byType[result.type] || 0) + 1;
    });

    return stats;
  }

  /**
   * Get recent results
   */
  getRecentResults(count = 10) {
    return this.results.slice(0, count);
  }

  /**
   * Find result by ID
   */
  findResult(id) {
    return this.results.find(result => result.id === id);
  }

  /**
   * Remove result by ID
   */
  removeResult(id) {
    const index = this.results.findIndex(result => result.id === id);
    if (index !== -1) {
      this.results.splice(index, 1);
      const element = this.container.querySelector(`[data-result-id="${id}"]`);
      if (element) {
        element.remove();
      }
      
      // Show placeholder if no results
      if (this.results.length === 0) {
        this.showPlaceholder();
      }
    }
  }
}

export default ResultsManager;