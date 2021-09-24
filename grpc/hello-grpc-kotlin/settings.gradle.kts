rootProject.name = "hello-grpc-kotlin"
include("protos", "stub", "client", "server")

pluginManagement {
    repositories {
        gradlePluginPortal()
        google()
    }
}
