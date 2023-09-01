package org.feuyeux.grpc.etcd;

import com.google.common.base.Charsets;
import com.google.common.base.Preconditions;
import io.etcd.jetcd.*;
import io.etcd.jetcd.kv.GetResponse;
import io.etcd.jetcd.options.GetOption;
import io.etcd.jetcd.options.WatchOption;
import io.etcd.jetcd.watch.WatchEvent;
import io.etcd.jetcd.watch.WatchResponse;
import io.grpc.Attributes;
import io.grpc.EquivalentAddressGroup;
import io.grpc.NameResolver;
import java.net.InetSocketAddress;
import java.net.SocketAddress;
import java.net.URI;
import java.net.URISyntaxException;
import java.util.*;
import java.util.logging.Level;
import java.util.logging.Logger;
import javax.annotation.concurrent.GuardedBy;

public class EtcdNameResolver extends NameResolver implements Watch.Listener {

  private final Logger logger = Logger.getLogger(getClass().getName());

  private final Client etcd;
  private final String serviceDir;
  private final Set<URI> serviceUris;

  @GuardedBy("this")
  private Listener listener;

  EtcdNameResolver(List<URI> endpoints, String serviceDir) {
    this.etcd = Client.builder().endpoints(endpoints).build();
    this.serviceDir = serviceDir;
    this.serviceUris = new HashSet<>();
  }

  @Override
  public String getServiceAuthority() {
    return serviceDir;
  }

  @Override
  public void start(Listener listener) {
    synchronized (this) {
      Preconditions.checkState(this.listener == null, "already started");
      this.listener = Preconditions.checkNotNull(listener, "listener");
    }

    initializeAndWatch();
  }

  @Override
  public void shutdown() {
    etcd.close();
  }

  @Override
  public void onNext(WatchResponse watchResponse) {
    for (WatchEvent event : watchResponse.getEvents()) {
      String svcAddress;
      switch (event.getEventType()) {
        case PUT:
          svcAddress = event.getKeyValue().getKey().toString(Charsets.UTF_8);
          try {
            URI uri = new URI(svcAddress);
            serviceUris.add(uri);
          } catch (URISyntaxException e) {
            logger.log(
                Level.WARNING,
                String.format(
                    "ignoring invalid uri. dir='%s', svcAddress='%s'", serviceDir, svcAddress),
                e);
          }
          break;
        case DELETE:
          svcAddress = event.getKeyValue().getKey().toString(Charsets.UTF_8);
          try {
            URI uri = new URI(svcAddress);
            boolean removed = serviceUris.remove(uri);
            if (!removed) {
              logger.log(
                  Level.WARNING,
                  String.format(
                      "did not remove address. dir='%s', svcAddress='%s'", serviceDir, svcAddress));
            }
          } catch (URISyntaxException e) {
            logger.log(
                Level.WARNING,
                String.format(
                    "ignoring invalid uri. dir='%s', svcAddress='%s'", serviceDir, svcAddress),
                e);
          }
          break;
        case UNRECOGNIZED:
      }
    }

    updateListener();
  }

  @Override
  public void onError(Throwable throwable) {
    throw new RuntimeException("received error from etcd watcher!", throwable);
  }

  @Override
  public void onCompleted() {}

  private void initializeAndWatch() {
    ByteSequence prefix = ByteSequence.from(serviceDir, Charsets.UTF_8);
    GetOption option = GetOption.newBuilder().withPrefix(prefix).build();

    GetResponse query;
    try (KV kv = etcd.getKVClient()) {
      query = kv.get(prefix, option).get();
    } catch (Exception e) {
      throw new RuntimeException("Unable to contact etcd", e);
    }

    for (KeyValue kv : query.getKvs()) {
      String svcAddress = getUriFromDir(kv.getKey().toString(Charsets.UTF_8));
      try {
        URI uri = new URI(svcAddress);
        serviceUris.add(uri);
      } catch (URISyntaxException e) {
        logger.log(
            Level.WARNING,
            String.format(
                "Unable to parse server address. dir='%s', svcAddress='%s'",
                serviceDir, svcAddress),
            e);
      }
    }

    updateListener();

    // set the Revision to avoid race between initializing URIs and watching for changes.
    WatchOption options =
        WatchOption.newBuilder().withRevision(query.getHeader().getRevision()).build();

    etcd.getWatchClient().watch(prefix, options, this);
  }

  private void updateListener() {
    logger.info("updating server list...");
    List<EquivalentAddressGroup> svcAddressList = new ArrayList<>();
    for (URI uri : serviceUris) {
      logger.info("online: " + uri);
      List<SocketAddress> socketAddresses = new ArrayList<>();
      socketAddresses.add(new InetSocketAddress(uri.getHost(), uri.getPort()));
      svcAddressList.add(new EquivalentAddressGroup(socketAddresses));
    }
    if (svcAddressList.isEmpty()) {
      logger.log(Level.WARNING, String.format("no servers online. dir='%s'", serviceDir));
    } else {
      listener.onAddresses(svcAddressList, Attributes.EMPTY);
    }
  }

  private static String getUriFromDir(String dir) {
    String tmp = dir.replace("://", "~");
    String[] tmps = tmp.split("/");
    return tmps[tmps.length - 1].replace("~", "://");
  }
}
