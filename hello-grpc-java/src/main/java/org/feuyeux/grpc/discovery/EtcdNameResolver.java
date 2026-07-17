package org.feuyeux.grpc.discovery;

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
import java.nio.charset.StandardCharsets;
import java.util.*;
import java.util.logging.Level;
import java.util.logging.Logger;
import javax.annotation.concurrent.GuardedBy;

public class EtcdNameResolver extends NameResolver implements Watch.Listener {

  private final Logger logger = Logger.getLogger(getClass().getName());

  // Cross-language compatible etcd key used by the Go/Python/Node.js/TypeScript
  // implementations: a single fixed key (no address suffix), independent of
  // serviceDir's prefix scheme, whose value is a plain "host:port" string.
  // Watched in addition to the Java-native serviceDir prefix so servers
  // started by any implementation are discoverable from Java.
  private static final String CROSS_LANG_ETCD_KEY = "/etcd/hello-grpc";

  private final Client etcd;
  private final String serviceDir;
  // Guarded by "this": two independent etcd watches (the serviceDir prefix
  // and the cross-language fixed key, registered in initializeAndWatch) can
  // deliver onNext callbacks concurrently on different jetcd watcher
  // threads, so all reads/writes/iteration over this set must be
  // synchronized — a plain HashSet is not thread-safe for concurrent
  // mutation and iteration.
  @GuardedBy("this")
  private final Set<URI> serviceUris;

  // The cross-language key is a single fixed key (not a prefix), so it can
  // only ever resolve to one address at a time. Tracking it separately lets
  // DELETE events clear exactly that entry without needing the pre-delete
  // value (etcd DELETE events carry an empty value by default; requesting
  // the previous value would require the client's watch-with-prev-kv option,
  // which this avoids to keep the change minimal and dependency-safe).
  @GuardedBy("this")
  private URI crossLangUri;

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
      String key = event.getKeyValue().getKey().toString(StandardCharsets.UTF_8);
      boolean crossLang = CROSS_LANG_ETCD_KEY.equals(key);
      switch (event.getEventType()) {
        case PUT:
          String svcAddress = crossLang
              ? resolveCrossLangValue(event.getKeyValue())
              : getUriFromDir(key);
          try {
            URI uri = new URI(svcAddress);
            synchronized (this) {
              if (crossLang) {
                // The cross-language key resolves to at most one address;
                // drop the previous one before adding the new one so a
                // re-registration under a different host:port does not
                // leave a stale entry behind.
                if (crossLangUri != null) {
                  serviceUris.remove(crossLangUri);
                }
                crossLangUri = uri;
              }
              serviceUris.add(uri);
            }
          } catch (URISyntaxException e) {
            logger.log(
                Level.WARNING,
                String.format(
                    "ignoring invalid uri. dir='%s', svcAddress='%s'", serviceDir, svcAddress),
                e);
          }
          break;
        case DELETE:
          if (crossLang) {
            // The cross-language key's DELETE event carries an empty value, so
            // remove the single address it was last known to hold instead of
            // trying to parse the (absent) payload.
            synchronized (this) {
              if (crossLangUri != null) {
                serviceUris.remove(crossLangUri);
                crossLangUri = null;
              }
            }
          } else {
            String removedAddress = getUriFromDir(key);
            try {
              URI uri = new URI(removedAddress);
              boolean removed;
              synchronized (this) {
                removed = serviceUris.remove(uri);
              }
              if (!removed) {
                logger.log(
                    Level.WARNING,
                    String.format(
                        "did not remove address. dir='%s', svcAddress='%s'",
                        serviceDir, removedAddress));
              }
            } catch (URISyntaxException e) {
              logger.log(
                  Level.WARNING,
                  String.format(
                      "ignoring invalid uri. dir='%s', svcAddress='%s'",
                      serviceDir, removedAddress),
                  e);
            }
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
    ByteSequence prefix = ByteSequence.from(serviceDir, StandardCharsets.UTF_8);
    GetOption option = GetOption.builder().isPrefix(true).build();
    ByteSequence crossLangKey = ByteSequence.from(CROSS_LANG_ETCD_KEY, StandardCharsets.UTF_8);

    GetResponse query;
    GetResponse crossLangQuery;
    try (KV kv = etcd.getKVClient()) {
      query = kv.get(prefix, option).get();
      crossLangQuery = kv.get(crossLangKey).get();
    } catch (Exception e) {
      throw new RuntimeException("Unable to contact etcd", e);
    }

    for (KeyValue kv : query.getKvs()) {
      addServiceUri(getUriFromDir(kv.getKey().toString(StandardCharsets.UTF_8)), false);
    }
    for (KeyValue kv : crossLangQuery.getKvs()) {
      addServiceUri(resolveCrossLangValue(kv), true);
    }

    updateListener();

    // set the Revision to avoid race between initializing URIs and watching for changes.
    WatchOption options =
        WatchOption.builder().withRevision(query.getHeader().getRevision()).build();

    etcd.getWatchClient().watch(prefix, options, this);
    // Watch the cross-language fixed key independently: it does not share the
    // serviceDir prefix, so it needs its own watch registration.
    WatchOption crossLangOptions =
        WatchOption.builder().withRevision(crossLangQuery.getHeader().getRevision()).build();
    etcd.getWatchClient().watch(crossLangKey, crossLangOptions, this);
  }

  private void addServiceUri(String svcAddress, boolean crossLang) {
    try {
      URI uri = new URI(svcAddress);
      synchronized (this) {
        if (crossLang) {
          crossLangUri = uri;
        }
        serviceUris.add(uri);
      }
    } catch (URISyntaxException e) {
      logger.log(
          Level.WARNING,
          String.format(
              "Unable to parse server address. dir='%s', svcAddress='%s'",
              serviceDir, svcAddress),
          e);
    }
  }

  private void updateListener() {
    logger.info("updating server list...");
    List<URI> snapshot;
    synchronized (this) {
      snapshot = new ArrayList<>(serviceUris);
    }
    List<EquivalentAddressGroup> svcAddressList = new ArrayList<>();
    for (URI uri : snapshot) {
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

  /**
   * Resolve the address URI from a cross-language fixed-key registration
   * (Go/Python/Node.js/TypeScript): the value is a plain {@code host:port}
   * string with no scheme, normalized here to a {@code grpc://host:port} URI.
   */
  private static String resolveCrossLangValue(KeyValue kv) {
    String value = kv.getValue().toString(StandardCharsets.UTF_8);
    return value.contains("://") ? value : "grpc://" + value;
  }

  /**
   * Extract the address URI embedded in a Java-native registration key, e.g.
   * {@code hello-grpc/grpc://host:port} -> {@code grpc://host:port}.
   */
  private static String getUriFromDir(String dir) {
    String tmp = dir.replace("://", "~");
    String[] tmps = tmp.split("/");
    return tmps[tmps.length - 1].replace("~", "://");
  }
}
