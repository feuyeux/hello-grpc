import org.gradle.api.plugins.JavaApplication

plugins {
    id("application")
    id("org.jetbrains.kotlin.jvm") version "1.9.24"
    // Shadow plugin compatibility with Gradle 9.x is pending
    // Will be re-enabled when shadow 9.x stable is released
    // id("com.github.johnrengelman.shadow") version "9.x"
}

extensions.configure<JavaApplication>("application") {
    mainClass.set("org.feuyeux.grpc.ProtoClientKt")
}

dependencies {
    add("implementation", project(":stub"))
    add("implementation", "org.jetbrains.kotlin:kotlin-reflect:${rootProject.extra["kotlinxVersion"]}")
    add("runtimeOnly", "io.grpc:grpc-netty:${rootProject.extra["grpcVersion"]}")
}
