rootProject.name = "hello-grpc-kotlin"
include("protos", "stub", "client", "server")

pluginManagement {
    repositories {
        maven {
            // https://developer.aliyun.com/mvn/guide
            url = uri("https://maven.aliyun.com/repository/gradle-plugin")
            isAllowInsecureProtocol = true
        }
        gradlePluginPortal()
        google()
    }
}
