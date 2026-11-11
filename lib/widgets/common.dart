import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api.dart';
import '../services/app_state.dart';
import '../screens/album_detail_screen.dart';

String? imageUrl(LidarrApi api, Json item, [String type = 'poster']) {
  final images = item['images'];
  if (images is! List) return null;
  for (final i in images) {
    if (i is Map && i['coverType'] == type) {
      final remote = i['remoteUrl'] as String?;
      if (remote != null && remote.isNotEmpty) return remote;
      final url = i['url'] as String?;
      if (url != null && url.isNotEmpty) return api.assetUrl(url);
    }
  }
  return null;
}

class Poster extends StatelessWidget {
  final Json item;
  final String type;
  final double? width;
  final double? height;
  const Poster(
    this.item, {
    super.key,
    this.type = 'poster',
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final api = state.api!;
    // Artists embedded in albums (calendar, wanted) may come without images;
    // an album without images falls back to its artist's.
    final artistId = type == 'cover'
        ? ((item['artist'] as Map?)?['id'] ?? item['artistId'])
        : item['id'];
    if (!api.isDemo && item['images'] is! List && artistId is int) {
      return FutureBuilder<Map<int, List>>(
        future: state.artistImages(),
        builder: (context, snap) => Poster(
          {...item, 'images': snap.data?[artistId] ?? const []},
          type: type,
          width: width,
          height: height,
        ),
      );
    }
    final url =
        imageUrl(api, item, type) ??
        (type == 'cover' ? imageUrl(api, item, 'poster') : null);
    final cs = Theme.of(context).colorScheme;
    final placeholder = Container(
      width: width,
      height: height,
      color: cs.surfaceContainerHighest,
      child: Icon(
        type == 'cover' ? Icons.album : Icons.person,
        color: cs.onSurfaceVariant,
      ),
    );
    if (api.isDemo) return _DemoPoster(item, width, height, type != 'fanart');
    if (url == null) return placeholder;
    return CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: BoxFit.cover,
      placeholder: (_, _) => placeholder,
      errorWidget: (_, _, _) => placeholder,
    );
  }
}

class ErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  const ErrorView({super.key, required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off, size: 48),
          const SizedBox(height: 12),
          Text('$error', textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton.tonal(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    ),
  );
}

class EmptyView extends StatelessWidget {
  final IconData icon;
  final String text;
  const EmptyView(this.icon, this.text, {super.key});

  @override
  Widget build(BuildContext context) => ListView(
    children: [
      SizedBox(
        height: 360,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 56, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(text),
          ],
        ),
      ),
    ],
  );
}

/// Loads data with pull-to-refresh, loading and error states.
class AsyncBody<T> extends StatefulWidget {
  final Future<T> Function(LidarrApi api) load;
  final Widget Function(BuildContext context, T data) builder;
  const AsyncBody({super.key, required this.load, required this.builder});

  @override
  State<AsyncBody<T>> createState() => AsyncBodyState<T>();
}

class AsyncBodyState<T> extends State<AsyncBody<T>> {
  T? _data;
  Object? _error;
  var _loaded = false;
  var _token = 0;

  @override
  void initState() {
    super.initState();
    reload();
  }

  /// Reloads the data. A [silent] reload keeps showing the current content
  /// (no spinner, errors ignored) — used for background refreshes.
  Future<void> reload({bool silent = false}) async {
    final token = ++_token;
    if (!silent || !_loaded) {
      setState(() {
        _loaded = false;
        _error = null;
      });
    }
    try {
      final data = await widget.load(context.read<AppState>().api!);
      if (!mounted || token != _token) return;
      setState(() {
        _data = data;
        _error = null;
        _loaded = true;
      });
    } catch (e) {
      if (!mounted || token != _token || (silent && _data != null)) return;
      setState(() {
        _error = e;
        _loaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Center(child: CircularProgressIndicator());
    if (_error != null) return ErrorView(error: _error!, onRetry: reload);
    return RefreshIndicator(
      onRefresh: reload,
      child: widget.builder(context, _data as T),
    );
  }
}

void toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}

String formatBytes(num bytes) {
  const u = ['B', 'KB', 'MB', 'GB', 'TB'];
  var v = bytes.toDouble();
  var i = 0;
  while (v >= 1024 && i < u.length - 1) {
    v /= 1024;
    i++;
  }
  return '${v.toStringAsFixed(i == 0 ? 0 : 1)} ${u[i]}';
}

void openAlbum(
  BuildContext context,
  Json album,
  String artistName, {
  int tab = 0,
}) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => AlbumDetailScreen(
        album: album,
        artistName: artistName,
        initialTab: tab,
      ),
    ),
  );
}

class ManualSearchButton extends StatelessWidget {
  final Json album;
  final String artistName;
  const ManualSearchButton({
    super.key,
    required this.album,
    required this.artistName,
  });

  @override
  Widget build(BuildContext context) {
    final search = context.watch<AppState>().manualSearches[album['id']];
    final running = search?.status == ManualSearchStatus.running;
    final ready = search?.status == ManualSearchStatus.done;
    return IconButton(
      tooltip: 'Manual search',
      onPressed: () => openAlbum(context, album, artistName, tab: 2),
      icon: running
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Badge(
              isLabelVisible: ready,
              smallSize: 8,
              child: const Icon(Icons.manage_search, size: 22),
            ),
    );
  }
}

String formatDuration(num? ms) {
  if (ms == null || ms <= 0) return '';
  final s = (ms / 1000).round();
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

/// Poster stand-in for demo mode, where there are no remote images.
class _DemoPoster extends StatelessWidget {
  final Json item;
  final double? width;
  final double? height;
  final bool showTitle;
  const _DemoPoster(this.item, this.width, this.height, this.showTitle);

  @override
  Widget build(BuildContext context) {
    final title = '${item['artistName'] ?? item['title'] ?? '?'}';
    final big = (height ?? 120) > 100;
    final initials = title
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();
    final hue = (title.codeUnits.fold<int>(0, (a, b) => a * 31 + b) % 360)
        .toDouble();
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            HSLColor.fromAHSL(1, hue, 0.55, 0.38).toColor(),
            HSLColor.fromAHSL(1, (hue + 40) % 360, 0.6, 0.18).toColor(),
          ],
        ),
      ),
      child: !showTitle
          ? null
          : Padding(
              padding: const EdgeInsets.all(6),
              child: Text(
                initials,
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.92),
                  fontSize: big ? 44 : 22,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
            ),
    );
  }
}
