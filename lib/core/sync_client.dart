import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Ошибка обращения к серверу синхронизации.
class SyncException implements Exception {
  const SyncException(this.message, {this.code, this.statusCode});

  final String message;
  final String? code;
  final int? statusCode;

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}

class SyncAccount {
  const SyncAccount({
    required this.id,
    required this.email,
    required this.name,
  });

  final String id;
  final String email;
  final String name;

  factory SyncAccount.fromJson(Map<String, dynamic> json) => SyncAccount(
    id: (json['id'] ?? '').toString(),
    email: (json['email'] ?? '').toString(),
    name: (json['name'] ?? '').toString(),
  );
}

class SyncSession {
  const SyncSession({
    required this.token,
    required this.expiresAt,
    required this.account,
  });

  final String token;
  final int expiresAt;
  final SyncAccount account;
}

class SyncSpace {
  const SyncSpace({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.members,
    required this.ownerId,
  });

  final String id;
  final String name;
  final String inviteCode;
  final int members;
  final String ownerId;

  factory SyncSpace.fromJson(Map<String, dynamic> json) => SyncSpace(
    id: (json['id'] ?? '').toString(),
    name: (json['name'] ?? '').toString(),
    inviteCode: (json['invite_code'] ?? '').toString(),
    members: (json['members'] as num?)?.toInt() ?? 0,
    ownerId: (json['owner_id'] ?? '').toString(),
  );
}

/// Одна версия строки в общем пространстве.
class SyncRow {
  const SyncRow({
    required this.table,
    required this.id,
    required this.updatedAt,
    required this.deviceId,
    required this.deleted,
    this.data,
    this.seq = 0,
  });

  final String table;
  final String id;
  final int updatedAt;
  final String deviceId;
  final bool deleted;
  final Map<String, Object?>? data;
  final int seq;

  factory SyncRow.fromJson(Map<String, dynamic> json) {
    final raw = json['data'];
    return SyncRow(
      table: (json['table'] ?? '').toString(),
      id: (json['id'] ?? '').toString(),
      updatedAt: (json['updated_at'] as num?)?.toInt() ?? 0,
      deviceId: (json['device_id'] ?? '').toString(),
      deleted: json['deleted'] == true,
      data: raw is Map ? Map<String, Object?>.from(raw) : null,
      seq: (json['seq'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'table': table,
    'id': id,
    'updated_at': updatedAt,
    'device_id': deviceId,
    'deleted': deleted,
    if (data != null) 'data': data,
  };
}

class SyncPushResult {
  const SyncPushResult({
    required this.applied,
    required this.seq,
    required this.conflicts,
  });

  final int applied;
  final int seq;
  final List<SyncRow> conflicts;
}

class SyncPullResult {
  const SyncPullResult({
    required this.rows,
    required this.next,
    required this.latest,
    required this.more,
    required this.reset,
    this.cursor = '',
  });

  final List<SyncRow> rows;
  final int next;
  final int latest;
  final bool more;
  final bool reset;

  /// Позиция внутри полного снапшота (когда сервер отдаёт историю заново).
  final String cursor;
}

class SyncHealth {
  const SyncHealth({
    required this.service,
    required this.api,
    required this.users,
    required this.spaces,
  });

  final String service;
  final String api;
  final int users;
  final int spaces;
}

/// Клиент HTTP API сервера синхронизации.
class SyncClient {
  SyncClient({String baseUrl = '', http.Client? client, this.timeout = const Duration(seconds: 25)})
    : _client = client ?? http.Client(),
      _baseUrl = _normalize(baseUrl);

  final http.Client _client;
  final Duration timeout;
  String _baseUrl;

  String get baseUrl => _baseUrl;

  set baseUrl(String value) => _baseUrl = _normalize(value);

  static String _normalize(String value) {
    var url = value.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    final root = _baseUrl.isEmpty ? '' : _baseUrl;
    final uri = Uri.parse('$root$path');
    if (query == null || query.isEmpty) return uri;
    return uri.replace(queryParameters: {...uri.queryParameters, ...query});
  }

  Map<String, String> _headers(String? token) => {
    'Accept': 'application/json',
    'Content-Type': 'application/json; charset=utf-8',
    if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
  };

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    String? token,
    Object? body,
    Map<String, String>? query,
  }) async {
    final request = http.Request(method, _uri(path, query));
    request.headers.addAll(_headers(token));
    if (body != null) request.body = jsonEncode(body);

    late http.Response response;
    try {
      final streamed = await _client.send(request).timeout(timeout);
      response = await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw const SyncException('Сервер не ответил вовремя.');
    } catch (error) {
      throw SyncException('Нет связи с сервером: $error');
    }

    Map<String, dynamic> payload = const {};
    if (response.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map) payload = Map<String, dynamic>.from(decoded);
      } catch (_) {
        payload = const {};
      }
    }

    if (response.statusCode >= 400) {
      throw SyncException(
        (payload['error'] ?? 'Ошибка сервера (${response.statusCode})').toString(),
        code: payload['code']?.toString(),
        statusCode: response.statusCode,
      );
    }
    return payload;
  }

  Future<SyncHealth> health() async {
    final data = await _send('GET', '/api/health');
    return SyncHealth(
      service: (data['service'] ?? '').toString(),
      api: (data['api'] ?? '').toString(),
      users: (data['users'] as num?)?.toInt() ?? 0,
      spaces: (data['spaces'] as num?)?.toInt() ?? 0,
    );
  }

  Future<SyncSession> signUp({
    required String email,
    required String password,
    String name = '',
  }) async {
    final data = await _send(
      'POST',
      '/api/auth/signup',
      body: {'email': email, 'password': password, 'name': name},
    );
    return _session(data);
  }

  Future<SyncSession> signIn({
    required String email,
    required String password,
  }) async {
    final data = await _send(
      'POST',
      '/api/auth/signin',
      body: {'email': email, 'password': password},
    );
    return _session(data);
  }

  SyncSession _session(Map<String, dynamic> data) {
    final user = data['user'];
    return SyncSession(
      token: (data['token'] ?? '').toString(),
      expiresAt: (data['expires_at'] as num?)?.toInt() ?? 0,
      account: SyncAccount.fromJson(
        user is Map ? Map<String, dynamic>.from(user) : const {},
      ),
    );
  }

  Future<void> signOut(String token) async {
    await _send('POST', '/api/auth/signout', token: token);
  }

  Future<SyncAccount> me(String token) async {
    final data = await _send('GET', '/api/auth/me', token: token);
    final user = data['user'];
    return SyncAccount.fromJson(
      user is Map ? Map<String, dynamic>.from(user) : const {},
    );
  }

  Future<List<SyncSpace>> spaces(String token) async {
    final data = await _send('GET', '/api/spaces', token: token);
    final list = data['spaces'];
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((item) => SyncSpace.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<SyncSpace> createSpace(String token, String name) async {
    final data = await _send(
      'POST',
      '/api/spaces',
      token: token,
      body: {'name': name},
    );
    return _space(data);
  }

  Future<SyncSpace> joinSpace(String token, String inviteCode) async {
    final data = await _send(
      'POST',
      '/api/spaces/join',
      token: token,
      body: {'invite_code': inviteCode},
    );
    return _space(data);
  }

  SyncSpace _space(Map<String, dynamic> data) {
    final space = data['space'];
    return SyncSpace.fromJson(
      space is Map ? Map<String, dynamic>.from(space) : const {},
    );
  }

  Future<void> leaveSpace(String token, String spaceId) async {
    await _send('DELETE', '/api/spaces/$spaceId', token: token);
  }

  Future<Map<String, dynamic>> stats(String token, String spaceId) {
    return _send('GET', '/api/spaces/$spaceId/stats', token: token);
  }

  Future<SyncPushResult> push({
    required String token,
    required String spaceId,
    required List<SyncRow> rows,
  }) async {
    final data = await _send(
      'POST',
      '/api/sync/push',
      token: token,
      body: {
        'space_id': spaceId,
        'rows': rows.map((row) => row.toJson()).toList(),
      },
    );
    final conflicts = data['conflicts'];
    return SyncPushResult(
      applied: (data['applied'] as num?)?.toInt() ?? 0,
      seq: (data['seq'] as num?)?.toInt() ?? 0,
      conflicts: conflicts is List
          ? conflicts
                .whereType<Map>()
                .map((item) => SyncRow.fromJson(Map<String, dynamic>.from(item)))
                .toList()
          : const [],
    );
  }

  Future<SyncPullResult> pull({
    required String token,
    required String spaceId,
    required int since,
    int limit = 500,
    String cursor = '',
  }) async {
    final data = await _send(
      'GET',
      '/api/sync/pull',
      token: token,
      query: {
        'space_id': spaceId,
        'since': '$since',
        'limit': '$limit',
        if (cursor.isNotEmpty) 'cursor': cursor,
      },
    );
    final rows = data['rows'];
    return SyncPullResult(
      rows: rows is List
          ? rows
                .whereType<Map>()
                .map((item) => SyncRow.fromJson(Map<String, dynamic>.from(item)))
                .toList()
          : const [],
      next: (data['next'] as num?)?.toInt() ?? since,
      latest: (data['latest'] as num?)?.toInt() ?? since,
      more: data['more'] == true,
      reset: data['reset'] == true,
      cursor: (data['cursor'] ?? '').toString(),
    );
  }

  void close() => _client.close();
}
