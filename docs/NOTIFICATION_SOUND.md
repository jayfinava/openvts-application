# Mobile notification sound

The supplied `Final-msg-track.mp3` is packaged as
`android/app/src/main/res/raw/open_vts_notification.mp3`. iOS bundles a
approximately 1.18-second, mono 44.1 kHz / 16-bit PCM WAV conversion at
`ios/Runner/open_vts_notification.wav`.

Android release resource shrinking must retain the sound and notification icons
referenced by Dart. `android/app/src/main/res/raw/open_vts_notifications_keep.xml`
keeps these specific resources. Without this rule the release APK removed the
MP3, even though debug/source configuration referenced it correctly.

Foreground notifications shown by the app use these sounds. Android background
push notifications use the `open_vts_alerts_v2` channel, which is also the
default FCM channel in `AndroidManifest.xml`. The new channel ID is needed
because Android retains the sound selected when a channel was first created.

For remote push payloads that set a channel explicitly, the sending service
should use `open_vts_alerts_v2`. For iOS remote notifications displayed while
the app is in the background or closed, the APNs payload must set
`aps.sound` to `open_vts_notification.wav`; the client cannot replace a remote
notification's sound after iOS displays it.

The backend sender at
`E:\Development\OpenVTS\complete-software\backend\src\common\utils\firebase-fcm.client.ts`
now sends Android pushes on `open_vts_alerts_v2` with
`sound: 'open_vts_notification'` and iOS pushes with
`aps.sound: 'open_vts_notification.wav'`. The user authorized these backend
changes and web notification audio on 2026-10-17, extending the earlier
mobile-only scope. Deploy the updated backend with the mobile build containing
the bundled sound and channel; OS notification and user mute settings apply.

The applied Firebase Admin SDK sender changes are below:

```diff
--- backend/src/common/utils/firebase-fcm.client.ts
+++ backend/src/common/utils/firebase-fcm.client.ts
@@ Android notification
-        channelId: 'open_vts_alerts',
-        sound: 'default',
+        channelId: 'open_vts_alerts_v2',
+        sound: 'open_vts_notification',
@@ APNs aps
-          sound: 'default',
+          sound: 'open_vts_notification.wav',
```

On Android 8+ the selected channel controls sound. The Android `sound` field
also supports devices below Android 8. Existing user mute, notification channel,
and system sound preferences remain authoritative; channels are not deleted or
reset by this change. No extra audio player or second notification is used.

Reference: [Android notification setup](https://firebase.google.com/docs/cloud-messaging/android/get-started),
[Apple custom notification sounds](https://developer.apple.com/documentation/usernotifications/unnotificationsound),
and the [notification plugin's release resource guidance](https://pub.dev/documentation/flutter_local_notifications/latest/).

## Verification on 2026-10-17

- Source MP3 and Android packaged sound match byte-for-byte: 29,132 bytes,
  SHA-256 `41F688EFB18F4E914E985CC46D10CAB7F3B5BC591642938114FB77CB50BF9831`.
- Android release builds passed for ARMv7, ARM64 and x86-64. Each APK's resource
  table retains `raw/open_vts_notification` and both notification icons; the
  referenced MP3's bytes match the supplied file. AAPT shortens the internal
  ZIP filename, so verification resolves the path through the resource table
  instead of assuming `res/raw/open_vts_notification.mp3` inside the APK.
- The existing iOS WAV is valid mono 16-bit / 44.1 kHz linear PCM, 1.18 seconds
  long, and is registered in the Xcode Resources build phase. iOS was not built
  on this Windows host.
- Build log: `build/notification_sound_release_apk.txt`; packaged-resource/hash
  checks: `build/notification_sound_asset_verification.txt`.
- No live Firebase message or audible physical-device test was performed.
  Release signing remains governed by the existing configuration.

## Web application

The main product's web app uses the same MP3 at
`Frontend/public/audio/open-vts-notification.mp3` through its shared foreground
FCM handler. The player is reused, duplicate/burst sounds are suppressed, and
logout or listener replacement releases the audio and Firebase subscription.
Playback requires a focused visible page, granted notification permission and
browser audio permission. The foreground native notification is silent to
avoid a second system sound. Background/closed-tab web notifications retain
browser-managed sound; custom MP3 playback cannot be guaranteed there.
See `complete-software/Frontend/docs/NOTIFICATION_SOUND.md` for deployment and
browser-policy details.

Backend/web follow-up validation: 18 web tests and 3 mocked Firebase Admin
payload tests passed; both projects' TypeScript checks passed; the Next.js
production build and standalone asset copy succeeded. The deployed web asset
was verified in the local standalone output against the source/mobile MP3's
SHA-256 checksum. Logs: `build/web_notification_sound_tests.txt`,
`build/backend_notification_sound_tests.txt`,
`build/web_notification_sound_release.txt`, and
`build/notification_sound_cross_platform_assets.json`. The backend/web changes
still require deployment; live delivery and audible client testing remain
unperformed.
