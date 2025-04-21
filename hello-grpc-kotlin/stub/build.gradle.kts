import com.google.protobuf.gradle.id
import com.google.protobuf.gradle.protobuf

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
    api("org.jetbrains.kotlinx:kotlinx-coroutines-core:${rootProject.ext["kotlinxVersion"]}")
    api("io.grpc:grpc-protobuf:${rootProject.ext["grpcVersion"]}")
    api("io.grpc:grpc-netty:${rootProject.ext["grpcVersion"]}")
    api("com.google.protobuf:protobuf-java-util:${rootProject.ext["protobufJavaUtilVersion"]}")
    api("io.grpc:grpc-kotlin-stub:${rootProject.ext["grpcKotlinVersion"]}")
    api("org.apache.logging.log4j:log4j-api-kotlin:${rootProject.ext["log4jKotlinVersion"]}")
    api("org.apache.logging.log4j:log4j-api:${rootProject.ext["log4jVersion"]}")
    api("org.apache.logging.log4j:log4j-core:${rootProject.ext["log4jVersion"]}")
    api("com.fasterxml.jackson.core:jackson-databind:${rootProject.ext["jacksonVersion"]}")
    api("com.fasterxml.jackson.dataformat:jackson-dataformat-yaml:${rootProject.ext["jacksonVersion"]}")
    testImplementation(kotlin("test"))
}

protobuf {
    protoc {
        artifact = "com.google.protobuf:protoc:${rootProject.ext["protobufVersion"]}"
    }
    plugins {
        id("grpc") {
            artifact = "io.grpc:protoc-gen-grpc-java:${rootProject.ext["grpcVersion"]}"
        }
        id("grpckt") {
            // https://repo1.maven.org/maven2/io/grpc/protoc-gen-grpc-kotlin/
            artifact = "io.grpc:protoc-gen-grpc-kotlin:${rootProject.ext["grpcKotlinVersion"]}:jdk8@jar"
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

//hello-grpc-kotlin/doc/windows_jdk.md
java {
    sourceCompatibility = JavaVersion.VERSION_21
}

kotlin {
    compilerOptions {
        apiVersion.set(org.jetbrains.kotlin.gradle.dsl.KotlinVersion.KOTLIN_2_0)
    }
}
tasks.test {
    useJUnitPlatform()
}

idea {
    module {
        sourceDirs.plusAssign(file("$projectDir/src/generated/"))
    }
}