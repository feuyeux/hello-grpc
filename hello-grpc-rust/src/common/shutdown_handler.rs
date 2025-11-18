use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::time::Duration;
use tokio::signal;
use tokio::sync::Mutex;
use tokio::time::timeout;
use log::{error, info, warn};

const DEFAULT_SHUTDOWN_TIMEOUT: Duration = Duration::from_secs(30);

type CleanupFunction = Box<dyn Fn() -> Result<(), Box<dyn std::error::Error + Send + Sync>> + Send + Sync>;

/// Manages graceful shutdown of the application
pub struct ShutdownHandler {
    timeout: Duration,
    cleanup_functions: Arc<Mutex<Vec<CleanupFunction>>>,
    shutdown_initiated: Arc<AtomicBool>,
}

impl ShutdownHandler {
    /// Creates a new shutdown handler with the specified timeout
    pub fn new(timeout: Duration) -> Self {
        ShutdownHandler {
            timeout,
            cleanup_functions: Arc::new(Mutex::new(Vec::new())),
            shutdown_initiated: Arc::new(AtomicBool::new(false)),
        }
    }

    /// Creates a new shutdown handler with default timeout
    pub fn default() -> Self {
        Self::new(DEFAULT_SHUTDOWN_TIMEOUT)
    }

    /// Registers a cleanup function to be called during shutdown
    pub async fn register_cleanup<F>(&self, cleanup_fn: F)
    where
        F: Fn() -> Result<(), Box<dyn std::error::Error + Send + Sync>> + Send + Sync + 'static,
    {
        let mut functions = self.cleanup_functions.lock().await;
        functions.push(Box::new(cleanup_fn));
    }

    /// Initiates the shutdown process
    pub fn initiate_shutdown(&self) {
        if !self.shutdown_initiated.swap(true, Ordering::SeqCst) {
            info!("Shutdown initiated");
        }
    }

    /// Checks if shutdown has been initiated
    pub fn is_shutdown_initiated(&self) -> bool {
        self.shutdown_initiated.load(Ordering::SeqCst)
    }

    /// Waits for a shutdown signal (SIGINT or SIGTERM)
    pub async fn wait(&self) {
        let shutdown_initiated = self.shutdown_initiated.clone();
        
        tokio::select! {
            _ = signal::ctrl_c() => {
                info!("Received SIGINT signal (Ctrl+C)");
                shutdown_initiated.store(true, Ordering::SeqCst);
            }
            _ = Self::wait_for_sigterm() => {
                info!("Received SIGTERM signal");
                shutdown_initiated.store(true, Ordering::SeqCst);
            }
        }
    }

    /// Waits for SIGTERM signal (Unix only)
    #[cfg(unix)]
    async fn wait_for_sigterm() {
        use tokio::signal::unix::{signal, SignalKind};
        
        let mut sigterm = signal(SignalKind::terminate())
            .expect("Failed to register SIGTERM handler");
        sigterm.recv().await;
    }

    /// Waits for SIGTERM signal (Windows - not supported, waits forever)
    #[cfg(not(unix))]
    async fn wait_for_sigterm() {
        // SIGTERM is not available on Windows, so we wait forever
        std::future::pending::<()>().await;
    }

    /// Performs graceful shutdown with timeout
    pub async fn shutdown(&self) -> bool {
        info!("Starting graceful shutdown...");

        let shutdown_future = async {
            let mut has_errors = false;
            
            // Execute cleanup functions in reverse order (LIFO)
            let functions = self.cleanup_functions.lock().await;
            for cleanup_fn in functions.iter().rev() {
                if let Err(e) = cleanup_fn() {
                    error!("Error during cleanup: {}", e);
                    has_errors = true;
                }
            }
            
            has_errors
        };

        match timeout(self.timeout, shutdown_future).await {
            Ok(has_errors) => {
                if has_errors {
                    warn!("Shutdown completed with errors");
                    false
                } else {
                    info!("Graceful shutdown completed successfully");
                    true
                }
            }
            Err(_) => {
                warn!("Shutdown timeout exceeded, forcing shutdown");
                false
            }
        }
    }

    /// Waits for a shutdown signal and then performs shutdown
    pub async fn wait_and_shutdown(&self) -> bool {
        self.wait().await;
        self.shutdown().await
    }
}

impl Clone for ShutdownHandler {
    fn clone(&self) -> Self {
        ShutdownHandler {
            timeout: self.timeout,
            cleanup_functions: Arc::clone(&self.cleanup_functions),
            shutdown_initiated: Arc::clone(&self.shutdown_initiated),
        }
    }
}
