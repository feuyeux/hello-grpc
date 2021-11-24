plugins {
    idea
    // https://github.com/google/protobuf-gradle-plugin
    val protobufPluginVersion = "0.8.18"
    // https://kotlinlang.org/docs/gradle.html
    val kotlinVersion = "1.6.0"

    id("com.google.protobuf") version protobufPluginVersion apply false
    kotlin("jvm") version kotlinVersion
}

ext["grpcVersion"] = "1.42.1"
ext["grpcKotlinVersion"] = "1.1.0" // CURRENT_GRPC_KOTLIN_VERSION
ext["protobufVersion"] = "3.17.3"
ext["log4jVersion"] = "2.14.1"
ext["jacksonVersion"] = "2.13.0"

allprojects {
    repositories {
        maven {
            // https://developer.aliyun.com/mvn/guide
            url = uri("https://maven.aliyun.com/repository/central")
            url = uri("https://maven.aliyun.com/repository/google")
            url = uri("https://maven.aliyun.com/repository/public")
            isAllowInsecureProtocol = true
        }
        mavenCentral()
    }
}
// tasks.create("assemble").dependsOn(":server:installDist")