plugins {
    application
    kotlin("jvm")
}

dependencies {
    implementation(project(":stub"))
    runtimeOnly("io.grpc:grpc-netty:${rootProject.ext["grpcVersion"]}")
}

tasks.register<JavaExec>("ProtoServer") {
    dependsOn("classes")
    classpath = sourceSets["main"].runtimeClasspath
    main = "org.feuyeux.grpc.ProtoServerKt"
}

val protoServerStartScripts = tasks.register<CreateStartScripts>("protoServerStartScripts") {
    mainClass.value("org.feuyeux.grpc.ProtoServerKt")
    applicationName = "proto-server"
    outputDir = tasks.named<CreateStartScripts>("startScripts").get().outputDir
    classpath = tasks.named<CreateStartScripts>("startScripts").get().classpath
}

tasks.named("startScripts") {
    dependsOn(protoServerStartScripts)
}
