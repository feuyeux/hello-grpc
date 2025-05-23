use std::collections::LinkedList;
use std::{collections::HashMap, sync::Mutex};

use rand::Rng;

// use futures::future::Lazy;
use once_cell::sync::Lazy;

use crate::common::landing::TalkRequest;

pub static HELLOS: [&'static str; 6] = [
    "Hello",
    "Bonjour",
    "Hola",
    "こんにちは",
    "Ciao",
    "안녕하세요",
];

static ANS_MAP: Lazy<Mutex<HashMap<&str, &str>>> = Lazy::new(|| {
    let mut m = HashMap::new();
    m.insert("你好", "非常感谢");
    m.insert("Hello", "Thank you very much");
    m.insert("Bonjour", "Merci beaucoup");
    m.insert("Hola", "Muchas Gracias");
    m.insert("こんにちは", "どうも ありがとう ございます");
    m.insert("Ciao", "Mille Grazie");
    m.insert("안녕하세요", "대단히 감사합니다");
    Mutex::new(m)
});

pub fn build_link_requests() -> LinkedList<TalkRequest> {
    let mut requests = LinkedList::new();
    for _ in 0..3 {
        let request = TalkRequest {
            data: random_id(5),
            meta: "RUST".to_string(),
        };
        requests.push_front(request);
    }
    requests
}

pub fn thanks(key: &str) -> &str {
    ANS_MAP.lock().unwrap().get(key).unwrap()
}

pub fn random_id(max: i32) -> String {
    let mut rng = rand::thread_rng(); // Using the latest rand crate
    let random_value = rng.gen_range(0..max); // Using the range syntax supported in rand 0.8.5
    let id_string = format!("{}", random_value);
    id_string
}

pub fn get_version() -> String {
    use std::fs;
    use std::path::Path;
    
    // First try to read Cargo.toml directly to get versions
    let cargo_path = Path::new("Cargo.toml");
    if cargo_path.exists() {
        if let Ok(content) = fs::read_to_string(cargo_path) {
            let tonic_version = extract_dependency_version(&content, "tonic").unwrap_or_else(|| "unknown".to_string());
            let prost_version = extract_dependency_version(&content, "prost").unwrap_or_else(|| "unknown".to_string());
            return format!("tonic.version={} (prost.version={})", tonic_version, prost_version);
        }
    }
    
    // If file reading fails, use hardcoded versions from Cargo.toml
    // These should be updated when dependencies change
    format!("tonic.version=0.9.2 (prost.version=0.11.9)")
}

fn extract_dependency_version(cargo_content: &str, dependency_name: &str) -> Option<String> {
    // Simple parser to find a dependency version in Cargo.toml
    for line in cargo_content.lines() {
        let line = line.trim();
        // Match patterns like: tonic = "0.9.2" or tonic = { version = "0.9.2", features = [...] }
        if line.starts_with(&format!("{} =", dependency_name)) {
            // Simple case: dependency = "version"
            if let Some(version) = line.split('"').nth(1) {
                return Some(version.to_string());
            }
        } else if line.starts_with(&format!("{} {{", dependency_name)) || 
                  line.starts_with(&format!("{}{{", dependency_name)) {
            // Complex case with features, scan next lines for version
            return extract_version_from_block(cargo_content, line);
        } 
    }
    None
}

fn extract_version_from_block(cargo_content: &str, start_line: &str) -> Option<String> {
    let mut in_block = false;
    let mut block_indent = 0;
    
    for line in cargo_content.lines() {
        let trimmed = line.trim();
        // Check if this line contains the starting line
        if line.contains(start_line) {
            in_block = true;
            block_indent = line.len() - line.trim_start().len();
            continue;
        }
        
        if in_block {
            // Look for version inside the block
            if trimmed.starts_with("version") {
                if let Some(version) = line.split('"').nth(1) {
                    return Some(version.to_string());
                }
            }
            
            // Check for end of block
            let current_indent = line.len() - line.trim_start().len();
            if !line.trim().is_empty() && current_indent <= block_indent {
                break;
            }
        }
    }
    None
}

#[cfg(test)]
mod tests {
    use super::*; // Imports items from the outer module (utils)
    use crate::common::landing::TalkRequest; // Assuming TalkRequest is needed and accessible here

    #[test]
    fn test_random_id_format_and_range() {
        let max_val = 100;
        let id_str = random_id(max_val);
        
        // Check if it's a string (Rust's type system handles this implicitly)
        // Try to parse as integer
        match id_str.parse::<i32>() {
            Ok(id_int) => {
                assert!(id_int >= 0 && id_int < max_val, 
                        "random_id {} out of range [0, {})", id_int, max_val);
            }
            Err(_) => {
                panic!("random_id did not return a parsable integer string: {}", id_str);
            }
        }

        // Test with zero max value if your function is expected to handle it.
        // random_id(0) would panic due to rng.gen_range(0..0) being empty.
        // Depending on desired behavior, this might need adjustment in random_id or specific error handling.
        // For now, we assume max_val > 0.
        let max_val_one = 1;
        let id_str_one = random_id(max_val_one);
        match id_str_one.parse::<i32>() {
            Ok(id_int_one) => {
                 assert!(id_int_one == 0,
                         "random_id {} with max 1 should be 0, was {}", id_int_one, id_str_one);
            }
            Err(_) => {
                panic!("random_id did not return a parsable integer string for max_val_one: {}", id_str_one);
            }
        }
    }

    #[test]
    fn test_thanks() {
        assert_eq!(thanks("Hello"), "Thank you very much");
        assert_eq!(thanks("Bonjour"), "Merci beaucoup");
        // Add more cases if desired
    }

    #[test]
    #[should_panic]
    fn test_thanks_panic_on_unknown_key() {
        // This tests if thanks() panics when an unknown key is provided,
        // which it will due to .unwrap() on a None Option from HashMap.get().
        thanks("UnknownGreeting");
    }

    #[test]
    fn test_build_link_requests() {
        let requests_list = build_link_requests();
        assert_eq!(requests_list.len(), 3, "Should build 3 requests");

        for (i, request) in requests_list.iter().enumerate() {
            assert_eq!(request.meta, "RUST", "Request meta should be RUST");
            // Validate data format if possible (e.g., parsable as int within a range)
            // random_id(5) is used, so data should be "0", "1", "2", "3", or "4".
            match request.data.parse::<i32>() {
                Ok(data_int) => {
                    assert!(data_int >= 0 && data_int < 5, 
                            "Request data {} out of range [0, 5) at index {}", data_int, i);
                }
                Err(_) => {
                    panic!("Request data was not a parsable i32: {} at index {}", request.data, i);
                }
            }
        }
    }
}
