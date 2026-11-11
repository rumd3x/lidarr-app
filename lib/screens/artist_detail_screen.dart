import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/api.dart';
import '../services/app_state.dart';
import '../widgets/common.dart';

class ArtistDetailScreen extends StatefulWidget {
  final Json artist;
  const ArtistDetailScreen({super.key, required this.artist});

  @override
  State<ArtistDetailScreen> createState() => _ArtistDetailScreenState();
}

class _ArtistDetailScreenState extends State<ArtistDetailScreen> {
  late Json _artist;
  List<Json> _albums = [];
  bool _loading = true;
  Object? _error;

  LidarrApi get _api => context.read<AppState>().api!;

  @override
  void initState() {
    super.initState();
    _artist = widget.artist;
    _load();
  }

  Future<void> _load() async {
    try {
      final id = _artist['id'] as int;
      final results = await Future.wait([_api.artistById(id), _api.albums(id)]);
      if (!mounted) return;
      setState(() {
        _artist = results[0] as Json;
        _albums = results[1] as List<Json>;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _run(Future<void> Function() action, String ok) async {
    try {
      await action();
      if (mounted) toast(context, ok);
    } catch (e) {
      if (mounted) toast(context, '$e');
    }
  }

  Future<void> _toggleArtist() async {
    final updated = {..._artist, 'monitored': !(_artist['monitored'] == true)};
    await _run(
      () async {
        final r = await _api.updateArtist(updated);
        setState(() => _artist = r);
      },
      updated['monitored'] == true ? 'Monitoring artist' : 'Artist unmonitored',
    );
  }

  Future<void> _toggleAlbum(Json e) async {
    final updated = {...e, 'monitored': !(e['monitored'] == true)};
    try {
      final r = await _api.updateAlbum(updated);
      setState(() {
        final i = _albums.indexWhere((x) => x['id'] == e['id']);
        if (i >= 0) {
          _albums[i] = {..._albums[i], 'monitored': r['monitored']};
        }
      });
    } catch (err) {
      if (mounted) toast(context, '$err');
    }
  }

  Future<void> _delete() async {
    var deleteFiles = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text('Delete ${_artist['artistName']}?'),
          content: CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: deleteFiles,
            onChanged: (v) => setD(() => deleteFiles = v ?? false),
            title: const Text('Also delete files from disk'),
          ),
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
      ),
    );
    if (ok != true) return;
    try {
      await _api.deleteArtist(_artist['id'] as int, deleteFiles: deleteFiles);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) toast(context, '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final id = _artist['id'] as int;
    final st = _artist['statistics'] as Map? ?? {};
    final albums = [..._albums]
      ..sort((a, b) => '${b['releaseDate']}'.compareTo('${a['releaseDate']}'));
    final monitored = _artist['monitored'] == true;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 240,
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  '${_artist['artistName']}',
                  style: const TextStyle(shadows: [Shadow(blurRadius: 8)]),
                ),
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    Poster(_artist, type: 'fanart'),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black87],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                IconButton(
                  tooltip: monitored ? 'Unmonitor' : 'Monitor',
                  icon: Icon(
                    monitored ? Icons.bookmark : Icons.bookmark_border,
                  ),
                  onPressed: _toggleArtist,
                ),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    switch (v) {
                      case 'refresh':
                        _run(() => _api.refreshArtist(id), 'Refresh queued');
                      case 'search':
                        _run(() => _api.searchArtist(id), 'Search started');
                      case 'delete':
                        _delete();
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'refresh',
                      child: Text('Refresh & scan'),
                    ),
                    PopupMenuItem(
                      value: 'search',
                      child: Text('Search all monitored'),
                    ),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if ('${_artist['artistType'] ?? ''}'.isNotEmpty)
                          Chip(label: Text('${_artist['artistType']}')),
                        Chip(label: Text(_cap('${_artist['status']}'))),
                        Chip(label: Text('${st['albumCount'] ?? 0} albums')),
                        Chip(
                          label: Text(
                            '${st['trackFileCount'] ?? 0}/${st['trackCount'] ?? 0} tracks',
                          ),
                        ),
                        if ((st['sizeOnDisk'] as num?) != null)
                          Chip(
                            label: Text(formatBytes(st['sizeOnDisk'] as num)),
                          ),
                      ],
                    ),
                    if ('${_artist['overview'] ?? ''}'.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        '${_artist['overview']}',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    ],
                    if ('${_artist['path'] ?? ''}'.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.folder_outlined, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${_artist['path']}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (_loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: ErrorView(error: _error!, onRetry: _load),
              )
            else
              SliverList.list(
                children: [
                  for (final a in albums) _albumTile(a),
                  const SizedBox(height: 32),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  Widget _albumTile(Json a) {
    final st = a['statistics'] as Map? ?? {};
    final have = (st['trackFileCount'] as num?) ?? 0;
    final total = (st['trackCount'] as num?) ?? 0;
    final date = DateTime.tryParse('${a['releaseDate']}')?.toLocal();
    final released = date != null && date.isBefore(DateTime.now());
    final complete = total > 0 && have >= total;
    final color = complete
        ? Colors.green
        : (released && a['monitored'] == true ? Colors.redAccent : Colors.grey);
    return ListTile(
      onTap: () => openAlbum(context, a, '${_artist['artistName']}'),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(width: 48, height: 48, child: Poster(a, type: 'cover')),
      ),
      title: Text(
        '${a['title']}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Row(
        children: [
          Icon(
            complete ? Icons.check_circle : Icons.circle_outlined,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              [
                if (a['albumType'] != null) '${a['albumType']}',
                if (date != null) DateFormat.yMMM().format(date),
                '$have/$total',
              ].join(' · '),
            ),
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Automatic search',
            icon: const Icon(Icons.search, size: 20),
            onPressed: () => _run(
              () => _api.searchAlbums([a['id'] as int]),
              'Search started',
            ),
          ),
          ManualSearchButton(album: a, artistName: '${_artist['artistName']}'),
          IconButton(
            icon: Icon(
              a['monitored'] == true ? Icons.bookmark : Icons.bookmark_border,
              size: 20,
            ),
            onPressed: () => _toggleAlbum(a),
          ),
        ],
      ),
    );
  }
}
