# Seerr quick-request plugin plan

## Product and API findings

Seerr is the unified Overseerr/Jellyseerr media-discovery and request manager for Plex, Jellyfin, and Emby, normally backed by Radarr/Sonarr. It owns login, permission/quota checks, request approval, and media-download status, so the plugin should use Seerr as the source of truth and not talk to downloaders directly.

The official API reference identifies `POST /api/v1/auth/local` (email/password, `connect.sid` session cookie), `GET /auth/me`, `POST /auth/logout`, `GET /search?query=…`, `POST /request` (mediaType `tv`, mediaId, optional seasons; needs REQUEST permission), `GET /request` (permission-scoped, supports `mediaType=tv` and filters), and TV/media status data. The client uses Qt's XMLHttpRequest cookie handling; it does not expose/persist cookies. Only the base URL is persisted, never passwords or session cookies, so users sign in again after restarting Omarchy shell. Keep the base URL configurable and preserve an optional Seerr subpath. Require HTTPS for remote instances in documentation; allow local HTTP for LAN use.

A request's lifecycle differs from a title merely being requested: `GET /request` returns request records and a linked media record; Seerr's media status is the authority for availability/download completion. Display request status and available/downloaded separately. Existing requests should prevent duplicate submissions.

Omarchy's current Quattro plugin contract uses a root `manifest.json`, a `bar-widget` QML entry point, shared theme tokens (`Color`, `Style`), a nested `KeyboardPanel`, and plugin IPC routing. The widget click toggles the panel; the hotkey binds shell IPC to the plugin lifecycle. Avoid spawning another Quickshell process. Configure `SUPER SHIFT ALT + R` through Omarchy's user keybinding configuration (document the exact install snippet); repository cannot modify a user's keybind file automatically.

## Decisions and constraints

- Plugin ID: `io.github.omarchy-seerr.plugin` (third-party namespaced ID; revise only if repository owner chooses a publishing namespace).
- Standalone QML bar widget + anchored panel, matching installed clock/weather patterns; no backend service or external runtime dependency.
- Login: Seerr local email/password cookie session; onboarding collects instance URL and credentials, validates with `/auth/me`, and retains the URL. Password/session cookie stay memory-only; Settings hides sign-out.
- Main surface: requested TV shows, search results, request action, request/media lifecycle labels, loading/error/empty states, refresh.
- Theme: use Omarchy `Color`/`Style` tokens only. Hotkey entry: expose plugin `toggle` IPC and provide Hyprland bind documentation for `omarchy-shell shell toggle <plugin-id>`.
- Keep implementation narrow: TV requests only, no movie request UI, admin approvals, downloader configuration, or new dependencies.

## Task slices for swarm

1. **Foundation / manifest / docs** — own `manifest.json`, `README.md`, this plan. Ensure valid Omarchy metadata; document install/enable, bar placement, keybind, Seerr compatibility and security, settings/sign-out, known scope.
2. **Seerr API client and session onboarding** — `SeerrApi.qml`: URL normalization incl. subpaths, local login, current-user validation, logout, search-TV normalization, request list and create request, error mapping. Do not persist session/password; document shell-restart sign-in.
3. **Panel UI and theme** — own `Panel.qml`, implementing onboarding, requested list, search, request action, downloaded/available state, settings/sign-out, empty/loading/error states; consume the API contract and use native Omarchy theme/style. Do not edit API client, widget entry, manifest/docs.
4. **Bar entry / popup integration** — own `BarWidget.qml`, implement icon/button, toggle IPC target and panel injection/lifecycle. Coordinate UI component contract with UI worker; do not edit panel/API/docs.
5. **Integration owner (coordinator)** — reconcile contracts, install instructions and keybind, validate manifest/QML, smoke test through available Omarchy shell/UI, repair integration issues, final README/plan notes.

## Acceptance checks

- `omarchy plugin validate .`, `qmllint SeerrApi.qml Panel.qml`, and `qmllint -I /usr/share/omarchy/shell BarWidget.qml` succeed.
- `node test-api.js` passes URL normalization cases for reverse-proxy paths, explicit `/api/v1`, default host, and rejected URL. Smoke source is in `test-api.js`.
- Local plugin discovered and enabled in Omarchy. Current shell launches without plugin-load QML errors; shell IPC can toggle the bar widget's popup lifecycle.
- UI sign-in fields and API calls are implemented; no live Seerr instance/account was available, so login, request listing, searching and request creation were not exercised against a server.
- Password/session values are not persisted. URL only; a shell restart requires login again.

## Risks / unresolved

- Seerr deployments vary in base path, reverse proxy, TLS, CSRF settings and authentication source; actual API behavior should be tested against the configured server.
- Omarchy plugins execute in the long-lived unsandboxed shell. Only enable reviewed code. QML/Qt cookie lifecycle must be verified with a real Seerr session.
- No Seerr instance/credentials were available. Cross-origin requests require server CORS credentials support; same-origin is the conservative deployment.
