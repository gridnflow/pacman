# Release Guide — Chompire (Phase 8)

Store-submission metadata, asset checklist, and build/signing steps for v1.

> Trademark note (D-001): never use the classic title, ghost names, or original art in
> any user-facing string or store listing. Describe the game as a **classic maze-chase
> arcade** game only. The word "Pac-Man" must not appear in any listing copy.

---

## 1. App identity & metadata

| Field | Value |
|-------|-------|
| Display name (user-facing) | **Chompire** (capital C) |
| Package name / identifier | `chompire` (pubspec), bundle ID `com.chompire.chompire` |
| Android `applicationId` | `com.chompire.chompire` |
| iOS `PRODUCT_BUNDLE_IDENTIFIER` | `com.chompire.chompire` |
| Version (marketing) | **1.0.0** |
| Build number / version code | **1** (`1.0.0+1`) |
| Category | Games → Arcade |
| Content rating | Everyone / All ages (PEGI 3 / ESRB E) — no violence, no UGC, no ads |
| Default orientation | Portrait |
| Min OS | Android 8.0 (API 26)+, iOS 13+ (per D-013) |
| Network | None — fully offline |
| Permissions | **None** requested |
| In-app purchases / ads | None |

### Listing copy

**Short description (≤ 80 chars, Play):**
> Original arcade maze-chase: gobble pellets, dodge ghosts, chase the high score.

**Subtitle (≤ 30 chars, App Store):**
> Classic maze-chase arcade

**Full / long description:**
> Chompire is an original, fast-paced **classic maze-chase arcade** game. Steer the
> Muncher through a neon maze, gobble every pellet, and grab a power pellet to turn the
> tables on the four Drifters chasing you. Eat bonus fruit, rack up combos, and push for
> a new high score across endlessly escalating levels.
>
> - Smooth full-screen swipe controls — flick to turn.
> - Four ghosts ("Drifters") with distinct, faithful chase behaviors.
> - Power pellets, eat-chains, bonus fruit, and an extra life at 10,000 points.
> - Endless level progression — the maze never lets up.
> - 100% offline. No ads. No accounts. No data collected. No permissions.

**Keywords (App Store, comma-separated, ≤ 100 chars):**
> maze,arcade,chase,retro,pellet,ghost,classic,chomp,high score,offline

**Play Store tags:** Arcade, Casual, Single player, Offline

---

## 2. Privacy & data

- The app collects **no data**, makes **no network calls**, and requests **no permissions**.
- On-device storage only (`shared_preferences`): high score + audio toggle (D-014). Nothing
  leaves the device.
- **Play Data safety form:** "No data collected / No data shared."
- **App Store privacy nutrition label:** "Data Not Collected."
- **Privacy policy URL:** A minimal policy is still *required by both stores even for
  no-data apps* (a hosted URL field is mandatory). Action item — host a one-paragraph
  "we collect nothing" policy and fill the URL. *(Not done in this environment — no
  hosting.)*

---

## 3. Release builds — commands

Run from the repo root. Toolchain here: Flutter 3.38.9 / Dart 3.10.8, Android SDK 36,
Java 21.

| Target | Command | Output | Status (this env) |
|--------|---------|--------|-------------------|
| Web | `flutter build web --release` | `build/web/` | ✅ Built |
| Android APK | `flutter build apk --release` | `build/app/outputs/flutter-apk/app-release.apk` (~44 MB) | ✅ Built (debug-key signed) |
| Android App Bundle | `flutter build appbundle --release` | `build/app/outputs/bundle/release/app-release.aab` (~40 MB) | ✅ Built (debug-key signed) |
| iOS | `flutter build ipa --release` | `build/ios/ipa/*.ipa` | ⛔ Not built — requires macOS + Xcode + signing |

Regenerate launcher icons after any master-art change:
```
dart run flutter_launcher_icons
```

> The APK/AAB above are signed with the **debug key** (D-026) and are **not** publishable.
> See §4 for production signing.

---

## 4. Signing — production setup (REQUIRED before store submission)

### Android (currently debug-signed — must replace)

1. Generate an upload keystore (keep it secret, back it up — losing it locks you out of
   updates):
   ```
   keytool -genkey -v -keystore ~/chompire-upload.jks \
     -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
2. Create `android/key.properties` (git-ignored — do **not** commit):
   ```
   storePassword=<password>
   keyPassword=<password>
   keyAlias=upload
   storeFile=/absolute/path/to/chompire-upload.jks
   ```
3. In `android/app/build.gradle.kts`, load `key.properties` and replace the release
   `signingConfig`. Currently:
   ```kotlin
   buildTypes {
       release {
           // Signing with the debug keys for now.
           signingConfig = signingConfigs.getByName("debug")
       }
   }
   ```
   Replace with a real `release` signingConfig built from `key.properties`, and point
   `release.signingConfig` at it.
4. Recommended: enable **Play App Signing** so Google manages the app signing key while
   you keep the upload key.
5. Rebuild: `flutter build appbundle --release` → upload the `.aab` to Play Console.

### iOS (config-only here — not built)

- Requires **macOS + Xcode** (not available in this environment).
- Need an **Apple Developer Program** membership ($99/yr).
- Create an App ID for `com.chompire.chompire`, a Distribution certificate, and an
  App Store provisioning profile (Xcode → Signing & Capabilities, or automatic signing).
- Build/upload: `flutter build ipa --release` then submit via Xcode Organizer or
  `xcrun altool` / Transporter.
- `CFBundleDisplayName` is already set to `Chompire`; `CFBundleName` stays `chompire`.

---

## 5. Store asset checklist

### Icons — DONE (generated by `flutter_launcher_icons` from `assets/icon/app_icon.png`)
- [x] Android legacy mipmaps (`mipmap-mdpi…xxxhdpi/ic_launcher.png`)
- [x] Android adaptive icon (foreground + `#0B0B1A` background, `mipmap-anydpi-v26/`)
- [x] iOS `AppIcon.appiconset` (all sizes incl. 1024×1024 marketing icon)
- [x] Web icons (`Icon-192/512`, maskable variants) + favicon + manifest colors

### Google Play — still needed (manual / design)
- [ ] **App icon (store listing):** 512×512 PNG, 32-bit
- [ ] **Feature graphic:** 1024×500 PNG/JPG (required)
- [ ] **Phone screenshots:** 2–8, PNG/JPG, 16:9 or 9:16, min 320 px, max 3840 px
- [ ] (Optional) 7" and 10" tablet screenshots
- [ ] Short description (≤80) + full description (≤4000) — copy in §1
- [ ] Data safety form, content rating questionnaire, privacy policy URL

### Apple App Store — still needed (manual / design)
- [ ] **App icon:** 1024×1024 (already produced as marketing icon; verify in listing)
- [ ] **iPhone 6.7" screenshots:** 1290×2796 (or 6.5" 1242×2688) — at least one required
- [ ] **iPhone 5.5" screenshots:** 1242×2208 (if supporting older devices)
- [ ] (If iPad supported) 12.9" iPad screenshots: 2048×2732
- [ ] App preview videos (optional)
- [ ] Privacy nutrition label, age rating, support URL, privacy policy URL

---

## 6. Not done in this environment (follow-ups before publishing)

1. **Production Android signing** — still debug-key signed (D-026). Generate upload
   keystore + `key.properties`, swap the release `signingConfig` (§4).
2. **iOS release build** — needs macOS + Xcode + Apple Developer signing (§4).
3. **Store screenshots & feature graphic** — must be captured/designed on real device
   sizes (§5).
4. **Privacy policy URL** — host a minimal "no data collected" policy and supply the URL
   (§2). Required even with zero data collection.
5. **(Polish, per D-020/D-023)** bundle the real `PressStart2P-Regular.ttf` and uncomment
   the `fonts:` block — independent of release plumbing.
