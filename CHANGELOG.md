# Changelog

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

