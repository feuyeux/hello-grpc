fn main() -> Result<(), Box<dyn std::error::Error>> {
    tonic_build::compile_protos("proto/landing.proto")?;

    /*tonic_build::configure()
        .type_attribute("routeguide.Point", "#[derive(Hash)]")
        .compile(&["proto/route_guide.proto"], &["proto"])
        .unwrap();*/
    Ok(())
}
