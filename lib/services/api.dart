import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'demo_client.dart';
import 'settings.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, [this.statusCode]);
  @override
  String toString() => message;
}

typedef Json = Map<String, dynamic>;

/// Lidarr API client. Tries the primary URL first and falls back to the
/// secondary URL when the primary is unreachable.
class LidarrApi {
  final ServerConfig config;
  final http.Client _client;
  static const _timeout = Duration(seconds: 12);

  String? _activeBase;
  final Map<String, String> _versionByBase = {};

  LidarrApi(this.config, {http.Client? client})
    : _client =
          client ?? (config.isDemo ? DemoServer().client() : http.Client());

  bool get isDemo => config.isDemo;

  List<String> get _bases => [
    ?_activeBase,
    for (final u in [config.primaryUrl, config.secondaryUrl])
      if (u.isNotEmpty && u != _activeBase) u,
  ];

  String? get activeBase => _activeBase;

  Map<String, String> get headers => {
    'X-Api-Key': config.apiKey,
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  /// Absolute URL for a relative asset path (e.g. artist images).
  String assetUrl(String path) {
    if (path.startsWith('http')) return path;
    final base = _activeBase ?? config.primaryUrl;
    final sep = path.contains('?') ? '&' : '?';
    return '$base$path${sep}apikey=${config.apiKey}';
  }

  Future<String> _version(String base) async {
    final cached = _versionByBase[base];
    if (cached != null) return cached;
    var v = 'v1';
    try {
      final r = await _client
          .get(Uri.parse('$base/api'), headers: headers)
          .timeout(_timeout);
      if (r.statusCode == 200) {
        final j = jsonDecode(r.body);
        if (j is Map && j['current'] is String) v = j['current'] as String;
      }
    } catch (_) {}
    return _versionByBase[base] = v;
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Object? body,
    Duration timeout = _timeout,
  }) async {
    Object? lastError;
    for (final base in _bases) {
      try {
        final v = await _version(base);
        final uri = Uri.parse(
          '$base/api/$v$path',
        ).replace(queryParameters: query?.map((k, val) => MapEntry(k, '$val')));
        final req = http.Request(method, uri)..headers.addAll(headers);
        if (body != null) req.body = jsonEncode(body);
        final res = await http.Response.fromStream(
          await _client.send(req).timeout(timeout),
        );
        _activeBase = base;
        if (res.statusCode == 401) {
          throw ApiException('Invalid API key', 401);
        }
        if (res.statusCode < 200 || res.statusCode >= 300) {
          throw ApiException(_errorMessage(res), res.statusCode);
        }
        if (res.body.isEmpty) return null;
        return jsonDecode(utf8.decode(res.bodyBytes));
      } on ApiException {
        rethrow;
      } on Exception catch (e) {
        lastError = e;
      }
    }
    throw ApiException('Could not reach Lidarr (${lastError ?? 'no URL'})');
  }

  String _errorMessage(http.Response res) {
    try {
      final j = jsonDecode(res.body);
      if (j is List && j.isNotEmpty && j.first is Map) {
        return (j.first['errorMessage'] ?? 'Error ${res.statusCode}')
            .toString();
      }
      if (j is Map && j['message'] != null) return j['message'].toString();
    } catch (_) {}
    return 'Request failed (${res.statusCode})';
  }

  // ---- System ----
  Future<Json> systemStatus() async =>
      Json.from(await _send('GET', '/system/status'));
  Future<List<Json>> health() async => _list(await _send('GET', '/health'));
  Future<List<Json>> diskSpace() async =>
      _list(await _send('GET', '/diskspace'));

  // ---- Artists ----
  Future<List<Json>> artists() async => _list(await _send('GET', '/artist'));

  Future<Json> artistById(int id) async =>
      Json.from(await _send('GET', '/artist/$id'));

  Future<List<Json>> lookup(String term) async =>
      _list(await _send('GET', '/artist/lookup', query: {'term': term}));

  Future<Json> addArtist(Json body) async =>
      Json.from(await _send('POST', '/artist', body: body));

  Future<Json> updateArtist(Json body) async =>
      Json.from(await _send('PUT', '/artist/${body['id']}', body: body));

  Future<void> deleteArtist(int id, {bool deleteFiles = false}) async {
    await _send('DELETE', '/artist/$id', query: {'deleteFiles': deleteFiles});
  }

  Future<List<Json>> rootFolders() async =>
      _list(await _send('GET', '/rootfolder'));

  Future<List<Json>> qualityProfiles() async =>
      _list(await _send('GET', '/qualityprofile'));

  Future<List<Json>> metadataProfiles() async =>
      _list(await _send('GET', '/metadataprofile'));

  // ---- Albums & tracks ----
  Future<List<Json>> albums(int artistId) async =>
      _list(await _send('GET', '/album', query: {'artistId': artistId}));

  Future<Json> albumById(int id) async =>
      Json.from(await _send('GET', '/album/$id'));

  Future<Json> updateAlbum(Json body) async =>
      Json.from(await _send('PUT', '/album/${body['id']}', body: body));

  Future<List<Json>> tracks(int albumId) async =>
      _list(await _send('GET', '/track', query: {'albumId': albumId}));

  Future<List<Json>> trackFiles(int albumId) async =>
      _list(await _send('GET', '/trackfile', query: {'albumId': albumId}));

  Future<void> deleteTrackFile(int id) async {
    await _send('DELETE', '/trackfile/$id');
  }

  Future<List<Json>> calendar(DateTime start, DateTime end) async => _list(
    await _send(
      'GET',
      '/calendar',
      query: {
        'start': start.toUtc().toIso8601String(),
        'end': end.toUtc().toIso8601String(),
        'includeArtist': true,
      },
    ),
  );

  Future<List<Json>> albumHistory(int albumId) async {
    final r = await _send(
      'GET',
      '/history',
      query: {
        'page': 1,
        'pageSize': 100,
        'sortKey': 'date',
        'sortDirection': 'descending',
        'albumId': albumId,
      },
    );
    return _list(r is Map ? r['records'] : r);
  }

  // ---- Manual search ----
  // Indexer queries can take minutes, so use a generous timeout.
  static const releaseTimeout = Duration(minutes: 5);

  Future<List<Json>> releases(int albumId) async => _list(
    await _send(
      'GET',
      '/release',
      query: {'albumId': albumId},
      timeout: releaseTimeout,
    ),
  );

  Future<void> grabRelease(String guid, int indexerId) async {
    await _send(
      'POST',
      '/release',
      body: {'guid': guid, 'indexerId': indexerId},
      timeout: releaseTimeout,
    );
  }

  // ---- Activity ----
  Future<List<Json>> queue() async {
    final r = await _send(
      'GET',
      '/queue',
      query: {
        'page': 1,
        'pageSize': 100,
        'includeArtist': true,
        'includeAlbum': true,
      },
    );
    return _list(r is Map ? r['records'] : r);
  }

  Future<void> removeQueueItem(int id, {bool blocklist = false}) async {
    await _send(
      'DELETE',
      '/queue/$id',
      query: {'removeFromClient': true, 'blocklist': blocklist},
    );
  }

  Future<List<Json>> history({int pageSize = 50}) async {
    final r = await _send(
      'GET',
      '/history',
      query: {
        'page': 1,
        'pageSize': pageSize,
        'sortKey': 'date',
        'sortDirection': 'descending',
        'includeArtist': true,
        'includeAlbum': true,
      },
    );
    return _list(r is Map ? r['records'] : r);
  }

  Future<List<Json>> missing({int page = 1, int pageSize = 50}) async {
    final r = await _send(
      'GET',
      '/wanted/missing',
      query: {
        'page': page,
        'pageSize': pageSize,
        'sortKey': 'releaseDate',
        'sortDirection': 'descending',
        'monitored': true,
        'includeArtist': true,
      },
    );
    return _list(r is Map ? r['records'] : r);
  }

  // ---- Commands ----
  Future<void> command(String name, [Json extra = const {}]) async {
    await _send('POST', '/command', body: {'name': name, ...extra});
  }

  Future<void> searchArtist(int artistId) =>
      command('ArtistSearch', {'artistId': artistId});
  Future<void> searchAlbums(List<int> ids) =>
      command('AlbumSearch', {'albumIds': ids});
  Future<void> refreshArtist(int artistId) =>
      command('RefreshArtist', {'artistId': artistId});
  Future<void> searchMissing() => command('MissingAlbumSearch');

  List<Json> _list(dynamic v) =>
      (v as List? ?? const []).map((e) => Json.from(e as Map)).toList();

  void dispose() => _client.close();
}
