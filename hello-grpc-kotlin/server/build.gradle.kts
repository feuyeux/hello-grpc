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
    testImplementation(kotlin("test"))
}

tasks.test {
    useJUnitPlatform()
}