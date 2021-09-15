sh build.sh
export JAVA_HOME=${JAVA_17_HOME}
mvn exec:java -Dexec.mainClass="org.feuyeux.grpc.client.ProtoClient"
