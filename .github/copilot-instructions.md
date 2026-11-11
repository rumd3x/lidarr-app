# Project instructions

- **Always read the documentation in `.docs/` before acting** (start with `.docs/README.md` and `.docs/PREMISES.md`).
- **Always keep the documentation updated**: any change to behavior, features, architecture, premises, commands or dependencies must update the matching file in `.docs/` (and `README.md` when user-facing) in the same change.
- Respect the premises: no login/database, local cache only, primary + secondary URL with API key.
- This is the **Lidarr** app (Flutter, Android only, package `com.rumd3x.lidarr`, API `v1`), ported from the Sonarr app: series → artist, episode → album (tracks shown inside the album screen).
- Validate with `flutter analyze` and `flutter test`; build with JDK 17 (`JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64 flutter build apk`).
- Every endpoint the app uses must also be served by the demo server in `lib/services/demo_client.dart`.
- When the UI changes, retake `.docs/screenshots/` (see `.docs/PLAYBOOK.md` §5) and keep the README references in sync.
- Keep `Jenkinsfile` (`FORGEJO_REPO`, `APP_NAME`) and the Play listing in `android/app/src/main/play/` consistent with the app identity.
