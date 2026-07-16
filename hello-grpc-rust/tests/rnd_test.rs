use rand::Rng;

#[test]
fn test_rnd() {
    let r = rand::rng().random_range(0..10);
    println!("{}", r)
}
