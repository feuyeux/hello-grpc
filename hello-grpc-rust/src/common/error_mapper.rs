use log::{error, info, warn};
use std::time::Duration;
use tokio::time::sleep;
use tonic::{Code, Status};

/// Configuration for retry logic
#[derive(Clone, Debug)]
pub struct RetryConfig {
    pub max_retries: u32,
    pub initial_delay: Duration,
    pub max_delay: Duration,
    pub multiplier: f64,
}

impl RetryConfig {
    /// Creates default retry configuration
    pub fn default() -> Self {
        RetryConfig {
            max_retries: 3,
            initial_delay: Duration::from_secs(2),
            max_delay: Duration::from_secs(30),
            multiplier: 2.0,
        }
    }
}

/// Maps gRPC status code to human-readable message
#[inline]
pub fn map_grpc_error(status: &Status) -> String {
    let description = get_status_description(status.code());
    let message = status.message();

    if message.is_empty() {
        description.to_string()
    } else {
        format!("{}: {}", description, message)
    }
}

/// Gets human-readable description for a gRPC status code
#[inline]
fn get_status_description(code: Code) -> &'static str {
    match code {
        Code::Ok => "Success",
        Code::Cancelled => "Operation cancelled",
        Code::Unknown => "Unknown error",
        Code::InvalidArgument => "Invalid request parameters",
        Code::DeadlineExceeded => "Request timeout",
        Code::NotFound => "Resource not found",
        Code::AlreadyExists => "Resource already exists",
        Code::PermissionDenied => "Permission denied",
        Code::ResourceExhausted => "Resource exhausted",
        Code::FailedPrecondition => "Precondition failed",
        Code::Aborted => "Operation aborted",
        Code::OutOfRange => "Out of range",
        Code::Unimplemented => "Not implemented",
        Code::Internal => "Internal server error",
        Code::Unavailable => "Service unavailable",
        Code::DataLoss => "Data loss",
        Code::Unauthenticated => "Authentication required",
    }
}

/// Determines if an error should be retried
#[inline]
pub fn is_retryable_error(status: &Status) -> bool {
    matches!(
        status.code(),
        Code::Unavailable | Code::DeadlineExceeded | Code::ResourceExhausted | Code::Internal
    )
}

/// Handles RPC errors with logging and context
#[inline]
pub fn handle_rpc_error(status: &Status, operation: &str, context: &[(&str, &str)]) {
    let error_msg = map_grpc_error(status);
    let context_str = if context.is_empty() {
        String::new()
    } else {
        let formatted = context
            .iter()
            .map(|(k, v)| format!("{}={}", k, v))
            .collect::<Vec<_>>()
            .join(", ");
        format!(", {}", formatted)
    };

    if is_retryable_error(status) {
        warn!(
            "Retryable error occurred: operation={}, error={}{}",
            operation, error_msg, context_str
        );
    } else {
        error!(
            "Non-retryable error occurred: operation={}, error={}{}",
            operation, error_msg, context_str
        );
    }
}

/// Executes a function with exponential backoff retry logic
pub async fn retry_with_backoff<F, Fut, T>(
    operation: &str,
    mut func: F,
    config: RetryConfig,
) -> Result<T, Status>
where
    F: FnMut() -> Fut,
    Fut: std::future::Future<Output = Result<T, Status>>,
{
    let mut last_error: Option<Status> = None;
    let mut delay = config.initial_delay;

    for attempt in 0..=config.max_retries {
        if attempt > 0 {
            info!(
                "Retry attempt {}/{} for {} after {}ms",
                attempt,
                config.max_retries,
                operation,
                delay.as_millis()
            );

            sleep(delay).await;
        }

        match func().await {
            Ok(result) => {
                if attempt > 0 {
                    info!(
                        "Operation {} succeeded after {} attempts",
                        operation,
                        attempt + 1
                    );
                }
                return Ok(result);
            }
            Err(status) => {
                last_error = Some(status.clone());

                if !is_retryable_error(&status) {
                    warn!(
                        "Non-retryable error for {}: {}",
                        operation,
                        map_grpc_error(&status)
                    );
                    return Err(status);
                }

                if attempt < config.max_retries {
                    // Calculate next delay with exponential backoff
                    delay = Duration::from_millis(
                        (delay.as_millis() as f64 * config.multiplier) as u64,
                    );
                    if delay > config.max_delay {
                        delay = config.max_delay;
                    }
                }
            }
        }
    }

    let final_error = last_error.unwrap();
    error!(
        "Operation {} failed after {} attempts: {}",
        operation,
        config.max_retries + 1,
        map_grpc_error(&final_error)
    );

    Err(Status::aborted(format!(
        "Max retries exceeded for {}",
        operation
    )))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_map_grpc_error() {
        let status = Status::unavailable("service down");
        let msg = map_grpc_error(&status);
        assert!(msg.contains("Service unavailable"));
        assert!(msg.contains("service down"));
    }

    #[test]
    fn test_is_retryable_error() {
        assert!(is_retryable_error(&Status::unavailable("")));
        assert!(is_retryable_error(&Status::deadline_exceeded("")));
        assert!(is_retryable_error(&Status::resource_exhausted("")));
        assert!(is_retryable_error(&Status::internal("")));
        assert!(!is_retryable_error(&Status::invalid_argument("")));
        assert!(!is_retryable_error(&Status::not_found("")));
    }
}
