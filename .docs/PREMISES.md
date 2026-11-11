# Premises

- **Name:** Lidarr (unofficial). Flutter, Android only (`com.rumd3x.lidarr`).
- **Goal:** let Lidarr administrators manage their own Lidarr instance from a phone, with an elegant mobile UI.
- **No accounts:** no login, no registration, no backend of our own, no database.
- **Local storage only:** `shared_preferences` holds the connection settings and a small cache of the artist list. Nothing else is persisted (demo mode only stores the demo config marker). "Disconnect" wipes it all.
- **First launch:** the app must ask for **primary URL**, **secondary URL** (optional fallback) and the **Lidarr API key**. The connection is verified (`GET /system/status`) before saving. A **Try demo** button skips this and uses built-in sample data (see Demo mode).
- **Demo mode:** the Setup screen has a **Try demo** button that stores `ServerConfig.demo` (URL `http://demo.lidarr.local`) and serves every request from an in-memory fake server (`lib/services/demo_client.dart`). It exists because Google Play reviewers need a way into an app that otherwise requires a self-hosted server. It must keep working with every screen/endpoint the app uses; when you add an API call, add it to `DemoServer`. No data leaves the device in demo mode.
- **URL failover:** every request tries the last working URL first, then the other one. Only network failures trigger failover; HTTP errors (e.g. 401) do not.
- **Auth:** API key sent as `X-Api-Key` header; image URLs served by Lidarr use the `apikey` query parameter.
- **API version:** detected at runtime via `GET /api` (`current` field, e.g. `v1`), defaulting to `v1`. API reference: https://lidarr.audio/docs/api/
- **Cleartext HTTP is allowed** (`usesCleartextTraffic`), because Lidarr is commonly reached over LAN.
- **Theme:** Material 3, dark by default, seed colour `#00A65B`.
- **Not affiliated** with the Lidarr project; the app says so in the More screen.
- **Branding:** the official Lidarr logo (from the open-source Lidarr repo, `Logo/`) is used for the launcher icon, setup screen, More screen and README. Sources live in `assets/branding/` (`logo.png`, `logo.svg`, `logo_foreground.png` = logo padded to 66% for the adaptive icon; adaptive background `#EDEDED`). Regenerate launcher icons with `dart run flutter_launcher_icons` (config: `flutter_launcher_icons.yaml`).
- **Tooling note:** Gradle fails on JDK 25; build with JDK 17 (`JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64`).
