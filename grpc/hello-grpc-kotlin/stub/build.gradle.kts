import com.google.protobuf.gradle.*

plugins {
    idea
    java
    kotlin("jvm")
    id("com.google.protobuf")
}

dependencies {
    protobuf(project(":protos"))
    implementation("io.grpc:grpc-stub:${rootProject.ext["grpcVersion"]}")
    api(kotlin("stdlib"))
    api("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.5.2-native-mt")
    api("io.grpc:grpc-protobuf:${rootProject.ext["grpcVersion"]}")
    api("io.grpc:grpc-netty:${rootProject.ext["grpcVersion"]}")
    api("com.google.protobuf:protobuf-java-util:3.19.1")
    api("io.grpc:grpc-kotlin-stub:1.2.0")
    api("org.apache.logging.log4j:log4j-api-kotlin:1.0.0")
    api("org.apache.logging.log4j:log4j-api:${rootProject.ext["log4jVersion"]}")
    api("org.apache.logging.log4j:log4j-core:${rootProject.ext["log4jVersion"]}")
    api("com.fasterxml.jackson.core:jackson-databind:${rootProject.ext["jacksonVersion"]}")
    api("com.fasterxml.jackson.dataformat:jackson-dataformat-yaml:${rootProject.ext["jacksonVersion"]}")
}

java {
    sourceCompatibility = JavaVersion.VERSION_16
}

protobuf {
    generatedFilesBaseDir = "$projectDir/src/generated"
    protoc {
        artifact = "com.google.protobuf:protoc:${rootProject.ext["protobufVersion"]}"
    }
    plugins {
        id("grpc") {
            artifact = "io.grpc:protoc-gen-grpc-java:${rootProject.ext["grpcVersion"]}"
        }
        id("grpckt") {
            // https://repo1.maven.org/maven2/io/grpc/protoc-gen-grpc-kotlin/1.1.0/
            artifact = "io.grpc:protoc-gen-grpc-kotlin:${rootProject.ext["grpcKotlinVersion"]}:jdk7@jar"
        }
    }
    generateProtoTasks {
        all().forEach {
            it.plugins {
                id("grpc")
                id("grpckt")
            }
        }
    }
}

tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile> {
    kotlinOptions.jvmTarget = "16"
}

idea {
    module {
        sourceDirs.plusAssign(file("$projectDir/src/generated/"))
    }
}