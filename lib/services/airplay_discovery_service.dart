import 'dart:async';
import 'dart:io';
import 'package:multicast_dns/multicast_dns.dart';

class AirplayDevice {
  final String name;
  final String host;
  final int port;

  AirplayDevice({required this.name, required this.host, required this.port});
}

class AirplayDiscoveryService {
  Future<List<AirplayDevice>> discover({Duration timeout = const Duration(seconds: 4)}) async {
    final List<AirplayDevice> devices = [];
    final client = MDnsClient(
      rawDatagramSocketFactory: (dynamic host, int port,
          {bool reuseAddress = true, bool reusePort = true, int ttl = 1}) {
        return RawDatagramSocket.bind(
          host,
          port,
          reuseAddress: reuseAddress,
          reusePort: reusePort,
          ttl: ttl,
        );
      },
    );

    try {
      await client.start();

      final ptrStream = client.lookup<PtrResourceRecord>(
        ResourceRecordQuery.serverPointer('_airplay._tcp.local'),
      );

      final completer = Completer<void>();
      Timer? timer;
      timer = Timer(timeout, () {
        if (!completer.isCompleted) completer.complete();
      });

      ptrStream.listen((ptr) async {
        final srvStream = client.lookup<SrvResourceRecord>(
          ResourceRecordQuery.service(ptr.domainName),
        );

        await for (final srv in srvStream) {
          final targetName = srv.target;
          final hostName = targetName.endsWith('.') ? targetName.substring(0, targetName.length - 1) : targetName;

          // Attempt to resolve address; fall back to host name.
          String resolvedHost = hostName;
          try {
            final addressQuery = client.lookup<IPAddressResourceRecord>(
              ResourceRecordQuery.addressIPv4(hostName),
            );
            await for (final addr in addressQuery) {
              resolvedHost = addr.address.address;
              break;
            }
          } catch (_) {}

          final deviceName = ptr.domainName.split('.').first;
          devices.add(
            AirplayDevice(
              name: deviceName,
              host: resolvedHost,
              port: srv.port,
            ),
          );
        }
      }, onDone: () {
        if (!completer.isCompleted) completer.complete();
      });

      await completer.future;
      timer?.cancel();
    } catch (_) {
      // Swallow errors; we prefer a graceful empty result.
    } finally {
      client.stop();
    }

    // De-duplicate by host/port/name
    final seen = <String>{};
    final unique = <AirplayDevice>[];
    for (final d in devices) {
      final key = '${d.name}-${d.host}-${d.port}';
      if (seen.add(key)) unique.add(d);
    }
    return unique;
  }
}
