

licenses(["none"])

package(default_visibility = ["//visibility:public"])

cc_library(
    name = "hello_utils",
    srcs = ["common/utils.cpp"],
    hdrs = ["common/utils.h"],
    deps = [
        "//protos:hello_cc_grpc",
        "@com_github_google_glog//:glog",
        "@com_google_absl//absl/strings",
        "@com_google_absl//absl/random",
        "@com_google_absl//absl/random:distributions",
    ],
)

cc_library(
    name = "hello_conn",
    srcs = ["common/connection.cpp"],
    hdrs = ["common/connection.h"],
    deps = [
        "//protos:hello_cc_grpc",
        ":hello_utils",
        "@com_github_google_glog//:glog",
        "@com_google_absl//absl/strings",
        "@com_google_absl//absl/random",
    ],
)

cc_binary(
    name = "hello_server",
    srcs = ["server/proto_server.cpp"],
    defines = ["BAZEL_BUILD"],
    deps = [
        ":hello_conn",
        ":hello_utils",
        "//protos:hello_cc_grpc",
        "@com_github_grpc_grpc//:grpc++",
        "@com_github_grpc_grpc//:grpc++_reflection",
        "@catch2",
    ],
)

cc_binary(
    name = "hello_client",
    srcs = ["client/proto_client.cpp"],
    defines = ["BAZEL_BUILD"],
    deps = [
        ":hello_conn",
        ":hello_utils",
        "//protos:hello_cc_grpc",
        "@com_github_grpc_grpc//:grpc++",
        "@com_github_grpc_grpc//:grpc++_reflection",
        "@catch2",
    ],
)