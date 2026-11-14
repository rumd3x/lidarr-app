# Features

Navigation: bottom bar with **Artists · Calendar · Activity · Wanted · More**. Lidarr API is `v1`; main entity mapping from the Sonarr app: series → artist, episode → album (tracks are listed inside the album screen). The Activity item shows a badge with the number of queue items (hidden when 0); it refreshes every 30 s while the app is in the foreground, on resume, and whenever the queue is loaded (`AppState.refreshQueueCount()`, `GET /queue/status` → `totalCount`).

## Setup / Connection (`setup_screen.dart`)
- Official Lidarr logo header, primary URL, secondary URL (fallback), API key (hidden, toggle visibility).
- URLs are normalized (adds `http://`, strips trailing `/`) and validated.
- **Try demo** button: runs the whole app against a built-in fake Lidarr (`services/demo_client.dart`) with sample artists, albums, tracks, queue, calendar, history and releases. No network or credentials; edits are kept in memory only. "Disconnect & clear data" leaves demo mode.
- Connection test (`GET /system/status`) before saving. Same screen is reused (editing mode) from More → Connection settings.

## Artists (`artist_list_screen.dart`)
- Library as artist grid (name overlay) or list (toggle); track progress bar per artist (green = complete/ended, primary = complete/continuing, red = missing monitored, grey = unmonitored).
- Text filter, status filter (All / Monitored / Continuing / Ended), pull-to-refresh.
- Cache-first: cached list shows instantly, then refreshes from the server.
- `GET /artist`

## Artist detail (`artist_detail_screen.dart`)
- Fanart header, chips (type, status, albums, tracks, size on disk), overview, path.
- Monitor/unmonitor artist and per album.
- Search: whole artist or a single album (automatic). Refresh & scan. Delete (optionally with files).
- Album list sorted by release date (newest first) with cover, type, date, track progress, auto search, manual search and monitor toggle. Tap an album for the **album detail**.
- `GET/PUT/DELETE /artist/{id}`, `GET /album?artistId=`, `PUT /album/{id}`, `POST /command` (`ArtistSearch`, `AlbumSearch`, `RefreshArtist`)

## Add artist (`add_artist_screen.dart`)
- Lookup by name or `lidarr:<MusicBrainz id>`; already-added results are marked.
- Bottom sheet: root folder, quality profile, metadata profile, monitor mode, search for missing albums on add.
- `GET /artist/lookup`, `GET /rootfolder`, `GET /qualityprofile`, `GET /metadataprofile`, `POST /artist`

## Album detail (`album_detail_screen.dart`)
Opened by tapping an album (artist detail, Calendar, Wanted); the manual-search icon opens it directly on the Search tab. Three tabs:
- **Details:** cover, type, release date, genres, overview; monitor toggle, auto search; track list (number, title, duration, file status/quality); file cards (path, quality, size, release group, audio codec/bit depth/sample rate/bitrate, date added) with delete file.
- **History:** grab/import/failure/delete/rename/retag events for the album, with release title, quality, indexer and download client.
- **Search:** manual search (below), embedded as `ManualSearchView`.
- `GET /album/{id}`, `GET /track?albumId=`, `GET /trackfile?albumId=`, `DELETE /trackfile/{id}`, `GET /history?albumId=`

## Manual search (`manual_search_screen.dart`)
- Starts only when the user taps "Search indexers" (never automatically, to avoid needless indexer queries).
- Interactive release search for an album: lists releases from all indexers with quality, size, age, indexer, seeders/leechers (torrent) or usenet (protocol is read from the `protocol` field, which Lidarr sends as `TorrentDownloadProtocol` / `UsenetDownloadProtocol`), custom-format score, and rejection reasons.
- Rejected releases are hidden by default (toggle); grabbing a rejected one asks for confirmation. Grab sends it to the download client.
- **Long-running by design:** indexer queries can take minutes. The request uses a 5-minute timeout (`LidarrApi.releaseTimeout`) and runs inside `AppState.manualSearch`, not in the screen, so the user can leave and come back. The album's search button shows a spinner while running and a badge when results are ready. Results are kept in memory until restart/disconnect; "Search again" re-runs.
- `GET /release?albumId=`, `POST /release` (`guid`, `indexerId`)

## Calendar (`calendar_screen.dart`)
- Full month calendar (Sunday-first) opening on the current month with today selected; prev/next arrows or horizontal swipe navigate up to ±12 months. Days with releases are highlighted; tapping a day selects it. Below the grid, the selected day's releases (or "Nothing scheduled") are listed. One request loads the whole ±12-month range. The month grid slides left/right when changing month, and a **Today** button appears in the app bar whenever the selected day isn't today (jumps back to the current month with today selected).
- Posters: album covers come from the album's own `images`; if an embedded album/artist has no `images`, `Poster` falls back to the artist's images looked up by id in the artist list (`AppState.artistImages()`, loaded once; `remoteUrl` is used because `/MediaCover` may redirect to the login page).
- `GET /calendar?includeArtist=true`

## Activity (`activity_screen.dart`)
- **Queue:** progress, status, size, time left, download client; remove with optional blocklist. It refreshes silently (no spinner) every 10 s while the Activity tab is shown and each time the tab is selected; pull-to-refresh still works.
- **Manual import button:** a queue item waiting for user action (it has a `downloadId` and `trackedDownloadState` is `importBlocked`, or `importPending`/`importFailed` with `trackedDownloadStatus` `warning`; `needsManualImport()`) shows a `person_search` button left of the "X". It opens the manual import screen and reloads the queue when the import was started.
- **History:** last 50 events with icon per event type.
- Requests send `Cache-Control: no-cache`; `GET /queue` uses `includeUnknownArtistItems=true` so downloads Lidarr could not match to an artist (the ones needing manual import) are listed.
- `GET /queue`, `DELETE /queue/{id}`, `GET /queue/status` (badge), `GET /history`

## Manual import (`manual_import_screen.dart`)
Mobile version of the web UI's "Interactive Import", opened from a queue item (see Activity).
- **Loading** (`LidarrApi.manualImportCandidates`): `GET /manualimport?downloadId=<id>&filterExistingFiles=false` first, so Lidarr matches artist/album like the web UI. If it errors (`Parameter 'path'`) or returns nothing, retry with `folder=<queue item outputPath>` (can't match the artist). Also loads `GET /qualitydefinition` (each `.quality` = choices).
- **One card per file:** relative path, size, and chips to edit **artist**, **album**, **tracks** (multi-select) and **quality**. A checkbox selects it for import; disabled until it has artist, album, at least one track and a quality. Fully matched files are pre-selected. Lidarr has no per-file language.
- **Pre-fill** for files without artist: the queue item's `artist`/`album`, else its `artistId` in `GET /artist`, else `GET /parse?title=` (`artist`, `albums`). Changing the artist clears album/tracks and opens the album picker, which then opens the track picker (`GET /album?artistId=`, `GET /track?albumId=`).
- **Errors:** the queue item's `statusMessages` are shown on the file they refer to (matched by file name against the message `title`, or by position if counts match); only if none, the file's raw `rejections[].reason`.
- **Import:** `POST /command` `{name: "ManualImport", importMode: "auto", files: [...]}`; each file is `path`, `artistId`, `albumId`, `albumReleaseId` (album's monitored release), `trackIds`, `quality`, `releaseGroup`, `downloadId`, `disableReleaseSwitching`, plus `indexerFlags` when present. Import mode is always `auto`. **Not yet verified against a real Lidarr server** — check the payload against the web UI if it fails.
- **Demo mode:** one queue item (`id` 502, `importBlocked`) with one unmatched file; the `ManualImport` command removes it.

## Wanted (`wanted_screen.dart`)
- Two tabs: **Missing** (monitored albums without files) and **Cutoff unmet** (monitored albums whose file quality is below the profile cutoff).
- Search one album (automatic or manual), or all of the current tab from the app bar (`MissingAlbumSearch` / `CutoffUnmetAlbumSearch`).
- `GET /wanted/missing`, `GET /wanted/cutoff`, `POST /command` (`AlbumSearch`, `MissingAlbumSearch`, `CutoffUnmetAlbumSearch`)

## More (`more_screen.dart`)
- Lidarr logo card with version and active URL, health warnings/errors, disk space bars.
- In demo mode the card shows "Demo mode · sample data" instead of the URL.
- Connection settings, Disconnect & clear data.
- `GET /system/status`, `GET /health`, `GET /diskspace`

## Cross-cutting
- Shared widgets in `widgets/common.dart`: poster/cover with cached images (in demo mode a generated gradient with the name, since there are no remote images), loading/error/empty states, pull-to-refresh loader, toasts.
- Errors are surfaced as readable messages (invalid API key, unreachable server, Lidarr validation messages).
