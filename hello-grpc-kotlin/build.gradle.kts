plugins {
    idea
    // https://plugins.gradle.org/plugin/com.google.protobuf
    id("com.google.protobuf") version "0.9.4"
    // https://kotlinlang.org/docs/jvm-get-started.html
    kotlin("jvm") version "1.9.22"
}

//https://github.com/grpc/grpc/releases
//https://mvnrepository.com/artifact/io.grpc/grpc-netty
ext["grpcVersion"] = "1.61.0"
//https://github.com/grpc/grpc-kotlin
ext["grpcKotlinVersion"] = "1.4.1"
//https://github.com/protocolbuffers/protobuf/releases
//https://mvnrepository.com/artifact/com.google.protobuf/protobuf-kotlin
ext["protobufVersion"] = "3.25.3"
//https://mvnrepository.com/artifact/org.apache.logging.log4j/log4j-core
ext["log4jVersion"] = "2.23.0"
//https://mvnrepository.com/artifact/com.fasterxml.jackson.core/jackson-core
ext["jacksonVersion"] = "2.16.1"

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
        gradlePluginPortal()
        google()
    }
}
// tasks.create("assemble").dependsOn(":server:installDist")