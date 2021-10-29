cmake_minimum_required(VERSION 3.5.1)
project(Hello-GRPC-CPP C CXX)
set(CMAKE_CXX_STANDARD 11)
set(CMAKE_PREFIX_PATH ${CMAKE_PREFIX_PATH} "$ENV{HOME}/.local")
include(cmake/common.cmake)

# Proto file
get_filename_component(landing_proto "protos/landing.proto" ABSOLUTE)
get_filename_component(landing_proto_path "${landing_proto}" PATH)

# Generated sources
set(PB_PATH "${CMAKE_CURRENT_SOURCE_DIR}/common")

set(landing_proto_lib "${PB_PATH}/landing.pb.cc" "${PB_PATH}/landing.pb.h")
set(landing_grpc_lib "${PB_PATH}/landing.grpc.pb.cc" "${PB_PATH}/landing.grpc.pb.h")
set(hello_grpc_lib ${PB_PATH}/utils.cpp ${PB_PATH}/utils.h ${PB_PATH}/connection.cpp ${PB_PATH}/connection.h)

add_custom_command(
        OUTPUT "${landing_proto_lib}" "${landing_grpc_lib}"
        COMMAND ${_PROTOBUF_PROTOC}
        ARGS --grpc_out "${PB_PATH}"
        --cpp_out "${PB_PATH}"
        -I "${landing_proto_path}"
        --plugin=protoc-gen-grpc="${_GRPC_CPP_PLUGIN_EXECUTABLE}"
        "${landing_proto}"
        DEPENDS "${landing_proto}")

# Include generated *.pb.h files
include_directories("${PB_PATH}")

# dependencies
#https://github.com/google/glog
#mirror:https://gitee.com/feuyeux/glog
find_package(glog 0.6.0 REQUIRED)

#https://cmake.org/cmake/help/latest/command/add_library.html
#add_library(<name> [STATIC | SHARED | MODULE]
#        [EXCLUDE_FROM_ALL]
#        [<source>...])
add_library(landing_grpc_proto ${landing_proto_lib} ${landing_grpc_lib} ${hello_grpc_lib})
target_link_libraries(landing_grpc_proto ${_REFLECTION} ${_GRPC_GRPCPP} ${_PROTOBUF_LIBPROTOBUF} glog::glog)

# Targets [async_](client|server)
#https://cmake.org/cmake/help/latest/command/add_executable.html
#add_executable(<name> [WIN32] [MACOSX_BUNDLE]
#        [EXCLUDE_FROM_ALL]
#        [source1] [source2 ...])
add_executable(proto_client "client/proto_client.cpp")
add_executable(proto_server "server/proto_server.cpp")

#https://cmake.org/cmake/help/latest/command/target_link_libraries.html
#target_link_libraries(<target> ... <item>... ...)
target_link_libraries(proto_server landing_grpc_proto ${_REFLECTION} ${_GRPC_GRPCPP} ${_PROTOBUF_LIBPROTOBUF})
target_link_libraries(proto_client landing_grpc_proto ${_REFLECTION} ${_GRPC_GRPCPP} ${_PROTOBUF_LIBPROTOBUF})

#https://cmake.org/cmake/help/latest/command/add_definitions.html
#add_definitions(-DFOO -DBAR ...)
add_definitions(-DCMAKE_EXPORT_COMPILE_COMMANDS=ON)