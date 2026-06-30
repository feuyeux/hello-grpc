plugins {
    application
    kotlin("jvm")
    // Shadow plugin compatibility with Gradle 9.x is pending
    // Will be re-enabled when shadow 9.x stable is released
    // id("com.github.johnrengelman.shadow") version "9.x"
}

application {
    mainClass.set("org.feuyeux.grpc.ProtoServerKt")
}

dependencies {
    implementation(project(":stub"))
    implementation(project(":client"))
    runtimeOnly("io.grpc:grpc-netty:${rootProject.ext["grpcVersion"]}")
    // OpenTelemetry SDK + contrib gRPC instrumentations. The contrib
    // package's TracingServerInterceptor / TracingClientInterceptor
    // implement io.grpc.ServerInterceptor / ClientInterceptor
    // respectively and work against any grpc-java 1.6+ runtime.
    implementation("io.opentelemetry:opentelemetry-api:${opentelemetryVersion}")
    implementation("io.opentelemetry:opentelemetry-sdk:${opentelemetryVersion}")
    implementation("io.opentelemetry:opentelemetry-exporter-logging:${opentelemetryVersion}")
    implementation("io.opentelemetry.instrumentation:opentelemetry-grpc-1.6:${opentelemetryContribVersion}")
    testImplementation(kotlin("test"))
}

tasks.test {
    useJUnitPlatform()
}