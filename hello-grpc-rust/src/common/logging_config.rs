use std::env;
use std::fs;
use std::path::Path;
use chrono::Local;
use tracing::Level;
use tracing_subscriber::{
    fmt::{self, format::FmtSpan},
    layer::SubscriberExt,
    util::SubscriberInitExt,
    EnvFilter, Layer,
};

/// Logging configuration for standardized logging setup.
///
/// Provides utilities to initialize logging with standard format:
/// [TIMESTAMP] [LEVEL] [COMPONENT] MESSAGE [CONTEXT]
///
/// Uses tracing with dual output (console and file).
pub struct LoggingConfig {
    pub component: String,
    pub log_dir: String,
    pub level: Level,
}

impl LoggingConfig {
    /// Create a new logging configuration with defaults
    pub fn new(component: &str) -> Self {
        Self {
            component: component.to_string(),
            log_dir: "logs".to_string(),
            level: Self::get_log_level(),
        }
    }

    /// Create a new logging configuration with custom log directory
    pub fn with_log_dir(component: &str, log_dir: &str) -> Self {
        Self {
            component: component.to_string(),
            log_dir: log_dir.to_string(),
            level: Self::get_log_level(),
        }
    }

    /// Initialize logging with dual output (console and file)
    pub fn initialize(&self) -> Result<(), Box<dyn std::error::Error>> {
        // Create log directory
        fs::create_dir_all(&self.log_dir)?;

        // Create log file with timestamp
        let timestamp = Local::now().format("%Y%m%d_%H%M%S");
        let log_file_name = format!("{}_{}.log", self.component, timestamp);
        let log_file_path = Path::new(&self.log_dir).join(&log_file_name);

        // Create file appender
        let file = fs::OpenOptions::new()
            .create(true)
            .append(true)
            .open(&log_file_path)?;

        // Configure console layer
        let console_layer = fmt::layer()
            .with_target(false)
            .with_thread_ids(false)
            .with_thread_names(false)
            .with_span_events(FmtSpan::NONE)
            .with_writer(std::io::stdout)
            .with_filter(Self::create_env_filter());

        // Configure file layer
        let file_layer = fmt::layer()
            .with_target(false)
            .with_thread_ids(false)
            .with_thread_names(false)
            .with_span_events(FmtSpan::NONE)
            .with_writer(file)
            .with_ansi(false)
            .with_filter(Self::create_env_filter());

        // Initialize subscriber with both layers
        tracing_subscriber::registry()
            .with(console_layer)
            .with(file_layer)
            .init();

        tracing::info!(
            component = %self.component,
            log_file = %log_file_path.display(),
            "Logging initialized"
        );

        Ok(())
    }

    /// Get log level from environment variable or default to INFO
    fn get_log_level() -> Level {
        match env::var("LOG_LEVEL")
            .unwrap_or_else(|_| "INFO".to_string())
            .to_uppercase()
            .as_str()
        {
            "TRACE" => Level::TRACE,
            "DEBUG" => Level::DEBUG,
            "INFO" => Level::INFO,
            "WARN" | "WARNING" => Level::WARN,
            "ERROR" => Level::ERROR,
            _ => Level::INFO,
        }
    }

    /// Create environment filter for log level
    fn create_env_filter() -> EnvFilter {
        let level = Self::get_log_level();
        let level_str = match level {
            Level::TRACE => "trace",
            Level::DEBUG => "debug",
            Level::INFO => "info",
            Level::WARN => "warn",
            Level::ERROR => "error",
        };

        EnvFilter::try_from_default_env()
            .unwrap_or_else(|_| EnvFilter::new(level_str))
            // Reduce noise from dependencies
            .add_directive("h2=warn".parse().unwrap())
            .add_directive("tower=warn".parse().unwrap())
            .add_directive("hyper=warn".parse().unwrap())
    }
}

/// Initialize logging with default configuration
pub fn initialize_logging(component: &str) -> Result<(), Box<dyn std::error::Error>> {
    LoggingConfig::new(component).initialize()
}

/// Initialize logging with custom log directory
pub fn initialize_logging_with_dir(
    component: &str,
    log_dir: &str,
) -> Result<(), Box<dyn std::error::Error>> {
    LoggingConfig::with_log_dir(component, log_dir).initialize()
}
