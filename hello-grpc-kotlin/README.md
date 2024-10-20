# grpc kotlin demo

hello-grpc-kotlin/stub/build.gradle.kts

```kotlin
//hello-grpc-kotlin/doc/windows_jdk.md

java {
    sourceCompatibility = JavaVersion.VERSION_21
}

kotlin {
    compilerOptions {
        apiVersion.set(org.jetbrains.kotlin.gradle.dsl.KotlinVersion.KOTLIN_2_0)
    }
}
```

```bash
# brew install gradle
gradle -v | grep JVM
gradle clean installDist --warning-mode all
gradle :server:ProtoServer
gradle :client:ProtoClient
```

```bash
rm -rf ~/.gradle
vi ~/.m2/settings.xml
```

## References

- <https://grpc.io/docs/languages/kotlin/basics/>
- <https://github.com/grpc/grpc-kotlin>
