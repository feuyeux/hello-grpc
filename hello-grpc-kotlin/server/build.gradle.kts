import org.gradle.api.plugins.JavaApplication
import org.gradle.api.tasks.testing.Test

plugins {
    id("application")
    id("org.jetbrains.kotlin.jvm") version "2.4.10"
    // Shadow plugin compatibility with Gradle 9.x is pending
    // Will be re-enabled when shadow 9.x stable is released
    // id("com.github.johnrengelman.shadow") version "9.x"
}

extensions.configure<JavaApplication>("application") {
    mainClass.set("org.feuyeux.grpc.ProtoServerKt")
}

dependencies {
    add("implementation", project(":stub"))
    add("implementation", project(":client"))
    add("runtimeOnly", "io.grpc:grpc-netty:${rootProject.extra["grpcVersion"]}")
    add("implementation", "io.grpc:grpc-services:${rootProject.extra["grpcVersion"]}")
    // OpenTelemetry SDK + contrib gRPC instrumentations. The contrib
    // package's TracingServerInterceptor / TracingClientInterceptor
    // implement io.grpc.ServerInterceptor / ClientInterceptor
    // respectively and work against any grpc-java 1.6+ runtime.
    add("implementation", "io.opentelemetry:opentelemetry-api:${rootProject.extra["opentelemetryVersion"]}")
    add("implementation", "io.opentelemetry:opentelemetry-sdk:${rootProject.extra["opentelemetryVersion"]}")
    add("implementation", "io.opentelemetry:opentelemetry-exporter-logging:${rootProject.extra["opentelemetryVersion"]}")
    add("implementation", "io.opentelemetry.instrumentation:opentelemetry-grpc-1.6:${rootProject.extra["opentelemetryContribVersion"]}")
    add("testImplementation", kotlin("test"))
    add("testRuntimeOnly", "org.junit.platform:junit-platform-launcher")
}

tasks.withType<Test>().configureEach {
    useJUnitPlatform()
}
