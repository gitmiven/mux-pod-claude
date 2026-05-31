# Feature Specification: Distinct App Identity (co-exist with upstream)

**Feature Branch**: `012-coexist-app-id` | **Created**: 2026-05-31 | **Status**: Draft
**Input**: User: install this Claude-focused fork **alongside** the original `moezakura/mux-pod`,
with a visibly distinct name. This fork is diverging to add Claude-Code-specific features to MuxPod.

## Context

The fork still shared upstream's Android `applicationId` (`si.mox.mux_pod`) and label ("MuxPod"), so
Android treats it as the *same app*: only one can be installed, and since the fork is signed with a
different key (010/CI), installing it over an existing upstream app fails with a signature/package
conflict. To co-exist, the fork needs its own package id and a distinguishable name.

## Requirements

- **FR-001**: Set the Android `applicationId` to **`si.mox.mux_pod_claude`** (distinct from upstream's
  `si.mox.mux_pod`) so the fork installs **alongside** the original.
- **FR-002**: Set a distinguishable home-screen name **"MuxPod Claude"** (Android `android:label`;
  iOS `CFBundleDisplayName`) so it's obvious which app is running.
- **FR-003**: No other behavior change. The Kotlin `namespace` (`si.mox.mux_pod`) is left unchanged
  (only the install identity must differ); the `muxpod://` deep-link scheme is unchanged.
- **FR-004**: `flutter analyze` / `flutter test` unaffected (348 pass).

## Success Criteria

- **SC-001**: A release APK built from this branch installs on a device that already has the upstream
  MuxPod, as a separate app named "MuxPod Claude".
- **SC-002**: analyze exit 0; test 348 pass (config-only change).

## Notes / trade-offs

- The two apps have **separate storage** (Android Keystore / SharedPreferences), so SSH keys and
  connections are NOT shared between them — expected for two distinct apps.
- Both apps register the `muxpod://` deep-link scheme, so tapping such a link shows an app chooser.
  A distinct scheme (e.g. `muxpodclaude://`) could be added later if that becomes annoying.
- iOS bundle identifier is left as-is (iOS side-loading isn't the current target); only the iOS
  display name is updated for parity.

## Scope
In scope: `android/app/build.gradle.kts` (applicationId), `android/app/src/main/AndroidManifest.xml`
(label), `ios/Runner/Info.plist` (display name). Out of scope: iOS bundle id, deep-link scheme,
in-app branding.
