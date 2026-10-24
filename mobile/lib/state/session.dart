import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/api.dart';

enum AuthStatus { booting, signedOut, signedIn }

class Session extends ChangeNotifier {
  Session(this.api) {
    api.onUnauthorized = _expired;
  }

  final Api api;
  final _store = const FlutterSecureStorage();
  static const _tokenKey = 'therapy_pal_token';
  static const _minSplash = Duration(milliseconds: 1400);

  AuthStatus status = AuthStatus.booting;
  Json? user;

  String get role => (user?['role'] as String?) ?? '';
  String get name => (user?['name'] as String?) ?? '';
  String get id => (user?['id'] as String?) ?? '';
  bool get isClinician => role == 'clinician';

  Future<void> restore() async {
    final started = DateTime.now();
    AuthStatus next = AuthStatus.signedOut;
    try {
      final token = await _store.read(key: _tokenKey);
      if (token != null) {
        api.token = token;
        final res = await api.get('/auth/me');
        user = Map<String, dynamic>.from(res['user'] as Map);
        next = AuthStatus.signedIn;
      }
    } on ApiException catch (e) {
      api.token = null;
      if (e.status == 401) await _store.delete(key: _tokenKey);
    } catch (_) {
      api.token = null;
    }
    final left = _minSplash - DateTime.now().difference(started);
    if (left > Duration.zero) await Future<void>.delayed(left);
    status = next;
    notifyListeners();
  }

  Future<void> _accept(Json res) async {
    api.token = res['token'] as String;
    user = Map<String, dynamic>.from(res['user'] as Map);
    await _store.write(key: _tokenKey, value: api.token);
    status = AuthStatus.signedIn;
    notifyListeners();
  }

  Future<void> login(String email, String password, String role) async =>
      _accept(await api.post('/auth/login', {'email': email, 'password': password, 'role': role}));

  Future<void> register(Json body) async => _accept(await api.post('/auth/register', body));

  void setUser(Json u) {
    user = u;
    notifyListeners();
  }

  Future<void> refreshUser() async {
    final res = await api.get('/auth/me');
    setUser(Map<String, dynamic>.from(res['user'] as Map));
  }

  Future<void> logout() async {
    api.token = null;
    user = null;
    await _store.delete(key: _tokenKey);
    status = AuthStatus.signedOut;
    notifyListeners();
  }

  void _expired() {
    if (status == AuthStatus.signedIn) logout();
  }
}

/// Unread counters shown on the bottom navigation.
class Badges extends ChangeNotifier {
  Badges(this.api);
  final Api api;
  int alerts = 0;
  int messages = 0;

  Future<void> refresh(String role) async {
    try {
      if (role == 'patient') {
        final r = await api.get('/notifications', withNow: true);
        alerts = (r['unread'] as num?)?.toInt() ?? 0;
      } else if (role == 'clinician') {
        final r = await api.get('/messages/threads');
        messages = (r['unread'] as num?)?.toInt() ?? 0;
      }
      notifyListeners();
    } catch (_) {
      // Badges are best-effort.
    }
  }

  void reset() {
    alerts = 0;
    messages = 0;
    notifyListeners();
  }
}
