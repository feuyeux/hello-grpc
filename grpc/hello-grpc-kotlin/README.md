## grpc kotlin demo

https://grpc.io/docs/languages/kotlin/basics/

```bash
export JAVA_HOME=${JAVA_17_HOME}
gradle clean installDist
gradle :server:ProtoServer
gradle :client:ProtoClient
```

```bash
rm -rf ~/.gradle
vi ~/.m2/settings.xml
```