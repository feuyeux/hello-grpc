package org.feuyeux.grpc.discovery;

import static com.alibaba.nacos.api.PropertyKeyConst.SERVER_ADDR;

import com.alibaba.nacos.api.NacosFactory;
import com.alibaba.nacos.api.exception.NacosException;
import com.alibaba.nacos.api.naming.NamingService;
import io.grpc.NameResolver;
import io.grpc.NameResolverProvider;
import java.net.URI;
import java.util.Properties;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class NacosNameResolverProvider extends NameResolverProvider {
  private final Logger logger = LoggerFactory.getLogger(getClass());

  protected static final String NACOS = "nacos";

  private URI uri;

  public NacosNameResolverProvider(URI targetUri) {
    this.uri = targetUri;
  }

  @Override
  protected boolean isAvailable() {
    return true;
  }

  @Override
  protected int priority() {
    return 6;
  }

  @Override
  public NameResolver newNameResolver(URI targetUri, NameResolver.Args args) {
    return new NacosNameResolver(targetUri, buildNamingService());
  }

  @Override
  public String getDefaultScheme() {
    return NACOS;
  }

  private NamingService buildNamingService() {
    NamingService namingService = null;
    try {
      namingService = NacosFactory.createNamingService(buildNacosProperties(uri));
    } catch (NacosException e) {
      logger.error("build naming service error, msg: {}", e.getErrMsg());
    }
    return namingService;
  }

  private static Properties buildNacosProperties(URI uri) {
    Properties properties = new Properties();
    properties.put(SERVER_ADDR, uri.getHost() + ":" + uri.getPort());
    return properties;
  }
}
