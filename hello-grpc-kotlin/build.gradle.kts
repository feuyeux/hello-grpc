plugins {
    idea
    // https://plugins.gradle.org/plugin/com.google.protobuf
    id("com.google.protobuf") version "0.9.6"
    // https://kotlinlang.org/docs/jvm-get-started.html
    kotlin("jvm") version "1.9.24"
}

//https://github.com/grpc/grpc/releases
//https://mvnrepository.com/artifact/io.grpc/grpc-netty
ext["grpcVersion"] = "1.68.0"
//https://mvnrepository.com/artifact/org.jetbrains.kotlinx/kotlinx-coroutines-core
ext["kotlinxVersion"] = "1.9.0"
//https://github.com/grpc/grpc-kotlin
//https://mvnrepository.com/artifact/io.grpc/grpc-kotlin-stub
//https://mvnrepository.com/artifact/io.grpc/protoc-gen-grpc-kotlin
ext["grpcKotlinVersion"] = "1.4.1"
//https://github.com/protocolbuffers/protobuf/releases
//https://mvnrepository.com/artifact/com.google.protobuf/protobuf-kotlin
ext["protobufVersion"] = "4.28.2"
//https://mvnrepository.com/artifact/com.google.protobuf/protobuf-java-util
ext["protobufJavaUtilVersion"] = "4.28.2"
//https://mvnrepository.com/artifact/org.apache.logging.log4j/log4j-core
ext["log4jVersion"] = "2.24.0"
//https://mvnrepository.com/artifact/org.apache.logging.log4j/log4j-api-kotlin
ext["log4jKotlinVersion"] = "1.5.0"
//https://mvnrepository.com/artifact/com.fasterxml.jackson.core/jackson-core
ext["jacksonVersion"] = "2.16.1"


allprojects {
    repositories {
        maven {
            // https://developer.aliyun.com/mvn/guide
            url = uri("https://maven.aliyun.com/repository/public")
            isAllowInsecureProtocol = true
        }
        mavenCentral()
        gradlePluginPortal()
        google()
    }
}