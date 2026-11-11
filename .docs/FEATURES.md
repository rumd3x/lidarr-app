# Features

Navigation: bottom bar with **Artists · Calendar · Activity · Wanted · More**. Lidarr API is `v1`; main entity mapping from the Sonarr app: series → artist, episode → album (tracks are listed inside the album screen).

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
- Interactive release search for an album: lists releases from all indexers with quality, size, age, indexer, seeders/leechers (torrent) or usenet, custom-format score, and rejection reasons.
- Rejected releases are hidden by default (toggle); grabbing a rejected one asks for confirmation. Grab sends it to the download client.
- **Long-running by design:** indexer queries can take minutes. The request uses a 5-minute timeout (`LidarrApi.releaseTimeout`) and runs inside `AppState.manualSearch`, not in the screen, so the user can leave and come back. The album's search button shows a spinner while running and a badge when results are ready. Results are kept in memory until restart/disconnect; "Search again" re-runs.
- `GET /release?albumId=`, `POST /release` (`guid`, `indexerId`)

## Calendar (`calendar_screen.dart`)
- Album releases from 3 days ago to 30 days ahead, grouped by day ("Today" highlighted).
- `GET /calendar?includeArtist=true`

## Activity (`activity_screen.dart`)
- **Queue:** progress, status, size, time left, download client; remove with optional blocklist.
- **History:** last 50 events with icon per event type.
- `GET /queue`, `DELETE /queue/{id}`, `GET /history`

## Wanted (`wanted_screen.dart`)
- Monitored missing albums; search one album (automatic or manual), or all missing from the app bar.
- `GET /wanted/missing`, `POST /command` (`AlbumSearch`, `MissingAlbumSearch`)

## More (`more_screen.dart`)
- Lidarr logo card with version and active URL, health warnings/errors, disk space bars.
- In demo mode the card shows "Demo mode · sample data" instead of the URL.
- Connection settings, Disconnect & clear data.
- `GET /system/status`, `GET /health`, `GET /diskspace`

## Cross-cutting
- Shared widgets in `widgets/common.dart`: poster/cover with cached images (in demo mode a generated gradient with the name, since there are no remote images), loading/error/empty states, pull-to-refresh loader, toasts.
- Errors are surfaced as readable messages (invalid API key, unreachable server, Lidarr validation messages).
