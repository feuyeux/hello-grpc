use rand::Rng;

pub static HELLOS: [&'static str; 6] = [
    "Hello",
    "Bonjour",
    "Hola",
    "こんにちは",
    "Ciao",
    "안녕하세요",
];


pub fn random_id(max: i32) -> String {
    let mut rng = rand::thread_rng();
    let r = rng.gen_range(0..max);
    let s = format!("{}", r);
    s
}