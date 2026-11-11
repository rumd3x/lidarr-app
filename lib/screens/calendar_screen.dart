import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/api.dart';
import '../widgets/common.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final _key = GlobalKey<AsyncBodyState<List<Json>>>();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Calendar'),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () => _key.currentState?.reload(),
        ),
      ],
    ),
    body: AsyncBody<List<Json>>(
      key: _key,
      load: (api) {
        final today = DateTime.now();
        final start = DateTime(today.year, today.month, today.day);
        return api.calendar(
          start.subtract(const Duration(days: 3)),
          start.add(const Duration(days: 30)),
        );
      },
      builder: (context, list) {
        if (list.isEmpty) {
          return const EmptyView(
            Icons.calendar_month_outlined,
            'Nothing scheduled',
          );
        }
        final byDay = <DateTime, List<Json>>{};
        for (final e in list) {
          final d = DateTime.tryParse('${e['releaseDate']}')?.toLocal();
          if (d == null) continue;
          byDay.putIfAbsent(DateTime(d.year, d.month, d.day), () => []).add(e);
        }
        final days = byDay.keys.toList()..sort();
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            for (final day in days) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  day == today
                      ? 'Today'
                      : DateFormat('EEEE, MMM d').format(day),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: day == today
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                ),
              ),
              for (final e in byDay[day]!) AlbumCard(e),
            ],
          ],
        );
      },
    ),
  );
}

/// Card for an album that carries an embedded `artist` object.
class AlbumCard extends StatelessWidget {
  final Json album;
  final Widget? trailing;
  final String? extra;
  const AlbumCard(this.album, {super.key, this.trailing, this.extra});

  @override
  Widget build(BuildContext context) {
    final artist = Json.from((album['artist'] as Map?) ?? {});
    final date = DateTime.tryParse('${album['releaseDate']}')?.toLocal();
    final st = album['statistics'] as Map? ?? {};
    final have = (st['trackFileCount'] as num?) ?? 0;
    final total = (st['trackCount'] as num?) ?? 0;
    final complete = total > 0 && have >= total;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openAlbum(context, album, '${artist['artistName'] ?? ''}'),
        child: Row(
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: Poster(album, type: 'cover'),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${album['title'] ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      '${artist['artistName'] ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (album['albumType'] != null) '${album['albumType']}',
                        if (date != null) DateFormat.yMMMd().format(date),
                        ?extra,
                      ].join(' · '),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ),
            trailing ??
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Icon(
                    complete ? Icons.check_circle : Icons.schedule,
                    color: complete ? Colors.green : Colors.grey,
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
