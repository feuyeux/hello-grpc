plugins {
    idea
    // https://github.com/google/protobuf-gradle-plugin
    val protobufPluginVersion = "0.9.2"
    // https://kotlinlang.org/docs/gradle.html
    val kotlinVersion = "1.8.10"

    id("com.google.protobuf") version protobufPluginVersion apply false
    kotlin("jvm") version kotlinVersion
}

//https://github.com/grpc/grpc/releases
ext["grpcVersion"] = "1.53.0"
//https://github.com/grpc/grpc-kotlin
ext["grpcKotlinVersion"] = "1.3.0"
//https://github.com/protocolbuffers/protobuf/releases
//https://mvnrepository.com/artifact/com.google.protobuf/protobuf-kotlin
ext["protobufVersion"] = "3.22.2"
//https://mvnrepository.com/artifact/org.apache.logging.log4j/log4j-core
ext["log4jVersion"] = "2.20.0"
//https://mvnrepository.com/artifact/com.fasterxml.jackson.core/jackson-core
ext["jacksonVersion"] = "2.14.2"

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