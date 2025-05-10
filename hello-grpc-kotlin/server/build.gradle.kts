import com.github.jengelman.gradle.plugins.shadow.tasks.ShadowJar

plugins {
    application
    kotlin("jvm")
    val shadowVersion = "8.1.1"
    id("com.github.johnrengelman.shadow") version shadowVersion
}

application {
    mainClass.set("org.feuyeux.grpc.ProtoServerKt")
}

dependencies {
    implementation(project(":stub"))
    api(project(":client"))
    runtimeOnly("io.grpc:grpc-netty:${rootProject.ext["grpcVersion"]}")
    testImplementation(kotlin("test"))
}

tasks.register<JavaExec>("ProtoServer") {
    dependsOn("classes")
    classpath = sourceSets["main"].runtimeClasspath
    mainClass.set("org.feuyeux.grpc.ProtoServerKt")
}

val protoServerStartScripts = tasks.register<CreateStartScripts>("protoServerStartScripts") {
    mainClass.set("org.feuyeux.grpc.ProtoServerKt")
    applicationName = "proto-server"
    outputDir = tasks.named<CreateStartScripts>("startScripts").get().outputDir
    classpath = tasks.named<CreateStartScripts>("startScripts").get().classpath
}

tasks.named("startScripts") {
    dependsOn(protoServerStartScripts)
}

tasks {
    named<ShadowJar>("shadowJar") {
        archiveBaseName.set("proto-server")
        mergeServiceFiles()
    }
    
    // 配置distTar任务
    named<Tar>("distTar") {
        archiveFileName.set("server.tar")
        compression = Compression.NONE
    }
}

tasks.test {
    useJUnitPlatform()
}