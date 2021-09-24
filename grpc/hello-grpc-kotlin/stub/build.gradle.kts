import com.google.protobuf.gradle.*

plugins {
    idea
    kotlin("jvm")
    id("com.google.protobuf")
}

dependencies {
    protobuf(project(":protos"))
    implementation("io.grpc:grpc-stub:1.40.1")
    api(kotlin("stdlib"))
    api("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.4.3")
    api("io.grpc:grpc-protobuf:${rootProject.ext["grpcVersion"]}")
    api("com.google.protobuf:protobuf-java-util:${rootProject.ext["protobufVersion"]}")
    api("io.grpc:grpc-kotlin-stub:${rootProject.ext["grpcKotlinVersion"]}")
}

java {
    sourceCompatibility = JavaVersion.VERSION_1_8
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
idea {
    module {
        sourceDirs.plusAssign(file("$projectDir/src/generated/"))
    }
}