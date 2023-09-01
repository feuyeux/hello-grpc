## grpc kotlin demo

```bash
export JAVA_HOME=${JAVA_19_HOME}
gradle clean installDist --warning-mode all
gradle :server:ProtoServer
gradle :client:ProtoClient
```

```bash
rm -rf ~/.gradle
vi ~/.m2/settings.xml
```

### References
- https://grpc.io/docs/languages/kotlin/basics/
- https://github.com/grpc/grpc-kotlin