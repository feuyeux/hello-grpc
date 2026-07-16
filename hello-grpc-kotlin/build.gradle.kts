plugins {
    idea
    // https://plugins.gradle.org/plugin/com.google.protobuf
    id("com.google.protobuf") version "0.10.0"
    // https://kotlinlang.org/docs/jvm-get-started.html
    // kotlin("jvm") 2.2.21 is the project's pinned Kotlin compiler
    // version (see AGENTS.md table "Kotlin 2.2.21"). 1.9.24 was the
    // pre-existing baseline but it cannot target JDK 25: kotlinc throws
    // java.lang.IllegalArgumentException: 25 in compileKotlin because
    // its fallback-to-JVM_21 path passes 25 to an internal API that
    // does not accept it. K2 (2.x) adds JDK 25 as a first-class
    // language target.
    kotlin("jvm") version "2.2.21"
}

//https://github.com/grpc/grpc/releases
//https://mvnrepository.com/artifact/io.grpc/grpc-netty
extra["grpcVersion"] = "1.82.1"
//https://mvnrepository.com/artifact/org.jetbrains.kotlinx/kotlinx-coroutines-core
extra["kotlinxVersion"] = "1.9.0"
//https://github.com/grpc/grpc-kotlin
//https://mvnrepository.com/artifact/io.grpc/grpc-kotlin-stub
//https://mvnrepository.com/artifact/io.grpc/protoc-gen-grpc-kotlin
extra["grpcKotlinVersion"] = "1.4.1"
//https://github.com/protocolbuffers/protobuf/releases
//https://mvnrepository.com/artifact/com.google.protobuf/protobuf-kotlin
extra["protobufVersion"] = "4.28.2"
//https://mvnrepository.com/artifact/com.google.protobuf/protobuf-java-util
extra["protobufJavaUtilVersion"] = "4.28.2"
//https://mvnrepository.com/artifact/org.apache.logging.log4j/log4j-core
extra["log4jVersion"] = "2.24.0"
//https://mvnrepository.com/artifact/org.apache.logging.log4j/log4j-api-kotlin
extra["log4jKotlinVersion"] = "1.5.0"
// OpenTelemetry SDK + contrib gRPC instrumentation versions used by Otel.kt.
// Upgrade these together because newer contrib releases rename GrpcTelemetry
// APIs and require corresponding source changes.
extra["opentelemetryVersion"] = "1.43.0"
extra["opentelemetryContribVersion"] = "2.10.0-alpha"
//https://mvnrepository.com/artifact/com.fasterxml.jackson.core/jackson-core
extra["jacksonVersion"] = "2.16.1"


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

// Force every subproject's Java source / target to 21, matching the
// Gradle build-base image (gradle:8.14-jdk21) and AGENTS.md's "Java 21
// compatibility as the source target unless a language project explicitly
// updates it". Kotlin 2.2.21's JVM target defaults to 21 on JDK 21, so
// pinning both compileJava and compileKotlin to 21 keeps Gradle's
// jvm-target validation happy.
subprojects {
    plugins.withType<org.gradle.api.plugins.JavaPlugin>().configureEach {
        extensions.configure<org.gradle.api.plugins.JavaPluginExtension>("java") {
            sourceCompatibility = JavaVersion.VERSION_21
            targetCompatibility = JavaVersion.VERSION_21
        }
    }

    plugins.withId("org.jetbrains.kotlin.jvm") {
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinJvmCompile>().configureEach {
            compilerOptions.jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_21)
        }
    }
}
