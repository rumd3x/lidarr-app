import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api.dart';
import '../services/app_state.dart';
import '../widgets/common.dart';

/// True when a queue item is waiting for the user to resolve the import
/// (Lidarr state `importBlocked`/`importPending`, or a warning on a finished
/// download).
bool needsManualImport(Json q) {
  final state = '${q['trackedDownloadState']}';
  final warning = q['trackedDownloadStatus'] == 'warning';
  return q['downloadId'] != null &&
      (state == 'importBlocked' ||
          (warning && (state == 'importPending' || state == 'importFailed')));
}

/// Mobile version of Lidarr's "Interactive Import" for a queue item.
class ManualImportScreen extends StatefulWidget {
  final Json queueItem;
  const ManualImportScreen({super.key, required this.queueItem});

  @override
  State<ManualImportScreen> createState() => _ManualImportScreenState();
}

class _ManualImportScreenState extends State<ManualImportScreen> {
  List<Json>? _files;
  List<Json> _qualities = [];
  final _selected = <int>{};
  Object? _error;
  var _importing = false;

  LidarrApi get _api => context.read<AppState>().api!;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _files = null;
      _error = null;
    });
    try {
      final api = _api;
      final results = await Future.wait([
        api.manualImportCandidates(
          folder: widget.queueItem['outputPath'] as String?,
          downloadId: widget.queueItem['downloadId'] as String?,
        ),
        api.qualityDefinitions(),
      ]);
      final prefill = await _queueMatch(api, results[0]);
      if (!mounted) return;
      setState(() {
        _files = results[0];
        _qualities = [
          for (final d in results[1])
            if (d['quality'] is Map) Json.from(d['quality'] as Map),
        ];
        for (final f in _files!) {
          if (f['artist'] == null && prefill.artist != null) {
            f['artist'] = prefill.artist;
            f['album'] ??= prefill.album;
          }
        }
        _selected
          ..clear()
          ..addAll([
            for (var i = 0; i < _files!.length; i++)
              if (_ready(_files![i])) i,
          ]);
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  /// Artist/album for files Lidarr could not match: the queue item's own,
  /// found by its embedded object, its id, or by parsing the release title.
  Future<({Json? artist, Json? album})> _queueMatch(
    LidarrApi api,
    List<Json> files,
  ) async {
    if (files.every((f) => f['artist'] != null)) {
      return (artist: null, album: null);
    }
    final q = widget.queueItem;
    Json? map(Object? v) => v is Map ? Json.from(v) : null;
    var artist = map(q['artist']);
    var album = map(q['album']);
    try {
      final id = q['artistId'];
      if (artist == null && id is int) {
        artist = (await api.artists()).where((a) => a['id'] == id).firstOrNull;
      }
      if (artist == null) {
        final parsed = await api.parse('${q['title']}');
        artist = map(parsed['artist']);
        final albums = parsed['albums'] as List?;
        if (album == null && albums != null && albums.isNotEmpty) {
          album = map(albums.first);
        }
      }
    } catch (_) {}
    return (artist: artist, album: album);
  }

  /// Lidarr's queue status messages are titled with the file they refer to.
  List<String> _errors(int i, Json f) {
    final msgs = (widget.queueItem['statusMessages'] as List? ?? const [])
        .map((m) => m as Map)
        .toList();
    String base(Object? p) => '$p'.split(RegExp(r'[\\/]')).last.toLowerCase();
    final names = {base(f['name']), base(f['relativePath']), base(f['path'])}
      ..remove('null');
    var mine = [
      for (final m in msgs)
        if (names.contains(base(m['title']))) m,
    ];
    if (mine.isEmpty && msgs.length == _files!.length) mine = [msgs[i]];
    final out = [
      for (final m in mine)
        ...(m['messages'] as List? ?? const []).map((e) => '$e'),
    ];
    if (out.isNotEmpty) return out;
    return [
      for (final r in (f['rejections'] as List? ?? const []))
        '${(r as Map)['reason']}',
    ];
  }

  bool _ready(Json f) =>
      f['artist'] != null &&
      f['album'] != null &&
      ((f['tracks'] as List?)?.isNotEmpty ?? false) &&
      f['quality'] != null;

  /// The album's monitored release, which the tracks belong to.
  Object? _releaseId(Json f) {
    final releases = (f['album'] as Map?)?['releases'] as List?;
    if (releases != null && releases.isNotEmpty) {
      final r = releases.firstWhere(
        (r) => (r as Map)['monitored'] == true,
        orElse: () => releases.first,
      );
      return (r as Map)['id'];
    }
    return f['albumReleaseId'];
  }

  Future<void> _import() async {
    final files = _files!;
    final payload = <Json>[
      for (final i in _selected)
        {
          'path': files[i]['path'],
          'artistId': (files[i]['artist'] as Map)['id'],
          'albumId': (files[i]['album'] as Map)['id'],
          'albumReleaseId': _releaseId(files[i]),
          'trackIds': [
            for (final t in files[i]['tracks'] as List) (t as Map)['id'],
          ],
          'quality': files[i]['quality'],
          'releaseGroup': files[i]['releaseGroup'],
          'downloadId':
              files[i]['downloadId'] ?? widget.queueItem['downloadId'],
          if (files[i]['indexerFlags'] != null)
            'indexerFlags': files[i]['indexerFlags'],
          'disableReleaseSwitching':
              files[i]['disableReleaseSwitching'] ?? false,
        },
    ];
    setState(() => _importing = true);
    try {
      await _api.manualImport(payload);
      if (!mounted) return;
      toast(context, 'Import started');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _importing = false);
        toast(context, '$e');
      }
    }
  }

  Future<void> _pickArtist(Json f) async {
    final all = await _api.artists();
    if (!mounted) return;
    final chosen = await showModalBottomSheet<Json>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ArtistPicker(artists: all),
    );
    if (chosen == null) return;
    setState(() {
      f['artist'] = chosen;
      f['album'] = null;
      f['albumReleaseId'] = null;
      f['tracks'] = <Json>[];
    });
    await _pickAlbum(f);
  }

  Future<void> _pickAlbum(Json f) async {
    final artist = f['artist'] as Map?;
    if (artist == null) return;
    final List<Json> albums;
    try {
      albums = await _api.albums(artist['id'] as int);
    } catch (e) {
      if (mounted) toast(context, '$e');
      return;
    }
    if (!mounted) return;
    final chosen = await showModalBottomSheet<Json>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AlbumPicker(albums: albums),
    );
    if (chosen == null) return;
    setState(() {
      f['album'] = chosen;
      f['albumReleaseId'] = null;
      f['tracks'] = <Json>[];
    });
    await _pickTracks(f);
  }

  Future<void> _pickTracks(Json f) async {
    final album = f['album'] as Map?;
    if (album == null) return;
    final List<Json> tracks;
    try {
      tracks = await _api.tracks(album['id'] as int);
    } catch (e) {
      if (mounted) toast(context, '$e');
      return;
    }
    if (!mounted) return;
    final current = {
      for (final t in (f['tracks'] as List? ?? const [])) (t as Map)['id'],
    };
    final chosen = await showModalBottomSheet<List<Json>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _TrackPicker(tracks: tracks, selectedIds: current),
    );
    if (chosen == null) return;
    setState(() => f['tracks'] = chosen);
  }

  Future<void> _pickQuality(Json f) async {
    final chosen = await showModalBottomSheet<Json>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (_, scroll) => ListView(
          controller: scroll,
          children: [
            ListTile(
              title: Text(
                'Quality',
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            for (final o in _qualities)
              ListTile(
                title: Text('${o['name']}'),
                onTap: () => Navigator.pop(ctx, o),
              ),
          ],
        ),
      ),
    );
    if (chosen == null) return;
    setState(
      () => f['quality'] = {
        'quality': chosen,
        'revision':
            (f['quality'] as Map?)?['revision'] ??
            {'version': 1, 'real': 0, 'isRepack': false},
      },
    );
  }

  String _qualityName(Json f) =>
      (((f['quality'] as Map?)?['quality']) as Map?)?['name']?.toString() ??
      'Unknown';

  String _trackLabel(List<Json> tracks) {
    final nums = [
      for (final t in tracks) '${t['trackNumber'] ?? t['absoluteTrackNumber']}',
    ];
    return nums.length > 4
        ? '${nums.length} tracks'
        : 'Track${nums.length > 1 ? 's' : ''} ${nums.join(', ')}';
  }

  Widget _fileCard(int i, Json f) {
    final theme = Theme.of(context);
    final artist = f['artist'] as Map?;
    final album = f['album'] as Map?;
    final tracks = (f['tracks'] as List? ?? const [])
        .map((e) => Json.from(e as Map))
        .toList();
    final rejections = _errors(i, f);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: _selected.contains(i),
                  onChanged: _ready(f)
                      ? (v) => setState(
                          () => v == true
                              ? _selected.add(i)
                              : _selected.remove(i),
                        )
                      : null,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      '${f['relativePath'] ?? f['name'] ?? f['path']}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (f['size'] != null)
                    Text(
                      formatBytes(f['size'] as num),
                      style: theme.textTheme.labelSmall,
                    ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.person, size: 16),
                        label: Text(
                          '${artist?['artistName'] ?? 'Select artist'}',
                        ),
                        onPressed: () => _pickArtist(f),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.album, size: 16),
                        label: Text('${album?['title'] ?? 'Select album'}'),
                        onPressed: artist == null ? null : () => _pickAlbum(f),
                      ),
                      ActionChip(
                        avatar: const Icon(
                          Icons.format_list_numbered,
                          size: 16,
                        ),
                        label: Text(
                          tracks.isEmpty
                              ? 'Select tracks'
                              : _trackLabel(tracks),
                        ),
                        onPressed: album == null ? null : () => _pickTracks(f),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.high_quality, size: 16),
                        label: Text(_qualityName(f)),
                        onPressed: () => _pickQuality(f),
                      ),
                    ],
                  ),
                  for (final r in rejections)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.warning_amber,
                            size: 14,
                            color: theme.colorScheme.error,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              r,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.queueItem;
    final files = _files;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manual import'),
        actions: [
          IconButton(
            tooltip: 'Reload',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _error != null
          ? ErrorView(error: _error!, onRetry: _load)
          : files == null
          ? const Center(child: CircularProgressIndicator())
          : files.isEmpty
          ? const EmptyView(Icons.folder_off_outlined, 'No files to import')
          : ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 16),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    '${q['title']}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                const SizedBox(height: 8),
                for (var i = 0; i < files.length; i++) _fileCard(i, files[i]),
              ],
            ),
      bottomNavigationBar: files == null || files.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton.icon(
                  onPressed: _selected.isEmpty || _importing ? null : _import,
                  icon: _importing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download_done),
                  label: Text('Import (${_selected.length})'),
                ),
              ),
            ),
    );
  }
}

class _ArtistPicker extends StatefulWidget {
  final List<Json> artists;
  const _ArtistPicker({required this.artists});

  @override
  State<_ArtistPicker> createState() => _ArtistPickerState();
}

class _ArtistPickerState extends State<_ArtistPicker> {
  var _term = '';

  @override
  Widget build(BuildContext context) {
    final list =
        [
          for (final a in widget.artists)
            if ('${a['artistName']}'.toLowerCase().contains(
              _term.toLowerCase(),
            ))
              a,
        ]..sort(
          (a, b) => '${a['sortName'] ?? a['artistName']}'.compareTo(
            '${b['sortName'] ?? b['artistName']}',
          ),
        );
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search artists',
                ),
                onChanged: (v) => setState(() => _term = v),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: list.length,
                itemBuilder: (_, i) => ListTile(
                  title: Text('${list[i]['artistName']}'),
                  onTap: () => Navigator.pop(context, list[i]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String? _date(Json a) {
  final d = a['releaseDate']?.toString();
  return d == null || d.length < 10 ? null : d.substring(0, 10);
}

class _AlbumPicker extends StatelessWidget {
  final List<Json> albums;
  const _AlbumPicker({required this.albums});

  @override
  Widget build(BuildContext context) {
    final list = [...albums]
      ..sort((a, b) => '${b['releaseDate']}'.compareTo('${a['releaseDate']}'));
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: ListView.builder(
        itemCount: list.length,
        itemBuilder: (_, i) => ListTile(
          title: Text('${list[i]['title']}'),
          subtitle: Text(
            [
              if (list[i]['albumType'] != null) '${list[i]['albumType']}',
              ?_date(list[i]),
            ].join(' · '),
          ),
          onTap: () => Navigator.pop(context, list[i]),
        ),
      ),
    );
  }
}

class _TrackPicker extends StatefulWidget {
  final List<Json> tracks;
  final Set<Object?> selectedIds;
  const _TrackPicker({required this.tracks, required this.selectedIds});

  @override
  State<_TrackPicker> createState() => _TrackPickerState();
}

class _TrackPickerState extends State<_TrackPicker> {
  late final Set<Object?> _ids = {...widget.selectedIds};

  @override
  Widget build(BuildContext context) => SizedBox(
    height: MediaQuery.of(context).size.height * 0.75,
    child: Column(
      children: [
        Expanded(
          child: ListView(
            children: [
              for (final t in widget.tracks)
                CheckboxListTile(
                  dense: true,
                  value: _ids.contains(t['id']),
                  title: Text(
                    '${t['trackNumber'] ?? t['absoluteTrackNumber'] ?? ''}. '
                    '${t['title'] ?? ''}',
                  ),
                  subtitle: (t['mediumNumber'] ?? 1) == 1
                      ? null
                      : Text('Disc ${t['mediumNumber']}'),
                  onChanged: (v) => setState(
                    () => v == true ? _ids.add(t['id']) : _ids.remove(t['id']),
                  ),
                ),
            ],
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, [
                  for (final t in widget.tracks)
                    if (_ids.contains(t['id'])) t,
                ]),
                child: Text('Done (${_ids.length})'),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
