# Changelog

## 1.3 — 2026-11-23

- Network shares are now rechecked periodically (every 5 minutes by default,
  adjustable or off in Settings) and remounted if they have dropped.
- Shares are also rechecked 15 seconds after the Mac wakes from sleep.
- Background rechecks stay quiet when everything is mounted, report an outage
  once rather than on every pass, and never open a Finder password dialog.
- Settings saved by older versions load correctly when new options are added.

## 1.2 — 2026-09-17

- Network shares now connect silently in the background through the NetFS
  framework, using the password already saved in Keychain. No Finder dialog
  needs to be confirmed at login.
- If no Keychain password exists for a server yet, MountPilot falls back to
  Finder's connection dialog once so the password can be saved.
- Share names containing spaces are percent-encoded automatically.

## 1.1 — 2026-09-05

- Added the MountPilot app icon and complete macOS AppIcon asset catalog.
- Published the first public binary release.

## 1.0 — 2026-09-05

- Initial menu-bar utility.
- Added SMB, AFP, and NFS connection requests after login.
- Added Time Machine, Carbon Copy Cloner, and custom process backup guards.
- Added conservative, non-forced clone-volume unmounting.
- Added login-item support and recent activity reporting.

