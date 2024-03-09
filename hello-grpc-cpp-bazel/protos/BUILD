load("@rules_proto//proto:defs.bzl", "proto_library")
load("@rules_cc//cc:defs.bzl", "cc_binary", "cc_proto_library")
load("@com_github_grpc_grpc//bazel:cc_grpc_library.bzl", "cc_grpc_library")

licenses(["none"])

package(default_visibility = ["//visibility:public"])

proto_library(
    name = "hello_proto",
    srcs = ["landing.proto"],
)

cc_proto_library(
    name = "hello_cc_proto",
    deps = [":hello_proto"],
)

cc_grpc_library(
    name = "hello_cc_grpc",
    srcs = [":hello_proto"],
    grpc_only = True,
    deps = [":hello_cc_proto"],
)