import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/api.dart';
import '../services/app_state.dart';
import '../widgets/common.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Activity'),
        bottom: const TabBar(
          tabs: [
            Tab(text: 'Queue'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: const TabBarView(children: [_QueueTab(), _HistoryTab()]),
    ),
  );
}

class _QueueTab extends StatefulWidget {
  const _QueueTab();

  @override
  State<_QueueTab> createState() => _QueueTabState();
}

class _QueueTabState extends State<_QueueTab>
    with AutomaticKeepAliveClientMixin {
  final _key = GlobalKey<AsyncBodyState<List<Json>>>();

  @override
  bool get wantKeepAlive => true;

  Future<void> _remove(Json item) async {
    var blocklist = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Remove from queue?'),
          content: CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: blocklist,
            onChanged: (v) => setD(() => blocklist = v ?? false),
            title: const Text('Blocklist release'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remove'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<AppState>().api!.removeQueueItem(
        item['id'] as int,
        blocklist: blocklist,
      );
      _key.currentState?.reload();
    } catch (e) {
      if (mounted) toast(context, '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return AsyncBody<List<Json>>(
      key: _key,
      load: (api) => api.queue(),
      builder: (context, list) {
        if (list.isEmpty) {
          return const EmptyView(Icons.downloading_outlined, 'Queue is empty');
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: list.length,
          itemBuilder: (_, i) {
            final q = list[i];
            final size = (q['size'] as num?) ?? 0;
            final left = (q['sizeleft'] as num?) ?? 0;
            final progress = size > 0 ? (size - left) / size : 0.0;
            final album = Json.from((q['album'] as Map?) ?? {});
            final artist = Json.from((q['artist'] as Map?) ?? {});
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${artist['artistName'] ?? q['title']}'
                            '${album.isNotEmpty ? ' · ${album['title']}' : ''}',
                            style: Theme.of(context).textTheme.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.close),
                          onPressed: () => _remove(q),
                        ),
                      ],
                    ),
                    Text(
                      '${q['title']}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress.toDouble(),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      [
                        '${q['status']}',
                        '${(progress * 100).toStringAsFixed(0)}%',
                        if (size > 0)
                          '${formatBytes(size - left)} / ${formatBytes(size)}',
                        if (q['timeleft'] != null) '${q['timeleft']}',
                        if (q['downloadClient'] != null)
                          '${q['downloadClient']}',
                      ].join(' · '),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _HistoryTab extends StatelessWidget {
  const _HistoryTab();

  IconData _icon(String? t) => switch (t) {
    'grabbed' => Icons.cloud_download,
    'downloadImported' || 'trackFileImported' => Icons.download_done,
    'downloadFailed' => Icons.error_outline,
    'trackFileDeleted' => Icons.delete_outline,
    'trackFileRenamed' => Icons.drive_file_rename_outline,
    _ => Icons.history,
  };

  @override
  Widget build(BuildContext context) => AsyncBody<List<Json>>(
    load: (api) => api.history(),
    builder: (context, list) {
      if (list.isEmpty) return const EmptyView(Icons.history, 'No history yet');
      return ListView.builder(
        itemCount: list.length,
        itemBuilder: (_, i) {
          final h = list[i];
          final artist = Json.from((h['artist'] as Map?) ?? {});
          final album = Json.from((h['album'] as Map?) ?? {});
          final date = DateTime.tryParse('${h['date']}')?.toLocal();
          return ListTile(
            leading: Icon(_icon(h['eventType'] as String?)),
            title: Text(
              '${artist['artistName'] ?? h['sourceTitle']}'
              '${album.isNotEmpty ? ' · ${album['title']}' : ''}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${h['sourceTitle']}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: date == null
                ? null
                : Text(
                    DateFormat('MMM d\nHH:mm').format(date),
                    textAlign: TextAlign.end,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
          );
        },
      );
    },
  );
}
