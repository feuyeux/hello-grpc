import groovy.lang.Closure
import groovy.lang.GroovyObject
import org.gradle.api.NamedDomainObjectContainer
import org.gradle.api.tasks.testing.Test

plugins {
    id("idea")
    id("java-library")
    id("org.jetbrains.kotlin.jvm") version "2.2.21"
    id("com.google.protobuf") version "0.10.0"
}

dependencies {
    add("protobuf", project(":protos"))
    add("implementation", "io.grpc:grpc-stub:${rootProject.extra["grpcVersion"]}")
    add("api", kotlin("stdlib"))
    add("api", "org.jetbrains.kotlinx:kotlinx-coroutines-core:${rootProject.extra["kotlinxVersion"]}")
    add("api", "io.grpc:grpc-protobuf:${rootProject.extra["grpcVersion"]}")
    add("api", "io.grpc:grpc-netty:${rootProject.extra["grpcVersion"]}")
    add("api", "com.google.protobuf:protobuf-java-util:${rootProject.extra["protobufJavaUtilVersion"]}")
    add("api", "io.grpc:grpc-kotlin-stub:${rootProject.extra["grpcKotlinVersion"]}")
    add("api", "org.apache.logging.log4j:log4j-api-kotlin:${rootProject.extra["log4jKotlinVersion"]}")
    add("api", "org.apache.logging.log4j:log4j-api:${rootProject.extra["log4jVersion"]}")
    add("api", "org.apache.logging.log4j:log4j-core:${rootProject.extra["log4jVersion"]}")
    add("api", "com.fasterxml.jackson.core:jackson-databind:${rootProject.extra["jacksonVersion"]}")
    add("api", "com.fasterxml.jackson.module:jackson-module-kotlin:${rootProject.extra["jacksonVersion"]}")
    add("api", "com.fasterxml.jackson.dataformat:jackson-dataformat-yaml:${rootProject.extra["jacksonVersion"]}")
    add("api", "io.opentelemetry:opentelemetry-api:${rootProject.extra["opentelemetryVersion"]}")
    add("api", "io.opentelemetry:opentelemetry-sdk:${rootProject.extra["opentelemetryVersion"]}")
    add("api", "io.opentelemetry:opentelemetry-exporter-logging:${rootProject.extra["opentelemetryVersion"]}")
    add("api", "io.opentelemetry.instrumentation:opentelemetry-grpc-1.6:${rootProject.extra["opentelemetryContribVersion"]}")
    add("testImplementation", kotlin("test"))
}

extensions.configure<Any>("protobuf") {
    val protobuf = this as GroovyObject
    protobuf.invokeMethod("protoc", closureOf<GroovyObject> {
        setProperty("artifact", "com.google.protobuf:protoc:${rootProject.extra["protobufVersion"]}")
    })
    protobuf.invokeMethod("plugins", closureOf<GroovyObject> {
        val container = this as NamedDomainObjectContainer<*>
        (container.create("grpc") as GroovyObject)
            .setProperty("artifact", "io.grpc:protoc-gen-grpc-java:${rootProject.extra["grpcVersion"]}")
        (container.create("grpckt") as GroovyObject)
            .setProperty(
                "artifact",
                "io.grpc:protoc-gen-grpc-kotlin:${rootProject.extra["grpcKotlinVersion"]}:jdk8@jar"
            )
    })
    protobuf.invokeMethod("generateProtoTasks", closureOf<GroovyObject> {
        val tasks = invokeMethod("all", emptyArray<Any>()) as Iterable<*>
        tasks.forEach { task ->
            (task as GroovyObject).invokeMethod("plugins", closureOf<GroovyObject> {
                val container = this as NamedDomainObjectContainer<*>
                container.create("grpc")
                container.create("grpckt")
            })
        }
    })
}

extensions.configure<org.gradle.api.plugins.JavaPluginExtension>("java") {
    // Kotlin 2.2.21's JVM target defaults to 21 on JDK 21. compileJava
    // must match, otherwise Gradle's jvm-target validation aborts the
    // build. Aligns with root build.gradle.kts and AGENTS.md's "Java
    // 21 compatibility as the source target".
    sourceCompatibility = JavaVersion.VERSION_21
    targetCompatibility = JavaVersion.VERSION_21
}

tasks.withType<Test>().configureEach {
    useJUnitPlatform()
}

extensions.configure<org.gradle.plugins.ide.idea.model.IdeaModel>("idea") {
    module.sourceDirs.plusAssign(file("$projectDir/src/generated/"))
}
