import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/api.dart';
import '../services/app_state.dart';
import '../widgets/common.dart';
import 'manual_search_screen.dart';

/// Album screen with three tabs: Details, History and Manual search.
class AlbumDetailScreen extends StatefulWidget {
  final Json album;
  final String artistName;
  final int initialTab;
  const AlbumDetailScreen({
    super.key,
    required this.album,
    required this.artistName,
    this.initialTab = 0,
  });

  @override
  State<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends State<AlbumDetailScreen> {
  late Json _album = widget.album;
  final _detailsKey = GlobalKey<AsyncBodyState<_AlbumData>>();

  int get _id => _album['id'] as int;
  String get _label => '${widget.artistName} · ${_album['title']}';
  LidarrApi get _api => context.read<AppState>().api!;

  Future<void> _run(Future<void> Function() action, String ok) async {
    try {
      await action();
      if (mounted) toast(context, ok);
    } catch (e) {
      if (mounted) toast(context, '$e');
    }
  }

  Future<void> _toggleMonitor(Json current) async {
    try {
      final r = await _api.updateAlbum({
        ...current,
        'monitored': !(current['monitored'] == true),
      });
      setState(() => _album = {..._album, 'monitored': r['monitored']});
      _detailsKey.currentState?.reload();
    } catch (e) {
      if (mounted) toast(context, '$e');
    }
  }

  Future<void> _deleteFile(int fileId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete track file?'),
        content: const Text('The file will be removed from disk.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() async {
      await _api.deleteTrackFile(fileId);
      _detailsKey.currentState?.reload();
    }, 'File deleted');
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 3,
    initialIndex: widget.initialTab,
    child: Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_album['title'] ?? 'Unknown'}',
              style: const TextStyle(fontSize: 18),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              _label,
              style: Theme.of(context).textTheme.labelSmall,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        bottom: const TabBar(
          tabs: [
            Tab(text: 'Details'),
            Tab(text: 'History'),
            Tab(text: 'Search'),
          ],
        ),
      ),
      body: TabBarView(
        children: [
          AsyncBody<_AlbumData>(
            key: _detailsKey,
            load: (api) async {
              final r = await Future.wait([
                api.albumById(_id),
                api.tracks(_id),
                api.trackFiles(_id),
              ]);
              return _AlbumData(
                r[0] as Json,
                r[1] as List<Json>,
                r[2] as List<Json>,
              );
            },
            builder: (context, d) => _details(d),
          ),
          AsyncBody<List<Json>>(
            load: (api) => api.albumHistory(_id),
            builder: (context, list) => _history(list),
          ),
          ManualSearchView(albumId: _id, label: _label),
        ],
      ),
    ),
  );

  Widget _details(_AlbumData d) {
    final cs = Theme.of(context).colorScheme;
    final al = d.album;
    final date = DateTime.tryParse('${al['releaseDate']}')?.toLocal();
    final monitored = al['monitored'] == true;
    final st = al['statistics'] as Map? ?? {};
    final filesById = {for (final f in d.files) f['id']: f};
    final genres = (al['genres'] as List? ?? []).join(', ');
    final tracks = [...d.tracks]
      ..sort((a, b) {
        final m = ((a['mediumNumber'] as num?) ?? 1).compareTo(
          (b['mediumNumber'] as num?) ?? 1,
        );
        if (m != 0) return m;
        return ((a['absoluteTrackNumber'] as num?) ?? 0).compareTo(
          (b['absoluteTrackNumber'] as num?) ?? 0,
        );
      });
    final multiDisc = tracks.any((t) => ((t['mediumNumber'] as num?) ?? 1) > 1);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 110,
                height: 110,
                child: Poster(al, type: 'cover'),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if ('${al['albumType'] ?? ''}'.isNotEmpty)
                    Chip(label: Text('${al['albumType']}')),
                  if (date != null)
                    Chip(label: Text(DateFormat.yMMMd().format(date))),
                  Chip(
                    label: Text(
                      '${st['trackFileCount'] ?? 0}/${st['trackCount'] ?? 0} tracks',
                    ),
                  ),
                  if ((st['sizeOnDisk'] as num?) != null &&
                      (st['sizeOnDisk'] as num) > 0)
                    Chip(label: Text(formatBytes(st['sizeOnDisk'] as num))),
                  if (genres.isNotEmpty) Chip(label: Text(genres)),
                ],
              ),
            ),
          ],
        ),
        if ('${al['overview'] ?? ''}'.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            '${al['overview']}',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _toggleMonitor(al),
                icon: Icon(monitored ? Icons.bookmark : Icons.bookmark_border),
                label: Text(monitored ? 'Monitored' : 'Unmonitored'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: () =>
                    _run(() => _api.searchAlbums([_id]), 'Search started'),
                icon: const Icon(Icons.search),
                label: const Text('Auto search'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _title('Tracks (${tracks.length})'),
        if (tracks.isEmpty)
          const Card(
            child: ListTile(
              leading: Icon(Icons.music_note_outlined),
              title: Text('No tracks'),
            ),
          )
        else
          Card(
            child: Column(
              children: [
                for (final t in tracks)
                  _trackTile(t, filesById[t['trackFileId']], multiDisc),
              ],
            ),
          ),
        const SizedBox(height: 20),
        _title('Files'),
        if (d.files.isEmpty)
          const Card(
            child: ListTile(
              leading: Icon(Icons.insert_drive_file_outlined),
              title: Text('No files'),
              subtitle: Text(
                'Use Auto search or the Search tab to find a release.',
              ),
            ),
          )
        else
          for (final f in d.files) _fileCard(f),
      ],
    );
  }

  Widget _title(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
  );

  Widget _trackTile(Json t, Json? file, bool multiDisc) {
    final hasFile = t['hasFile'] == true;
    final quality = (file?['quality'] as Map?)?['quality']?['name'];
    final number = multiDisc
        ? '${t['mediumNumber']}.${t['trackNumber']}'
        : '${t['trackNumber']}';
    return ListTile(
      dense: true,
      leading: Icon(
        hasFile ? Icons.check_circle : Icons.circle_outlined,
        color: hasFile ? Colors.green : Colors.grey,
      ),
      title: Text(
        '$number. ${t['title']}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: quality == null ? null : Text('$quality'),
      trailing: Text(
        formatDuration(t['duration'] as num?),
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }

  Widget _fileCard(Json f) {
    final media = f['mediaInfo'] is Map
        ? Json.from(f['mediaInfo'] as Map)
        : <String, dynamic>{};
    final quality = (f['quality'] as Map?)?['quality']?['name'];
    final added = DateTime.tryParse('${f['dateAdded']}')?.toLocal();
    final bitrate = media['audioBitRate'];
    final rate = media['audioSampleRate'];
    final rows = <(String, String)>[
      ('Path', '${f['path'] ?? f['relativePath'] ?? ''}'),
      if (quality != null) ('Quality', '$quality'),
      ('Size', formatBytes((f['size'] as num?) ?? 0)),
      if ('${f['releaseGroup'] ?? ''}'.isNotEmpty)
        ('Release group', '${f['releaseGroup']}'),
      if (media['audioCodec'] != null)
        (
          'Audio',
          [
            '${media['audioCodec']}',
            if (media['audioBits'] != null) '${media['audioBits']}',
            if (rate != null) '$rate',
            if (bitrate != null) '$bitrate',
            if (media['audioChannels'] != null) '${media['audioChannels']}ch',
          ].join(' · '),
        ),
      if (added != null) ('Added', DateFormat.yMMMd().add_jm().format(added)),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final r in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 104,
                      child: Text(
                        r.$1,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                    Expanded(child: SelectableText(r.$2)),
                  ],
                ),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _deleteFile(f['id'] as int),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete file'),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const _events = {
    'grabbed': ('Grabbed', Icons.cloud_download),
    'downloadImported': ('Imported', Icons.download_done),
    'trackFileImported': ('Imported', Icons.download_done),
    'albumImportIncomplete': ('Import incomplete', Icons.warning_amber),
    'downloadFailed': ('Download failed', Icons.error_outline),
    'trackFileDeleted': ('File deleted', Icons.delete_outline),
    'trackFileRenamed': ('Renamed', Icons.drive_file_rename_outline),
    'trackFileRetagged': ('Retagged', Icons.label_outline),
    'downloadIgnored': ('Ignored', Icons.block),
  };

  Widget _history(List<Json> list) {
    if (list.isEmpty) {
      return const EmptyView(Icons.history, 'No history for this album');
    }
    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (_, i) {
        final h = list[i];
        final ev =
            _events['${h['eventType']}'] ??
            ('${h['eventType']}', Icons.history);
        final date = DateTime.tryParse('${h['date']}')?.toLocal();
        final quality = (h['quality'] as Map?)?['quality']?['name'];
        final data = h['data'] is Map ? h['data'] as Map : const {};
        return ListTile(
          leading: Icon(ev.$2),
          title: Text(ev.$1),
          subtitle: Text(
            [
              '${h['sourceTitle'] ?? ''}',
              if (quality != null) '$quality',
              if (data['indexer'] != null) '${data['indexer']}',
              if (data['downloadClientName'] != null)
                '${data['downloadClientName']}',
            ].join('\n'),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
          isThreeLine: true,
          trailing: date == null
              ? null
              : Text(
                  DateFormat('MMM d, y\nHH:mm').format(date),
                  textAlign: TextAlign.end,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
        );
      },
    );
  }
}

class _AlbumData {
  final Json album;
  final List<Json> tracks;
  final List<Json> files;
  const _AlbumData(this.album, this.tracks, this.files);
}
