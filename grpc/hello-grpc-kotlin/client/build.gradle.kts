plugins {
    application
    kotlin("jvm")
}

dependencies {
    implementation(project(":stub"))
    runtimeOnly("io.grpc:grpc-netty:${rootProject.ext["grpcVersion"]}")
}

tasks.register<JavaExec>("ProtoClient") {
    dependsOn("classes")
    classpath = sourceSets["main"].runtimeClasspath
    main = "org.feuyeux.grpc.ProtoClientKt"
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
