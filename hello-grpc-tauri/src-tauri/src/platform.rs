use serde::{Deserialize, Serialize};
use std::fmt;

/// Platform-specific error types and handling
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum PlatformError {
    NetworkUnavailable,
    PermissionDenied,
    SecurityPolicyViolation,
    PlatformSpecific(String),
    ConfigurationError(String),
}

impl fmt::Display for PlatformError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            PlatformError::NetworkUnavailable => write!(f, "Network is not available"),
            PlatformError::PermissionDenied => write!(f, "Network permission denied"),
            PlatformError::SecurityPolicyViolation => write!(f, "Security policy violation"),
            PlatformError::PlatformSpecific(msg) => write!(f, "Platform error: {}", msg),
            PlatformError::ConfigurationError(msg) => write!(f, "Configuration error: {}", msg),
        }
    }
}

impl std::error::Error for PlatformError {}

/// Platform-specific configuration and utilities
pub struct PlatformManager;

impl PlatformManager {
    /// Get the current platform information
    pub fn get_platform_info() -> PlatformInfo {
        PlatformInfo {
            platform: get_current_platform(),
            version: get_platform_version(),
            supports_cleartext: supports_cleartext_traffic(),
            network_available: is_network_available(),
        }
    }
    
    /// Check if the current platform supports the requested network configuration
    pub fn validate_network_config(use_tls: bool, server: &str) -> Result<(), PlatformError> {
        let platform_info = Self::get_platform_info();
        
        // Check if cleartext traffic is allowed
        if !use_tls && !platform_info.supports_cleartext {
            return Err(PlatformError::SecurityPolicyViolation);
        }
        
        // Check network availability
        if !platform_info.network_available {
            return Err(PlatformError::NetworkUnavailable);
        }
        
        // Platform-specific validations
        match platform_info.platform {
            Platform::Android => validate_android_config(use_tls, server),
            Platform::Ios => validate_ios_config(use_tls, server),
            Platform::Desktop => Ok(()), // Desktop platforms are more permissive
        }
    }
    
    /// Get platform-specific error message for user display
    pub fn get_user_friendly_error(error: &PlatformError) -> String {
        match error {
            PlatformError::NetworkUnavailable => {
                "No network connection available. Please check your internet connection.".to_string()
            }
            PlatformError::PermissionDenied => {
                "Network permission denied. Please check app permissions in settings.".to_string()
            }
            PlatformError::SecurityPolicyViolation => {
                match get_current_platform() {
                    Platform::Android => {
                        "HTTP connections are not allowed. Please use HTTPS or configure network security policy.".to_string()
                    }
                    Platform::Ios => {
                        "HTTP connections are blocked by App Transport Security. Please use HTTPS or configure ATS exceptions.".to_string()
                    }
                    Platform::Desktop => {
                        "Insecure connections are not allowed by security policy.".to_string()
                    }
                }
            }
            PlatformError::PlatformSpecific(msg) => msg.clone(),
            PlatformError::ConfigurationError(msg) => format!("Configuration error: {}", msg),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PlatformInfo {
    pub platform: Platform,
    pub version: String,
    pub supports_cleartext: bool,
    pub network_available: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum Platform {
    Android,
    Ios,
    Desktop,
}

/// Get the current platform
fn get_current_platform() -> Platform {
    #[cfg(target_os = "android")]
    return Platform::Android;
    
    #[cfg(target_os = "ios")]
    return Platform::Ios;
    
    #[cfg(not(any(target_os = "android", target_os = "ios")))]
    return Platform::Desktop;
}

/// Get platform version information
fn get_platform_version() -> String {
    #[cfg(target_os = "android")]
    {
        // On Android, we could use JNI to get the actual Android version
        // For now, return a placeholder
        "Android".to_string()
    }
    
    #[cfg(target_os = "ios")]
    {
        // On iOS, we could use system APIs to get the iOS version
        // For now, return a placeholder
        "iOS".to_string()
    }
    
    #[cfg(not(any(target_os = "android", target_os = "ios")))]
    {
        std::env::consts::OS.to_string()
    }
}

/// Check if the platform supports cleartext traffic
fn supports_cleartext_traffic() -> bool {
    #[cfg(target_os = "android")]
    {
        // On Android, this depends on the network security config
        // For development, we've configured it to allow cleartext
        true
    }
    
    #[cfg(target_os = "ios")]
    {
        // On iOS, this depends on App Transport Security settings
        // For development, we've configured ATS exceptions
        true
    }
    
    #[cfg(not(any(target_os = "android", target_os = "ios")))]
    {
        // Desktop platforms typically allow cleartext traffic
        true
    }
}

/// Check if network is available
fn is_network_available() -> bool {
    // This is a simplified check - in a real app, you might want to
    // use platform-specific APIs to check network connectivity
    true
}

/// Android-specific configuration validation
#[cfg(target_os = "android")]
fn validate_android_config(use_tls: bool, server: &str) -> Result<(), PlatformError> {
    // Check if server is localhost or local network for cleartext
    if !use_tls {
        let is_local = server == "localhost" 
            || server == "127.0.0.1" 
            || server == "10.0.2.2" // Android emulator host
            || server.starts_with("192.168.") 
            || server.starts_with("10.0.");
            
        if !is_local {
            return Err(PlatformError::SecurityPolicyViolation);
        }
    }
    
    Ok(())
}

#[cfg(not(target_os = "android"))]
fn validate_android_config(_use_tls: bool, _server: &str) -> Result<(), PlatformError> {
    Ok(())
}

/// iOS-specific configuration validation
#[cfg(target_os = "ios")]
fn validate_ios_config(use_tls: bool, server: &str) -> Result<(), PlatformError> {
    // Check if server is in ATS exception list for cleartext
    if !use_tls {
        let is_exception = server == "localhost" || server == "127.0.0.1";
        
        if !is_exception {
            return Err(PlatformError::SecurityPolicyViolation);
        }
    }
    
    Ok(())
}

#[cfg(not(target_os = "ios"))]
fn validate_ios_config(_use_tls: bool, _server: &str) -> Result<(), PlatformError> {
    Ok(())
}

/// Platform-specific network configuration helper
pub fn get_recommended_settings() -> Vec<(String, String)> {
    let mut recommendations = Vec::new();
    
    match get_current_platform() {
        Platform::Android => {
            recommendations.push((
                "Server".to_string(),
                "Use 10.0.2.2 for Android emulator or your local IP for device".to_string(),
            ));
            recommendations.push((
                "Security".to_string(),
                "HTTP is allowed for localhost and local networks only".to_string(),
            ));
        }
        Platform::Ios => {
            recommendations.push((
                "Server".to_string(),
                "Use localhost or 127.0.0.1 for simulator".to_string(),
            ));
            recommendations.push((
                "Security".to_string(),
                "HTTP is allowed for localhost only due to ATS".to_string(),
            ));
        }
        Platform::Desktop => {
            recommendations.push((
                "Server".to_string(),
                "Any server address is supported".to_string(),
            ));
            recommendations.push((
                "Security".to_string(),
                "Both HTTP and HTTPS are supported".to_string(),
            ));
        }
    }
    
    recommendations
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_platform_info() {
        let info = PlatformManager::get_platform_info();
        assert!(!info.version.is_empty());
    }

    #[test]
    fn test_network_validation() {
        // Test localhost with HTTP - should be allowed
        let result = PlatformManager::validate_network_config(false, "localhost");
        assert!(result.is_ok());
        
        // Test localhost with HTTPS - should be allowed
        let result = PlatformManager::validate_network_config(true, "localhost");
        assert!(result.is_ok());
    }

    #[test]
    fn test_user_friendly_errors() {
        let error = PlatformError::NetworkUnavailable;
        let message = PlatformManager::get_user_friendly_error(&error);
        assert!(message.contains("network"));
    }
}