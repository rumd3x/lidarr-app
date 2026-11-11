import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// In-memory fake Lidarr server used by demo mode. It answers the same
/// endpoints as the real API, so every screen works without a server.
class DemoServer {
  static const url = 'http://demo.lidarr.local';

  final DateTime _now = DateTime.now();
  final List<Map<String, dynamic>> _artists = [];
  final List<Map<String, dynamic>> _albums = [];
  final Map<int, List<Map<String, dynamic>>> _tracks = {};
  final List<Map<String, dynamic>> _queue = [];
  final List<Map<String, dynamic>> _history = [];
  var _nextId = 1000;

  DemoServer() {
    _seed();
  }

  http.Client client() => MockClient(_handle);

  // name, type, status, genre, overview, albums (title, type, days from now)
  static const _specs = [
    (
      'Neon Harbor',
      'Group',
      'continuing',
      'Synthwave',
      'Four friends from a port city blend glowing synths with drum machines '
          'and late-night storytelling.',
      [
        ('Night Shift', 'Album', -1500),
        ('Glass Tide', 'Album', -900),
        ('Afterglow EP', 'EP', -400),
        ('Signal Lights', 'Album', -40),
        ('Harbor Dreams', 'Album', 12),
      ],
    ),
    (
      'The Paper Foxes',
      'Group',
      'continuing',
      'Indie Folk',
      'A folk quartet known for hushed harmonies and handmade '
          'instruments.',
      [
        ('Orchard Songs', 'Album', -2000),
        ('Winter Letters', 'Album', -1100),
        ('Lantern', 'Single', -200),
        ('Tall Grass', 'Album', 5),
      ],
    ),
    (
      'Ada Winters',
      'Person',
      'continuing',
      'Jazz',
      'A pianist and composer reinventing the standards one late set at '
          'a time.',
      [
        ('Blue Hour', 'Album', -1800),
        ('Small Rooms', 'Album', -700),
        ('Live at the Cellar', 'Live', -90),
      ],
    ),
    (
      'Static Bloom',
      'Group',
      'ended',
      'Shoegaze',
      'A short-lived but beloved band whose two records still echo '
          'through the scene.',
      [('Pale Colors', 'Album', -4500), ('Overgrown', 'Album', -4000)],
    ),
    (
      'Marcus Vale',
      'Person',
      'continuing',
      'Hip-Hop',
      'A storyteller rapper chronicling life on the last bus home.',
      [
        ('Last Bus', 'Album', -1300),
        ('Zone 6', 'Album', -600),
        ('Mixtape Vol. 1', 'Compilation', -250),
        ('Night Owl', 'Single', -1),
      ],
    ),
    (
      'Solar Choir',
      'Group',
      'continuing',
      'Ambient',
      'Choral textures and field recordings made for long train rides.',
      [('Dawn Chorus', 'Album', -800), ('Slow Orbit', 'Album', 21)],
    ),
  ];

  static const _words = [
    'Echo',
    'Ember',
    'Harbor',
    'Velvet',
    'Paper',
    'Midnight',
    'Wire',
    'Lantern',
    'Orbit',
    'Static',
    'Bloom',
    'Tide',
    'Silver',
    'Quiet',
    'Highway',
    'Moth',
    'Glass',
    'Field',
    'Signal',
    'Neon',
    'Fox',
    'Rain',
  ];
  static const _nouns = [
    'Light',
    'Song',
    'Run',
    'Dream',
    'Road',
    'Hour',
    'Garden',
    'Room',
    'Fire',
    'Letter',
    'Season',
    'Machine',
    'Weather',
    'Story',
    'Girl',
  ];

  String _trackTitle(int seed, int n) {
    final a = _words[(seed * 7 + n * 3) % _words.length];
    final b = _nouns[(seed * 5 + n * 11) % _nouns.length];
    return n % 4 == 0 ? a : '$a $b';
  }

  void _seed() {
    var aid = 1;
    for (final (name, type, status, genre, overview, albums) in _specs) {
      final artistId = aid++;
      _artists.add({
        'id': artistId,
        'artistName': name,
        'sortName': name.toLowerCase().replaceFirst('the ', ''),
        'foreignArtistId': 'demo-mbid-$artistId',
        'artistType': type,
        'status': status,
        'overview': overview,
        'genres': [genre],
        'monitored': true,
        'path': '/media/music/$name',
        'rootFolderPath': '/media/music',
        'qualityProfileId': 1,
        'metadataProfileId': 1,
        'added': _now.subtract(const Duration(days: 300)).toIso8601String(),
        'images': const [],
      });
      var n = 0;
      for (final (title, albumType, days) in albums) {
        n++;
        final albumId = _nextId++;
        final date = _now.add(Duration(days: days));
        final released = date.isBefore(_now);
        final missing = released && days > -120 && n % 2 == 1;
        final count = albumType == 'Single' ? 2 : 8 + (artistId + n) % 5;
        _albums.add({
          'id': albumId,
          'artistId': artistId,
          'title': title,
          'albumType': albumType,
          'foreignAlbumId': 'demo-album-$albumId',
          'overview':
              '"$title" by $name. A ${genre.toLowerCase()} record about '
              'distance, memory and the quiet moments in between.',
          'releaseDate': date.toUtc().toIso8601String(),
          'monitored': true,
          'genres': [genre],
          'images': const [],
        });
        final tracks = <Map<String, dynamic>>[];
        for (var t = 1; t <= count; t++) {
          final hasFile = released && !missing;
          final fileId = _nextId++;
          tracks.add({
            'id': _nextId++,
            'albumId': albumId,
            'artistId': artistId,
            'title': _trackTitle(albumId, t),
            'trackNumber': '$t',
            'absoluteTrackNumber': t,
            'mediumNumber': 1,
            'duration': 150000 + ((albumId * 13 + t * 37) % 140) * 1000,
            'hasFile': hasFile,
            'trackFileId': hasFile ? fileId : 0,
            if (hasFile)
              'trackFile': {
                'id': fileId,
                'albumId': albumId,
                'path':
                    '/media/music/$name/$title/${t.toString().padLeft(2, '0')}'
                    ' - ${_trackTitle(albumId, t)}.flac',
                'size': 28000000 + (t * 977000),
                'dateAdded': date
                    .add(const Duration(days: 1))
                    .toIso8601String(),
                'quality': {
                  'quality': {'id': 6, 'name': 'FLAC'},
                },
                'mediaInfo': {
                  'audioCodec': 'FLAC',
                  'audioBitRate': '912kbps',
                  'audioChannels': 2,
                  'audioBits': '16bit',
                  'audioSampleRate': '44.1kHz',
                },
              },
          });
        }
        _tracks[albumId] = tracks;
        if (released && !missing) {
          _history.add({
            'id': _nextId++,
            'albumId': albumId,
            'artistId': artistId,
            'eventType': 'trackFileImported',
            'sourceTitle': '$name - $title (2020) FLAC',
            'date': date.add(const Duration(days: 1)).toIso8601String(),
            'quality': {
              'quality': {'name': 'FLAC'},
            },
            'data': {'indexer': 'Demo Indexer'},
          });
          _history.add({
            'id': _nextId++,
            'albumId': albumId,
            'artistId': artistId,
            'eventType': 'grabbed',
            'sourceTitle': '$name - $title (2020) FLAC',
            'date': date.toIso8601String(),
            'quality': {
              'quality': {'name': 'FLAC'},
            },
            'data': {
              'indexer': 'Demo Indexer',
              'downloadClientName': 'Demo Client',
            },
          });
        }
      }
    }
    _history.sort((a, b) => '${b['date']}'.compareTo('${a['date']}'));

    final queued = _albums
        .where((a) {
          final d = DateTime.parse(a['releaseDate'] as String);
          return d.isBefore(_now) &&
              _tracks[a['id']]!.every((t) => t['hasFile'] != true);
        })
        .take(2);
    var i = 0;
    for (final a in queued) {
      final size = 420000000 + i * 90000000;
      _queue.add({
        'id': _nextId++,
        'artistId': a['artistId'],
        'albumId': a['id'],
        'title': '${_artistOf(a)['artistName']} - ${a['title']} FLAC',
        'status': i == 0 ? 'downloading' : 'queued',
        'size': size,
        'sizeleft': i == 0 ? (size * 0.35).round() : size,
        'timeleft': i == 0 ? '00:04:12' : '00:12:40',
        'downloadClient': 'Demo Client',
        'protocol': 'torrent',
        'artist': _artistOf(a),
        'album': a,
      });
      i++;
    }
  }

  Map<String, dynamic> _artistOf(Map<String, dynamic> album) =>
      _artists.firstWhere((a) => a['id'] == album['artistId']);

  Map<String, dynamic> _albumStats(Map<String, dynamic> album) {
    final tracks = _tracks[album['id']] ?? const [];
    final files = tracks.where((t) => t['hasFile'] == true).toList();
    final size = files.fold<int>(
      0,
      (a, t) => a + ((t['trackFile'] as Map)['size'] as int),
    );
    return {
      'trackCount': tracks.length,
      'trackFileCount': files.length,
      'totalTrackCount': tracks.length,
      'sizeOnDisk': size,
      'percentOfTracks': tracks.isEmpty
          ? 0
          : 100 * files.length / tracks.length,
    };
  }

  Map<String, dynamic> _albumOut(Map<String, dynamic> a) => {
    ...a,
    'statistics': _albumStats(a),
  };

  Map<String, dynamic> _albumWithArtist(Map<String, dynamic> a) => {
    ..._albumOut(a),
    'artist': _artistOut(_artistOf(a)),
  };

  Map<String, dynamic> _artistOut(Map<String, dynamic> artist) {
    final albums = _albums.where((a) => a['artistId'] == artist['id']);
    var tracks = 0, files = 0, size = 0;
    for (final a in albums) {
      final s = _albumStats(a);
      tracks += s['trackCount'] as int;
      files += s['trackFileCount'] as int;
      size += s['sizeOnDisk'] as int;
    }
    return {
      ...artist,
      'statistics': {
        'albumCount': albums.length,
        'trackCount': tracks,
        'trackFileCount': files,
        'totalTrackCount': tracks,
        'sizeOnDisk': size,
      },
    };
  }

  http.Response _json(Object? body, [int status = 200]) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  Map<String, dynamic> _withRefs(Map<String, dynamic> h) => {
    ...h,
    'artist': _artistOut(_artists.firstWhere((a) => a['id'] == h['artistId'])),
    'album': _albumOut(_albums.firstWhere((a) => a['id'] == h['albumId'])),
  };

  Future<http.Response> _handle(http.Request req) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final path = req.url.path;
    final q = req.url.queryParameters;
    final m = req.method;
    final body = req.body.isEmpty ? null : jsonDecode(req.body);

    if (path == '/api') return _json({'current': 'v1'});
    final p = path.replaceFirst('/api/v1', '');

    switch (p) {
      case '/system/status':
        return _json({'appName': 'Lidarr', 'version': '2.0.0.0 (demo)'});
      case '/health':
        return _json([
          {
            'type': 'warning',
            'source': 'IndexerStatusCheck',
            'message': 'Demo Indexer unavailable due to failures (sample)',
          },
        ]);
      case '/diskspace':
        return _json([
          {
            'path': '/media/music',
            'label': 'Music',
            'freeSpace': 900000000000,
            'totalSpace': 2000000000000,
          },
        ]);
      case '/rootfolder':
        return _json([
          {'id': 1, 'path': '/media/music', 'freeSpace': 900000000000},
        ]);
      case '/qualityprofile':
        return _json([
          {'id': 1, 'name': 'Lossless'},
          {'id': 2, 'name': 'Standard'},
          {'id': 3, 'name': 'Any'},
        ]);
      case '/metadataprofile':
        return _json([
          {'id': 1, 'name': 'Standard'},
          {'id': 2, 'name': 'None'},
        ]);
      case '/artist':
        if (m == 'POST') {
          final a = {
            ...Map<String, dynamic>.from(body as Map),
            'id': _nextId++,
            'added': _now.toIso8601String(),
            'images': const [],
          };
          _artists.add(a);
          return _json(_artistOut(a), 201);
        }
        return _json(_artists.map(_artistOut).toList());
      case '/artist/lookup':
        final term = (q['term'] ?? '').toLowerCase();
        return _json([
          for (final t in _lookupCatalog)
            if (term.isEmpty ||
                '${t['artistName']}'.toLowerCase().contains(term))
              t,
        ]);
      case '/album':
        final aid = int.tryParse(q['artistId'] ?? '');
        return _json([
          for (final a in _albums)
            if (aid == null || a['artistId'] == aid) _albumOut(a),
        ]);
      case '/track':
        final id = int.tryParse(q['albumId'] ?? '');
        return _json([
          for (final t in _tracks[id] ?? const <Map<String, dynamic>>[])
            {...t}..remove('trackFile'),
        ]);
      case '/trackfile':
        final id = int.tryParse(q['albumId'] ?? '');
        return _json([
          for (final t in _tracks[id] ?? const <Map<String, dynamic>>[])
            if (t['hasFile'] == true) t['trackFile'],
        ]);
      case '/calendar':
        final start = DateTime.parse(q['start']!);
        final end = DateTime.parse(q['end']!);
        final out =
            [
              for (final a in _albums)
                if (!DateTime.parse(
                      a['releaseDate'] as String,
                    ).isBefore(start) &&
                    DateTime.parse(a['releaseDate'] as String).isBefore(end))
                  _albumWithArtist(a),
            ]..sort(
              (a, b) => '${a['releaseDate']}'.compareTo('${b['releaseDate']}'),
            );
        return _json(out);
      case '/history':
        var list = [..._history];
        if (q['albumId'] != null) {
          list = list.where((h) => '${h['albumId']}' == q['albumId']).toList();
        }
        return _json({
          'page': 1,
          'totalRecords': list.length,
          'records': list.map(_withRefs).toList(),
        });
      case '/queue':
        return _json({
          'page': 1,
          'totalRecords': _queue.length,
          'records': _queue,
        });
      case '/wanted/missing':
        final recs = [
          for (final a in _albums)
            if (a['monitored'] == true &&
                DateTime.parse(a['releaseDate'] as String).isBefore(_now) &&
                (_tracks[a['id']] ?? const []).any((t) => t['hasFile'] != true))
              _albumWithArtist(a),
        ];
        return _json({'page': 1, 'totalRecords': recs.length, 'records': recs});
      case '/release':
        if (m == 'POST') return _json({});
        await Future<void>.delayed(const Duration(milliseconds: 900));
        return _json(_releases(int.tryParse(q['albumId'] ?? '') ?? 0));
      case '/command':
        return _json({'id': _nextId++, 'status': 'queued'}, 201);
    }

    final artistMatch = RegExp(r'^/artist/(\d+)$').firstMatch(p);
    if (artistMatch != null) {
      final id = int.parse(artistMatch.group(1)!);
      final idx = _artists.indexWhere((a) => a['id'] == id);
      if (idx < 0) return _json({'message': 'Not found'}, 404);
      if (m == 'DELETE') {
        _artists.removeAt(idx);
        final ids = _albums
            .where((a) => a['artistId'] == id)
            .map((a) => a['id'])
            .toList();
        _albums.removeWhere((a) => a['artistId'] == id);
        for (final i in ids) {
          _tracks.remove(i);
        }
        _queue.removeWhere((e) => e['artistId'] == id);
        return _json({});
      }
      if (m == 'PUT') {
        final b = Map<String, dynamic>.from(body as Map);
        _artists[idx] = {..._artists[idx], 'monitored': b['monitored']};
      }
      return _json(_artistOut(_artists[idx]));
    }

    final albumMatch = RegExp(r'^/album/(\d+)$').firstMatch(p);
    if (albumMatch != null) {
      final id = int.parse(albumMatch.group(1)!);
      final i = _albums.indexWhere((a) => a['id'] == id);
      if (i < 0) return _json({'message': 'Not found'}, 404);
      if (m == 'PUT') {
        _albums[i] = {..._albums[i], 'monitored': (body as Map)['monitored']};
      }
      return _json(_albumWithArtist(_albums[i]));
    }

    final fileMatch = RegExp(r'^/trackfile/(\d+)$').firstMatch(p);
    if (fileMatch != null && m == 'DELETE') {
      final id = int.parse(fileMatch.group(1)!);
      for (final tracks in _tracks.values) {
        for (var i = 0; i < tracks.length; i++) {
          if (tracks[i]['trackFileId'] == id) {
            tracks[i] = {...tracks[i], 'hasFile': false, 'trackFileId': 0}
              ..remove('trackFile');
          }
        }
      }
      return _json({});
    }

    final queueMatch = RegExp(r'^/queue/(\d+)$').firstMatch(p);
    if (queueMatch != null && m == 'DELETE') {
      final id = int.parse(queueMatch.group(1)!);
      _queue.removeWhere((e) => e['id'] == id);
      return _json({});
    }

    return _json({'message': 'Not found'}, 404);
  }

  List<Map<String, dynamic>> _releases(int albumId) => [
    for (final (i, r) in const [
      ('FLAC', 'FLAC', 380000000, 64, 3, <String>[]),
      ('FLAC 24bit-96kHz', 'FLAC 24bit', 1100000000, 21, 9, <String>[]),
      ('MP3 320', 'MP3-320', 110000000, 150, 1, <String>[]),
      (
        'MP3 VBR V0',
        'MP3-VBR-V0',
        95000000,
        0,
        40,
        ['Not an upgrade for existing track file(s)'],
      ),
    ].indexed)
      {
        'guid': 'demo-$albumId-$i',
        'indexerId': 1,
        'indexer': 'Demo Indexer',
        'title': 'Sample.Artist-Sample.Album-WEB-${r.$1.replaceAll(' ', '.')}',
        'size': r.$3,
        'seeders': r.$4,
        'leechers': r.$4 ~/ 4,
        'age': r.$5,
        'ageHours': r.$5 * 24,
        'protocol': 'torrent',
        'quality': {
          'quality': {'id': 6, 'name': r.$2},
        },
        'customFormatScore': 0,
        'rejected': r.$6.isNotEmpty,
        'rejections': r.$6,
      },
  ];

  static final List<Map<String, dynamic>> _lookupCatalog = [
    for (final (i, t) in const [
      ('Copper Sparrow', 'Group', 'A duo mixing banjo and drum loops.'),
      ('Lena Hartmann', 'Person', 'A cellist writing cinematic miniatures.'),
      ('Velvet Circuit', 'Group', 'Retro-futurist funk from the city lights.'),
    ].indexed)
      {
        'artistName': t.$1,
        'sortName': t.$1.toLowerCase(),
        'foreignArtistId': 'demo-lookup-$i',
        'artistType': t.$2,
        'overview': t.$3,
        'status': 'continuing',
        'images': const [],
      },
  ];
}
