import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'settings.dart';

enum ManualSearchStatus { running, done, failed }

/// A manual (interactive) release search that runs in the background, so the
/// user can leave the screen and come back to the results later.
class ManualSearch {
  final int albumId;
  final String label;
  ManualSearchStatus status = ManualSearchStatus.running;
  List<Json> releases = [];
  Object? error;
  ManualSearch(this.albumId, this.label);
}

class AppState extends ChangeNotifier {
  final Map<int, ManualSearch> manualSearches = {};

  /// Starts (or returns the existing) manual search for an album.
  ManualSearch manualSearch(int albumId, String label, {bool restart = false}) {
    final existing = manualSearches[albumId];
    if (existing != null &&
        !restart &&
        existing.status != ManualSearchStatus.failed) {
      return existing;
    }
    final search = ManualSearch(albumId, label);
    manualSearches[albumId] = search;
    final client = api!;
    client
        .releases(albumId)
        .then((r) {
          search.releases = r;
          search.status = ManualSearchStatus.done;
        })
        .catchError((Object e) {
          search.error = e;
          search.status = ManualSearchStatus.failed;
        })
        .whenComplete(notifyListeners);
    notifyListeners();
    return search;
  }

  void clearManualSearch(int albumId) {
    manualSearches.remove(albumId);
    notifyListeners();
  }

  final SettingsStore store;
  ServerConfig? config;
  LidarrApi? api;
  bool loaded = false;

  AppState(this.store);

  Future<void> init() async {
    config = await store.load();
    if (config != null) api = LidarrApi(config!);
    loaded = true;
    notifyListeners();
  }

  Future<void> setConfig(ServerConfig c) async {
    await store.save(c);
    config = await store.load();
    api?.dispose();
    api = config == null ? null : LidarrApi(config!);
    notifyListeners();
  }

  Future<void> reset() async {
    await store.clear();
    final p = await SharedPreferences.getInstance();
    await p.remove(_artistCacheKey);
    manualSearches.clear();
    api?.dispose();
    api = null;
    config = null;
    notifyListeners();
  }

  // Local cache of the artist list so the library opens instantly / offline.
  static const _artistCacheKey = 'cache_artists';

  Future<List<Json>?> cachedArtists() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_artistCacheKey);
    if (s == null) return null;
    try {
      return (jsonDecode(s) as List).map((e) => Json.from(e as Map)).toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> cacheArtists(List<Json> list) async {
    final p = await SharedPreferences.getInstance();
    // Drop bulky fields not needed for the list view.
    final slim = list
        .map(
          (s) => {
            for (final k in [
              'id',
              'artistName',
              'foreignArtistId',
              'status',
              'artistType',
              'monitored',
              'images',
              'statistics',
              'sortName',
              'added',
            ])
              if (s.containsKey(k)) k: s[k],
          },
        )
        .toList();
    await p.setString(_artistCacheKey, jsonEncode(slim));
  }
}
