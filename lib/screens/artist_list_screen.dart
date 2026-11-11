import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api.dart';
import '../services/app_state.dart';
import '../widgets/common.dart';
import 'add_artist_screen.dart';
import 'artist_detail_screen.dart';

class ArtistListScreen extends StatefulWidget {
  const ArtistListScreen({super.key});

  @override
  State<ArtistListScreen> createState() => _ArtistListScreenState();
}

enum _Filter { all, monitored, continuing, ended }

class _ArtistListScreenState extends State<ArtistListScreen> {
  List<Json> _all = [];
  bool _loading = true;
  Object? _error;
  String _query = '';
  bool _searching = false;
  bool _grid = true;
  _Filter _filter = _Filter.all;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final state = context.read<AppState>();
    final cached = await state.cachedArtists();
    if (cached != null && mounted) {
      setState(() {
        _all = cached;
        _loading = false;
      });
    }
    await _refresh();
  }

  Future<void> _refresh() async {
    final state = context.read<AppState>();
    try {
      final list = await state.api!.artists();
      state.cacheArtists(list);
      if (!mounted) return;
      setState(() {
        _all = list;
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

  List<Json> get _visible {
    final q = _query.toLowerCase();
    final list = _all.where((s) {
      if (q.isNotEmpty && !('${s['artistName']}'.toLowerCase().contains(q))) {
        return false;
      }
      switch (_filter) {
        case _Filter.all:
          return true;
        case _Filter.monitored:
          return s['monitored'] == true;
        case _Filter.continuing:
          return s['status'] == 'continuing';
        case _Filter.ended:
          return s['status'] == 'ended';
      }
    }).toList();
    list.sort(
      (a, b) => '${a['sortName'] ?? a['artistName']}'.toLowerCase().compareTo(
        '${b['sortName'] ?? b['artistName']}'.toLowerCase(),
      ),
    );
    return list;
  }

  Future<void> _open(Json s) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ArtistDetailScreen(artist: s)),
    );
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final items = _visible;
    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Filter library…',
                  border: InputBorder.none,
                ),
                onChanged: (v) => setState(() => _query = v),
              )
            : Text('Artists (${_all.length})'),
        actions: [
          IconButton(
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) _query = '';
            }),
          ),
          IconButton(
            icon: Icon(_grid ? Icons.view_list : Icons.grid_view),
            onPressed: () => setState(() => _grid = !_grid),
          ),
          PopupMenuButton<_Filter>(
            icon: const Icon(Icons.filter_list),
            initialValue: _filter,
            onSelected: (f) => setState(() => _filter = f),
            itemBuilder: (_) => const [
              PopupMenuItem(value: _Filter.all, child: Text('All')),
              PopupMenuItem(value: _Filter.monitored, child: Text('Monitored')),
              PopupMenuItem(
                value: _Filter.continuing,
                child: Text('Continuing'),
              ),
              PopupMenuItem(value: _Filter.ended, child: Text('Ended')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Add'),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddArtistScreen()),
          );
          _refresh();
        },
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_error != null && _all.isEmpty)
          ? ErrorView(error: _error!, onRetry: _refresh)
          : RefreshIndicator(
              onRefresh: _refresh,
              child: items.isEmpty
                  ? const EmptyView(
                      Icons.library_music_outlined,
                      'No artists found',
                    )
                  : _grid
                  ? _buildGrid(items)
                  : _buildList(items),
            ),
    );
  }

  Widget _buildGrid(List<Json> items) => GridView.builder(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: 160,
      childAspectRatio: 0.8,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
    ),
    itemCount: items.length,
    itemBuilder: (_, i) {
      final s = items[i];
      return GestureDetector(
        onTap: () => _open(s),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Poster(s),
              Positioned(
                left: 0,
                right: 0,
                bottom: 5,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(8, 14, 8, 6),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black87],
                    ),
                  ),
                  child: Text(
                    '${s['artistName']}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _ProgressBar(s, thick: true),
              ),
              if (s['monitored'] != true)
                const Positioned(
                  top: 6,
                  right: 6,
                  child: Icon(
                    Icons.bookmark_border,
                    size: 20,
                    color: Colors.white70,
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );

  Widget _buildList(List<Json> items) => ListView.builder(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
    itemCount: items.length,
    itemBuilder: (_, i) {
      final s = items[i];
      final st = s['statistics'] as Map? ?? {};
      return Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _open(s),
          child: Row(
            children: [
              SizedBox(width: 80, height: 80, child: Poster(s)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${s['artistName']}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${s['artistType'] ?? ''}'
                        '${(s['artistType'] ?? '').toString().isEmpty ? '' : ' · '}'
                        '${st['albumCount'] ?? 0} albums',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      _ProgressBar(s),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _ProgressBar extends StatelessWidget {
  final Json artist;
  final bool thick;
  const _ProgressBar(this.artist, {this.thick = false});

  @override
  Widget build(BuildContext context) {
    final st = artist['statistics'] as Map? ?? {};
    final total = (st['trackCount'] as num?) ?? 0;
    final have = (st['trackFileCount'] as num?) ?? 0;
    final complete = total > 0 && have >= total;
    final cs = Theme.of(context).colorScheme;
    final color = complete
        ? (artist['status'] == 'ended' ? Colors.green : cs.primary)
        : (artist['monitored'] == true ? Colors.redAccent : Colors.grey);
    final bar = LinearProgressIndicator(
      value: total == 0 ? 0 : have / total,
      minHeight: thick ? 5 : 6,
      color: color,
      backgroundColor: Colors.black38,
    );
    if (thick) return bar;
    return Row(
      children: [
        Expanded(
          child: ClipRRect(borderRadius: BorderRadius.circular(4), child: bar),
        ),
        const SizedBox(width: 8),
        Text('$have/$total', style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
