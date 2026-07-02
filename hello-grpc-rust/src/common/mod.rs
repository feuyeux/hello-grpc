pub mod landing {
    tonic::include_proto!("hello");
}

pub const FILE_DESCRIPTOR_SET: &[u8] =
    tonic::include_file_descriptor_set!("descriptor");

pub mod conn;
pub mod error_mapper;
pub mod logging_config;
pub mod shutdown_handler;
pub mod trans;
pub mod utils;
