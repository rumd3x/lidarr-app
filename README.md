<div align="center">

<img src="assets/branding/logo.png" width="120" alt="Lidarr logo" />

# Lidarr

**An elegant, unofficial Android companion for your Lidarr server.**

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)
![Platform](https://img.shields.io/badge/platform-Android-3DDC84?logo=android&logoColor=white)
![Material 3](https://img.shields.io/badge/design-Material%203-00A65B)
![License](https://img.shields.io/badge/license-see%20LICENSE-lightgrey)

</div>

> Not affiliated with or endorsed by the Lidarr project.

## ✨ Highlights

- **Zero accounts** – no login, no registration, no database. Just your server URL and API key.
- **Try it without a server** – a built-in demo mode with sample data lets you explore every feature before connecting.
- **Resilient connection** – set a primary and a secondary URL (e.g. LAN + public domain); the app fails over automatically.
- **Full-featured** – browse, add, monitor, search and delete artists, check the calendar, queue, history and missing albums.
- **Fast** – library is cached locally and opens instantly, then refreshes in the background.
- **Beautiful** – Material 3, dark theme, cover grid, artist headers and progress bars.

## 📱 Features

| Area | What you can do |
|---|---|
| **Artists** | Cover grid/list, filters, search, per-artist progress |
| **Artist detail** | Albums list, monitor toggles, automatic search, refresh, delete |
| **Album detail** | Track list and file info, per-album history, manual (interactive) search with long-running background queries |
| **Add artist** | Lookup by name or `lidarr:MBID`, pick root folder, quality profile, metadata profile and monitor mode |
| **Calendar** | Upcoming and recent albums grouped by day |
| **Activity** | Live download queue (remove/blocklist) and history |
| **Wanted** | Missing albums, search one or all |
| **More** | Server version, health checks, disk space, connection settings |

See [`.docs/FEATURES.md`](.docs/FEATURES.md) for the full list and the API endpoints used.

## 🖼️ Screenshots

<p align="center">
  <img src=".docs/screenshots/01-setup.png" width="22%" alt="First-launch setup" />
  <img src=".docs/screenshots/02-artists.png" width="22%" alt="Artist library" />
  <img src=".docs/screenshots/03-artist-detail.png" width="22%" alt="Artist detail" />
  <img src=".docs/screenshots/04-album.png" width="22%" alt="Album details and tracks" />
</p>
<p align="center">
  <img src=".docs/screenshots/05-manual-search.png" width="22%" alt="Manual search" />
  <img src=".docs/screenshots/06-calendar.png" width="22%" alt="Calendar" />
  <img src=".docs/screenshots/07-activity.png" width="22%" alt="Download queue" />
  <img src=".docs/screenshots/08-wanted.png" width="22%" alt="Wanted albums" />
</p>

<sub>Captured with demo data; artists, albums and covers are fictional placeholders.</sub>

## 🚀 Getting started

1. Install the app on your Android device.
2. On first launch enter:
   - **Primary URL** – e.g. `http://192.168.1.10:8686`
   - **Secondary URL** *(optional)* – e.g. `https://lidarr.example.com`
   - **API key** – Lidarr → *Settings → General → Security*
3. Tap **Connect**.

No server handy? Tap **Try demo** to explore the app with built-in sample data.

## 🛠️ Development

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

> Gradle does not work with JDK 25 yet. Build with JDK 17:
> `JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64 flutter build apk`

The Android package is `com.rumd3x.lidarr`; the Lidarr API (`v1`) is detected at runtime.

## 📚 Documentation

Project premises, features and architecture live in [`.docs/`](.docs/). Contributors (and AI agents) must read it before making changes and keep it updated — see [`AGENTS.md`](AGENTS.md). To build the same app for Radarr, Readarr, Prowlarr, etc., follow [`.docs/PLAYBOOK.md`](.docs/PLAYBOOK.md).

## 📄 License

See [LICENSE](LICENSE).
