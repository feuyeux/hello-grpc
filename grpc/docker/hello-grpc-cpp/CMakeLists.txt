cmake_minimum_required(VERSION 3.5.1)
project(Hello-GRPC-CPP C CXX)
set(CMAKE_PREFIX_PATH ${CMAKE_PREFIX_PATH} "$ENV{HOME}/.local")
include(cmake/common.cmake)

# Proto file
get_filename_component(hello_proto "protos/helloworld.proto" ABSOLUTE)
get_filename_component(landing_proto "protos/landing.proto" ABSOLUTE)
get_filename_component(hello_proto_path "${hello_proto}" PATH)
get_filename_component(landing_proto_path "${landing_proto}" PATH)

# Generated sources
set(PB_PATH "${CMAKE_CURRENT_SOURCE_DIR}/common")

set(hello_proto_srcs "${PB_PATH}/helloworld.pb.cc")
set(hello_proto_hdrs "${PB_PATH}/helloworld.pb.h")
set(hello_grpc_srcs "${PB_PATH}/helloworld.grpc.pb.cc")
set(hello_grpc_hdrs "${PB_PATH}/helloworld.grpc.pb.h")
set(landing_proto_srcs "${PB_PATH}/landing.pb.cc")
set(landing_proto_hdrs "${PB_PATH}/landing.pb.h")
set(landing_grpc_srcs "${PB_PATH}/landing.grpc.pb.cc")
set(landing_grpc_hdrs "${PB_PATH}/landing.grpc.pb.h")
set(landing_grpc_utils_head "${CMAKE_CURRENT_SOURCE_DIR}/client/utils.h")
set(landing_grpc_utils_src "${CMAKE_CURRENT_SOURCE_DIR}/client/utils.cpp")

add_custom_command(
        OUTPUT "${hello_proto_srcs}" "${hello_proto_hdrs}" "${hello_grpc_srcs}" "${hello_grpc_hdrs}"
        COMMAND ${_PROTOBUF_PROTOC}
        ARGS --grpc_out "${PB_PATH}"
        --cpp_out "${PB_PATH}"
        -I "${hello_proto_path}"
        --plugin=protoc-gen-grpc="${_GRPC_CPP_PLUGIN_EXECUTABLE}"
        "${hello_proto}"
        DEPENDS "${hello_proto}")

add_custom_command(
        OUTPUT "${landing_proto_srcs}" "${landing_proto_hdrs}" "${landing_grpc_srcs}" "${landing_grpc_hdrs}"
        COMMAND ${_PROTOBUF_PROTOC}
        ARGS --grpc_out "${PB_PATH}"
        --cpp_out "${PB_PATH}"
        -I "${landing_proto_path}"
        --plugin=protoc-gen-grpc="${_GRPC_CPP_PLUGIN_EXECUTABLE}"
        "${landing_proto}"
        DEPENDS "${landing_proto}")

# Include generated *.pb.h files
include_directories("${PB_PATH}")
# hello_grpc_proto
add_library(hello_grpc_proto ${hello_grpc_srcs} ${hello_grpc_hdrs} ${hello_proto_srcs} ${hello_proto_hdrs})
add_library(landing_grpc_proto ${landing_grpc_srcs} ${landing_grpc_hdrs} ${landing_proto_srcs} ${landing_proto_hdrs} ${landing_grpc_utils_src}  ${landing_grpc_utils_head})
target_link_libraries(hello_grpc_proto ${_REFLECTION} ${_GRPC_GRPCPP} ${_PROTOBUF_LIBPROTOBUF})
target_link_libraries(landing_grpc_proto ${_REFLECTION} ${_GRPC_GRPCPP} ${_PROTOBUF_LIBPROTOBUF})

# Targets [async_](client|server)
#https://cmake.org/cmake/help/latest/command/add_executable.html
add_executable(proto_client "client/proto_client.cpp")
add_executable(greeter_async_client "client/greeter_async_client.cc")
add_executable(greeter_async_client2 "client/greeter_async_client2.cc")
add_executable(proto_server "server/proto_server.cpp")
add_executable(greeter_async_server "server/greeter_async_server.cc")

# dependencies
find_package (glog 0.6.0 REQUIRED)

#https://cmake.org/cmake/help/latest/command/target_link_libraries.html
target_link_libraries(proto_server hello_grpc_proto landing_grpc_proto ${_REFLECTION} ${_GRPC_GRPCPP} ${_PROTOBUF_LIBPROTOBUF} glog::glog)
target_link_libraries(proto_client hello_grpc_proto landing_grpc_proto ${_REFLECTION} ${_GRPC_GRPCPP} ${_PROTOBUF_LIBPROTOBUF} glog::glog)
target_link_libraries(greeter_async_client hello_grpc_proto ${_REFLECTION} ${_GRPC_GRPCPP} ${_PROTOBUF_LIBPROTOBUF} glog::glog)
target_link_libraries(greeter_async_client2 hello_grpc_proto ${_REFLECTION} ${_GRPC_GRPCPP} ${_PROTOBUF_LIBPROTOBUF} glog::glog)
target_link_libraries(greeter_async_server hello_grpc_proto ${_REFLECTION} ${_GRPC_GRPCPP} ${_PROTOBUF_LIBPROTOBUF} glog::glog)