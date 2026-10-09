// Richieste partite mentre l'app rinnova l'accesso (bug del 2026-10-09: foto allegata che non compariva). Al ritorno in primo piano, per esempio dopo aver scelto una foto, l'app rinnova la chiave d'accesso e il server da quel momento rifiuta la vecchia: una richiesta partita in quell'istante non deve usare la chiave vecchia e farsi rifiutare. Il server finto qui sotto fa come quello vero: il rinnovo invalida subito la chiave precedente.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kitchenowl/services/api/api_service.dart';

class _FakeServer {
  late final HttpServer server;
  var validAccessToken = '';
  var rotations = 0;
  final rejectedItemRequests = <String>[];
  Completer<void> refreshArrived = Completer();
  Completer<void> releaseRefresh = Completer()..complete();

  String get url => 'http://${server.address.host}:${server.port}';

  Future<void> start() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen(_handle);
  }

  Future<void> _handle(HttpRequest request) async {
    final path = request.uri.path;
    final auth = request.headers.value('authorization') ?? '';
    if (path.startsWith('/api/health')) {
      return _json(request, {
        'msg': 'OK',
        'version': 200,
        'min_frontend_version': 0,
      });
    }
    if (path == '/api/auth/refresh') {
      rotations++;
      validAccessToken = 'access-$rotations';
      if (!refreshArrived.isCompleted) refreshArrived.complete();
      await releaseRefresh.future;
      return _json(request, {
        'access_token': validAccessToken,
        'refresh_token': 'refresh-$rotations',
      });
    }
    if (path == '/api/item/1') {
      if (auth != 'Bearer $validAccessToken') {
        rejectedItemRequests.add(auth);
        request.response.statusCode = 401;
        return _json(request, {'msg': 'Token has been revoked'});
      }
      return _json(request, {'id': 1});
    }
    request.response.statusCode = 404;
    await request.response.close();
  }

  Future<void> _json(HttpRequest request, Object body) async {
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(body));
    await request.response.close();
  }
}

void main() {
  test("a request started while the app renews access is not rejected",
      () async {
    final fake = _FakeServer();
    await fake.start();
    await ApiService.connectTo(fake.url, refreshToken: 'refresh-0');
    final api = ApiService.getInstance();
    expect(api.isAuthenticated(), isTrue);

    // Come al ritorno in primo piano: il rinnovo è già arrivato al server
    // (che ha invalidato la chiave vecchia) e non ha ancora risposto
    fake.refreshArrived = Completer();
    fake.releaseRefresh = Completer();
    final renewal = api.refresh();
    await fake.refreshArrived.future;
    final request = api.get('/item/1');
    await Future.delayed(const Duration(milliseconds: 100));
    fake.releaseRefresh.complete();
    final response = await request;
    await renewal;

    expect(response.statusCode, 200);
    expect(fake.rejectedItemRequests, isEmpty);
    api.dispose();
    await fake.server.close(force: true);
  });
}
