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
    let mut rng = rand::thread_rng();
    let r = rng.gen_range(0..max);
    let s = format!("{}", r);
    s
}
