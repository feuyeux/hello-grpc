import com.github.jengelman.gradle.plugins.shadow.tasks.ShadowJar
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

plugins {
    application
    kotlin("jvm")
    val shadowVersion = "8.1.1"
    id("com.github.johnrengelman.shadow") version shadowVersion
}

application {
    mainClass.set("org.feuyeux.grpc.ProtoClientKt")
}

dependencies {
    implementation(project(":stub"))
    runtimeOnly("io.grpc:grpc-netty:${rootProject.ext["grpcVersion"]}")
}

tasks.register<JavaExec>("ProtoClient") {
    dependsOn("classes")
    classpath = sourceSets["main"].runtimeClasspath
    mainClass.set("org.feuyeux.grpc.ProtoClientKt")
}
//https://github.com/GoogleCloudPlatform/kotlin-samples/blob/master/run/grpc-hello-world-gradle/build.gradle.kts
val protoClientStartScripts = tasks.register<CreateStartScripts>("protoClientStartScripts") {
    mainClass.set("org.feuyeux.grpc.ProtoClientKt")
    applicationName = "proto-client"
    outputDir = tasks.named<CreateStartScripts>("startScripts").get().outputDir
    classpath = tasks.named<CreateStartScripts>("startScripts").get().classpath
}

tasks.named("startScripts") {
    dependsOn(protoClientStartScripts)
}

tasks {
    named<ShadowJar>("shadowJar") {
        archiveBaseName.set("proto-client")
        mergeServiceFiles()
    }
}