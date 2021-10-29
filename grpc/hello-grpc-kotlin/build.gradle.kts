plugins {
    idea
    // https://github.com/google/protobuf-gradle-plugin
    id("com.google.protobuf") version "0.8.17" apply false
    // https://kotlinlang.org/docs/gradle.html
    kotlin("jvm") version "1.5.31"
}

ext["grpcVersion"] = "1.42.0"
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