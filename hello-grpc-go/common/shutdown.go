package common

import (
	"context"
	"os"
	"os/signal"
	"syscall"
	"time"

	log "github.com/sirupsen/logrus"
)

const (
	// DefaultShutdownTimeout is the default timeout for graceful shutdown
	DefaultShutdownTimeout = 30 * time.Second
)

// ShutdownHandler manages graceful shutdown of the application
type ShutdownHandler struct {
	timeout       time.Duration
	shutdownFuncs []func() error
	signals       chan os.Signal
	ctx           context.Context
	cancel        context.CancelFunc
}

// NewShutdownHandler creates a new shutdown handler with the specified timeout
func NewShutdownHandler(timeout time.Duration) *ShutdownHandler {
	ctx, cancel := context.WithCancel(context.Background())

	handler := &ShutdownHandler{
		timeout:       timeout,
		shutdownFuncs: make([]func() error, 0),
		signals:       make(chan os.Signal, 1),
		ctx:           ctx,
		cancel:        cancel,
	}

	// Register signal handlers
	signal.Notify(handler.signals, os.Interrupt, syscall.SIGTERM, syscall.SIGINT)

	return handler
}

// RegisterCleanup registers a cleanup function to be called during shutdown
func (h *ShutdownHandler) RegisterCleanup(fn func() error) {
	h.shutdownFuncs = append(h.shutdownFuncs, fn)
}

// Context returns the shutdown context
func (h *ShutdownHandler) Context() context.Context {
	return h.ctx
}

// Wait blocks until a shutdown signal is received
func (h *ShutdownHandler) Wait() {
	sig := <-h.signals
	log.Infof("Received shutdown signal: %v", sig)
	h.cancel()
}

// Shutdown performs graceful shutdown with timeout
func (h *ShutdownHandler) Shutdown() error {
	log.Info("Starting graceful shutdown...")

	// Create a context with timeout for shutdown operations
	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), h.timeout)
	defer shutdownCancel()

	// Channel to signal completion of cleanup
	done := make(chan error, 1)

	go func() {
		var lastErr error
		// Execute all cleanup functions in reverse order (LIFO)
		for i := len(h.shutdownFuncs) - 1; i >= 0; i-- {
			if err := h.shutdownFuncs[i](); err != nil {
				log.Errorf("Error during cleanup: %v", err)
				lastErr = err
			}
		}
		done <- lastErr
	}()

	// Wait for cleanup to complete or timeout
	select {
	case err := <-done:
		if err != nil {
			log.Warn("Shutdown completed with errors")
			return err
		}
		log.Info("Graceful shutdown completed successfully")
		return nil
	case <-shutdownCtx.Done():
		log.Warn("Shutdown timeout exceeded, forcing shutdown")
		return shutdownCtx.Err()
	}
}

// WaitAndShutdown is a convenience method that waits for a signal and then shuts down
func (h *ShutdownHandler) WaitAndShutdown() error {
	h.Wait()
	return h.Shutdown()
}
