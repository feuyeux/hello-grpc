use hello_grpc_rust::common::etcd::is_etcd_discovery;

#[test]
fn test_is_etcd_discovery() {
    // Test unset
    unsafe { std::env::remove_var("GRPC_HELLO_DISCOVERY") };
    assert!(!is_etcd_discovery());

    // Test set to "etcd"
    unsafe { std::env::set_var("GRPC_HELLO_DISCOVERY", "etcd") };
    assert!(is_etcd_discovery());

    // Test set to wrong value
    unsafe { std::env::set_var("GRPC_HELLO_DISCOVERY", "consul") };
    assert!(!is_etcd_discovery());

    // Cleanup
    unsafe { std::env::remove_var("GRPC_HELLO_DISCOVERY") };
}
