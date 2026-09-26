# Seerr quick-request improvements plan

## Research and current behavior

Official Seerr OpenAPI (`https://docs.seerr.dev/api/seerr-api/`, export `seerr-api.yml`) confirms:
- `GET /search?query=...` returns movies (`mediaType: "movie"`, `title`, `releaseDate`), TV (`mediaType: "tv"`, `name`, `firstAirDate`), and people. Movie and TV search result schemas both include `posterPath`, `backdropPath`, and `mediaInfo`.
- `POST /request` accepts `mediaType: movie|tv` and `mediaId`; `seasons: "all"` is a TV-only field. Requests listing `GET /request` accepts `mediaType=all|movie|tv`. Linked `MediaInfo` has TMDB ID/status, not guaranteed title or artwork.
- Current Seerr API docs support `X-Api-Key` header auth. The API key is stored in the OS Secret Service; the plugin only persists the non-sensitive instance URL. Email/password and cookie-based login are intentionally excluded by the user's follow-up instruction.
- Poster paths are TMDB paths. Use `https://image.tmdb.org/t/p/w92/<posterPath>` (or a TMDB image URL setting if Seerr's configuration reports it), asynchronous image loading, explicit empty-art fallback, and no poster request when path is missing. Respect TMDB's asset terms/privacy implications.
- Omarchy Quattro panel receives keyboard focus on open. Current `PanelKeyCatcher` handles arrows, tab, and text keys, but a focused `TextField` needs `blocked` semantics and moving keyboard focus intentionally to result rows when navigation exits search.

## User requirements in this iteration

1. Focus search on opening authenticated view; add visual spacing between search and request list/results.
2. Show real movie and TV show names, posters, and release/air years; no ID-only cards. Requests must show a meaningful Requested/Approved/Available label, never “Not requested” for a requested item.
3. Rename header to “Seerr Requests”. Include movies in search and allow movie requests as well as TV.
4. Keyboard navigation across result rows with arrow keys and Tab out of search; Escape closes popup; search typing remains normal.
5. Replace the bar `TV` text label with a Seerr-like icon/glyph, ensuring graceful fallback in fonts.
6. Persist the instance URL and prefill it on later sign-in. Persist the Seerr API key in the OS keyring across shell restarts/reboot; never store it in plugin config. The session cookie is HttpOnly and cannot be extracted safely. User has directed API-key-only auth: prompt for the API key, verify with `X-Api-Key` via `/auth/me`, then save it to the keyring. Remove email/password fields and local-cookie fallback.

## Security decision

After successful `/auth/me`, prompt with three explicit choices: keyring, plaintext config, or session-only. Keyring uses Secret Service and is preferred. Plaintext is opt-in, requires separate warning confirmation, stores the key in the plugin config readable by any process/user with file access, and is chmod `0600` before the key is written. “Don't save” writes no key and keeps the verified key in memory until shell exit. Switching modes/sign-out must clear previous persistent copies. No email/password or cookie login path.

## Swarm slices

1. **API/auth, media data, persistence — `SeerrApi.qml` only.** Add mixed TV/movie search, mediaType-aware create/dedupe, all-media requests, normalized titles/years/poster/status and request-detail lookup where search data is unavailable, URL persistence, API-key-only auth through `/auth/me`, and Secret Service storage using installed `secret-tool` through QML Process stdin. No password/cookie auth and no plaintext key storage.
2. **Panel UI, artwork, keyboard accessibility — `Panel.qml` only.** Search TV+movies, display title + year + left poster, request list with titles rather than IDs where available; fix requested status copy; header “Seerr Requests”; focus search on open; add spacing; keyboard arrow selection, Tab traversal, maintain typing/Enter in the input and Escape close. API-key-only login form with docs link and transparent keyring warning. Consume API contract; no email/password controls.
3. **Bar icon — `BarWidget.qml` only.** Replace “TV” with Seerr-resembling icon using existing Nerd Font glyph support or QML vector shape without dependency; accessible tooltip remains “Quick Seerr requests”. Keep all bar widget lifecycle and popup click intact.
4. **Coordinator** merges API interface, writes docs, test script for media/credential behavior, validates plugin and runtime, updates local installation (already symlinked locally; rescan shell).

Agents are separate ownership slices; avoid overlapping edits. First coordinate credential/API contract explicitly before concurrent edits.

## Acceptance / verification

- Plugin manifest validates; `qmllint` all QML passes; `node test-api.js` covers URL normalization and media request payload types.
- Local plugin was enabled; current Omarchy shell launches and the plugin's popup lifecycle is reachable by IPC. API-key auth flow was not exercised against a Seerr instance because no API key/server credentials are available.
- Secret Service store/lookup/clear was exercised using a temporary throwaway key and cleared. Actual keyring-backed Seerr `/auth/me` and restart persistence remain unverified without a usable Seerr API key.
- README documents API-key setup, broad permissions, keyring dependence, sign-out, mixed media, art, and keybind.

## Risks

- No live Seerr server/API key was available, so API-key endpoint acceptance, request behavior, and authenticated media results were not exercised.
- Secret Service may be unavailable/locked in a given desktop session. Never silently store token elsewhere.
- The user asks for reboot persistence. Keyring persistence depends on their login keyring being persistent/unlocked after reboot; say so explicitly.