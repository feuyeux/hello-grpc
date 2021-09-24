import com.github.jengelman.gradle.plugins.shadow.tasks.ShadowJar
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

plugins {
    application
    kotlin("jvm")
    id("com.github.johnrengelman.shadow") version "7.0.0"
}

application {
    mainClass.value("org.feuyeux.grpc.ProtoClientKt")
}

dependencies {
    implementation(project(":stub"))
    runtimeOnly("io.grpc:grpc-netty:${rootProject.ext["grpcVersion"]}")
}

tasks.register<JavaExec>("ProtoClient") {
    dependsOn("classes")
    classpath = sourceSets["main"].runtimeClasspath
    mainClass.value("org.feuyeux.grpc.ProtoClientKt")
}

val protoClientStartScripts = tasks.register<CreateStartScripts>("protoClientStartScripts") {
    mainClass.value("org.feuyeux.grpc.ProtoClientKt")
    applicationName = "proto-client"
    outputDir = tasks.named<CreateStartScripts>("startScripts").get().outputDir
    classpath = tasks.named<CreateStartScripts>("startScripts").get().classpath
}

tasks.named("startScripts") {
    dependsOn(protoClientStartScripts)
}

tasks.withType<KotlinCompile> {
    kotlinOptions.jvmTarget = "16"
}

tasks {
    named<ShadowJar>("shadowJar") {
        archiveBaseName.set("proto-client")
        mergeServiceFiles()
    }
}