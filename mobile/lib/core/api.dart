import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config.dart';
import 'format.dart';

typedef Json = Map<String, dynamic>;

class ApiException implements Exception {
  ApiException(this.message, [this.status]);
  final String message;
  final int? status;
  @override
  String toString() => message;
}

class Api {
  Api({String? base, http.Client? client})
      : base = base ?? Config.apiBase,
        _client = client ?? http.Client();

  final String base;
  String? token;
  void Function()? onUnauthorized;
  final http.Client _client;

  Future<dynamic> _send(String method, String path, {Map<String, String>? query, Object? body}) async {
    final uri = Uri.parse('$base$path').replace(queryParameters: query?.isEmpty ?? true ? null : query);
    try {
      final req = http.Request(method, uri)
        ..headers['Content-Type'] = 'application/json'
        ..headers['Accept'] = 'application/json';
      if (token != null) req.headers['Authorization'] = 'Bearer $token';
      if (body != null) req.body = jsonEncode(body);

      final streamed = await _client.send(req).timeout(const Duration(seconds: 15));
      final res = await http.Response.fromStream(streamed);
      final data = res.body.isEmpty ? null : jsonDecode(res.body);

      if (res.statusCode >= 200 && res.statusCode < 300) return data;
      if (res.statusCode == 401 && token != null) onUnauthorized?.call();
      final msg = data is Map && data['error'] is Map ? data['error']['message'] as String? : null;
      throw ApiException(msg ?? 'Request failed (${res.statusCode})', res.statusCode);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException("Can't reach the server at $base. Is it running, and is this address right for your device?");
    } on FormatException {
      throw ApiException('The server at $base sent an unexpected reply. Check that it is the Therapy Pal API.');
    } catch (_) {
      throw ApiException("Can't reach the server at $base. Is it running, and is this address right for your device?");
    }
  }

  /// GET. With [withNow], the device's local day/time are added so "today" matches the user's timezone.
  Future<Json> get(String path, {Map<String, String>? query, bool withNow = false}) async {
    final q = {...?query, if (withNow) ...nowQuery()};
    return Map<String, dynamic>.from(await _send('GET', path, query: q) as Map);
  }

  Future<Json> post(String path, [Json? body]) async =>
      Map<String, dynamic>.from(await _send('POST', path, body: body ?? {}) as Map);

  Future<Json> patch(String path, Json body) async =>
      Map<String, dynamic>.from(await _send('PATCH', path, body: body) as Map);
}