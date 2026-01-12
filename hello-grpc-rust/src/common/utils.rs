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

#[inline]
pub fn random_id(max: i32) -> String {
    let mut rng = rand::rng(); // Using rand 0.9.x API
    format!("{}", rng.random_range(0..max)) // Using rand 0.9.x API
}

pub fn get_version() -> String {
    use std::fs;
    use std::path::Path;

    // First try to read Cargo.toml directly to get versions
    let cargo_path = Path::new("Cargo.toml");
    let Ok(content) = fs::read_to_string(cargo_path) else {
        // If file reading fails, use hardcoded versions from Cargo.toml
        // These should be updated when dependencies change
        return format!("tonic.version=0.9.2 (prost.version=0.11.9)");
    };

    let tonic_version =
        extract_dependency_version(&content, "tonic").unwrap_or_else(|| "unknown".to_string());
    let prost_version =
        extract_dependency_version(&content, "prost").unwrap_or_else(|| "unknown".to_string());
    format!(
        "tonic.version={} (prost.version={})",
        tonic_version, prost_version
    )
}

#[inline]
fn extract_dependency_version(cargo_content: &str, dependency_name: &str) -> Option<String> {
    // Simple parser to find a dependency version in Cargo.toml using iterator pattern
    cargo_content.lines().find_map(|line| {
        let trimmed = line.trim();
        let dep_pattern = format!("{} =", dependency_name);

        if trimmed.starts_with(&dep_pattern) {
            // Simple case: dependency = "version"
            line.split('"').nth(1).map(|s| s.to_string())
        } else if trimmed.starts_with(&format!("{} {{", dependency_name)) {
            // Complex case with features, scan next lines for version
            extract_version_from_block(cargo_content, line)
        } else {
            None
        }
    })
}

#[inline]
fn extract_version_from_block(cargo_content: &str, start_line: &str) -> Option<String> {
    let block_indent = start_line.len() - start_line.trim_start().len();
    let mut found_start = false;

    cargo_content.lines().find_map(|line| {
        if !found_start {
            if line.contains(start_line) {
                found_start = true;
            }
            return None;
        }

        let trimmed = line.trim();
        let current_indent = line.len() - line.trim_start().len();

        // Check for end of block
        if !line.trim().is_empty() && current_indent <= block_indent {
            return None;
        }

        // Look for version inside the block
        if trimmed.starts_with("version") {
            line.split('"').nth(1).map(|s| s.to_string())
        } else {
            None
        }
    })
}
