rootProject.name = "hello-grpc-kotlin"

// when running the assemble task, ignore the android & graalvm related subprojects
if (startParameter.taskRequests.find { it.args.contains("assemble") } == null) {
    include("protos", "stub", "client", "server")
} else {
    include("protos", "stub", "server")
}

pluginManagement {
    repositories {
        gradlePluginPortal()
        google()
    }
}
