plugins {
    idea
    // https://github.com/google/protobuf-gradle-plugin
    id("com.google.protobuf") version "0.8.17" apply false
    // https://kotlinlang.org/docs/gradle.html
    kotlin("jvm") version "1.5.30"
}

ext["grpcVersion"] = "1.37.0"
ext["grpcKotlinVersion"] = "1.1.0" // CURRENT_GRPC_KOTLIN_VERSION
ext["protobufVersion"] = "3.17.3"

allprojects {
  repositories {
    maven {
      // https://developer.aliyun.com/mvn/guide  
      url = uri("https://maven.aliyun.com/repository/public/")
      isAllowInsecureProtocol = true
    }
    google()
  }
}
// tasks.create("assemble").dependsOn(":server:installDist")