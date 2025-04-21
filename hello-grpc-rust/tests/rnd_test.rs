use rand::Rng;

#[test]
fn test_rnd() {
    let r = rand::thread_rng().gen_range(0..10);
    println!("{}", r)
}
