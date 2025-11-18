package common

import (
	"context"
	"fmt"
	"time"

	log "github.com/sirupsen/logrus"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

// RetryConfig holds configuration for retry logic
type RetryConfig struct {
	MaxRetries   int
	InitialDelay time.Duration
	MaxDelay     time.Duration
	Multiplier   float64
}

// DefaultRetryConfig returns the default retry configuration
func DefaultRetryConfig() RetryConfig {
	return RetryConfig{
		MaxRetries:   3,
		InitialDelay: 2 * time.Second,
		MaxDelay:     30 * time.Second,
		Multiplier:   2.0,
	}
}

// MapGRPCError translates gRPC status codes to human-readable messages
func MapGRPCError(err error) string {
	if err == nil {
		return "Success"
	}

	st, ok := status.FromError(err)
	if !ok {
		return fmt.Sprintf("Unknown error: %v", err)
	}

	code := st.Code()
	message := st.Message()

	var description string
	switch code {
	case codes.OK:
		description = "Success"
	case codes.Canceled:
		description = "Operation cancelled"
	case codes.Unknown:
		description = "Unknown error"
	case codes.InvalidArgument:
		description = "Invalid request parameters"
	case codes.DeadlineExceeded:
		description = "Request timeout"
	case codes.NotFound:
		description = "Resource not found"
	case codes.AlreadyExists:
		description = "Resource already exists"
	case codes.PermissionDenied:
		description = "Permission denied"
	case codes.ResourceExhausted:
		description = "Resource exhausted"
	case codes.FailedPrecondition:
		description = "Precondition failed"
	case codes.Aborted:
		description = "Operation aborted"
	case codes.OutOfRange:
		description = "Out of range"
	case codes.Unimplemented:
		description = "Not implemented"
	case codes.Internal:
		description = "Internal server error"
	case codes.Unavailable:
		description = "Service unavailable"
	case codes.DataLoss:
		description = "Data loss"
	case codes.Unauthenticated:
		description = "Authentication required"
	default:
		description = "Unknown error code"
	}

	if message != "" {
		return fmt.Sprintf("%s: %s", description, message)
	}
	return description
}

// IsRetryableError determines if an error should be retried
func IsRetryableError(err error) bool {
	if err == nil {
		return false
	}

	st, ok := status.FromError(err)
	if !ok {
		return false
	}

	code := st.Code()
	switch code {
	case codes.Unavailable, codes.DeadlineExceeded, codes.ResourceExhausted, codes.Internal:
		return true
	default:
		return false
	}
}

// HandleRPCError logs and handles RPC errors with context
func HandleRPCError(err error, operation string, context map[string]interface{}) error {
	if err == nil {
		return nil
	}

	errorMsg := MapGRPCError(err)

	fields := log.Fields{
		"operation": operation,
		"error":     errorMsg,
	}

	for k, v := range context {
		fields[k] = v
	}

	if IsRetryableError(err) {
		log.WithFields(fields).Warn("Retryable error occurred")
	} else {
		log.WithFields(fields).Error("Non-retryable error occurred")
	}

	return err
}

// RetryWithBackoff executes a function with exponential backoff retry logic
func RetryWithBackoff(ctx context.Context, operation string, fn func() error, config RetryConfig) error {
	var lastErr error
	delay := config.InitialDelay

	for attempt := 0; attempt <= config.MaxRetries; attempt++ {
		if attempt > 0 {
			log.Infof("Retry attempt %d/%d for %s after %v", attempt, config.MaxRetries, operation, delay)

			select {
			case <-ctx.Done():
				return fmt.Errorf("operation cancelled: %w", ctx.Err())
			case <-time.After(delay):
				// Continue with retry
			}
		}

		lastErr = fn()
		if lastErr == nil {
			if attempt > 0 {
				log.Infof("Operation %s succeeded after %d attempts", operation, attempt+1)
			}
			return nil
		}

		if !IsRetryableError(lastErr) {
			log.Warnf("Non-retryable error for %s: %v", operation, MapGRPCError(lastErr))
			return lastErr
		}

		if attempt < config.MaxRetries {
			// Calculate next delay with exponential backoff
			delay = time.Duration(float64(delay) * config.Multiplier)
			if delay > config.MaxDelay {
				delay = config.MaxDelay
			}
		}
	}

	log.Errorf("Operation %s failed after %d attempts: %v", operation, config.MaxRetries+1, MapGRPCError(lastErr))
	return fmt.Errorf("max retries exceeded for %s: %w", operation, lastErr)
}

// LogError logs an error with request ID and operation context
func LogError(err error, requestID string, operation string) {
	if err == nil {
		return
	}

	errorMsg := MapGRPCError(err)
	log.WithFields(log.Fields{
		"request_id": requestID,
		"operation":  operation,
		"error":      errorMsg,
	}).Error("RPC error occurred")
}

// ToGrpcError converts an error to a gRPC status error with request ID
func ToGrpcError(err error, requestID string) error {
	if err == nil {
		return nil
	}

	// If it's already a gRPC status error, return it
	if _, ok := status.FromError(err); ok {
		return err
	}

	// Convert to gRPC error with request ID in metadata
	return status.Errorf(codes.Internal, "request_id=%s: %v", requestID, err)
}
