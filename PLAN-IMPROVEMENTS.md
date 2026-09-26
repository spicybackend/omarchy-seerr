# Seerr quick-request improvements plan

## Research and current behavior

Official Seerr OpenAPI (`https://docs.seerr.dev/api/seerr-api/`, export `seerr-api.yml`) confirms:
- `GET /search?query=...` returns movies (`mediaType: "movie"`, `title`, `releaseDate`), TV (`mediaType: "tv"`, `name`, `firstAirDate`), and people. Movie and TV search result schemas both include `posterPath`, `backdropPath`, and `mediaInfo`.
- `POST /request` accepts `mediaType: movie|tv` and `mediaId`; `seasons: "all"` is a TV-only field. Requests listing `GET /request` accepts `mediaType=all|movie|tv`. Linked `MediaInfo` has TMDB ID/status, not guaranteed title or artwork.
- Authentication supports local-login cookie sessions and an `X-Api-Key` generated in Seerr's main settings. API key auth can make sessions durable without retaining the password or extracting an HttpOnly cookie. No refresh-token endpoint is documented. Key should live in the desktop Secret Service (available here as `secret-tool`), never in the plugin JSON config or source. If Secret Service is absent/unavailable, explain persistence cannot be enabled, keep cookie session only in-memory, and allow re-login; do not fall back to plaintext token storage.
- Poster paths are TMDB paths. Use `https://image.tmdb.org/t/p/w92/<posterPath>` (or a TMDB image URL setting if Seerr's configuration reports it), asynchronous image loading, explicit empty-art fallback, and no poster request when path is missing. Respect TMDB's asset terms/privacy implications.
- Omarchy Quattro panel receives keyboard focus on open. Current `PanelKeyCatcher` handles arrows, tab, and text keys, but a focused `TextField` needs `blocked` semantics and moving keyboard focus intentionally to result rows when navigation exits search.

## User requirements in this iteration

1. Focus search on opening authenticated view; add visual spacing between search and request list/results.
2. Show real movie and TV show names, posters, and release/air years; no ID-only cards. Requests must show a meaningful Requested/Approved/Available label, never “Not requested” for a requested item.
3. Rename header to “Seerr Requests”. Include movies in search and allow movie requests as well as TV.
4. Keyboard navigation across result rows with arrow keys and Tab out of search; Escape closes popup; search typing remains normal.
5. Replace the bar `TV` text label with a Seerr-like icon/glyph, ensuring graceful fallback in fonts.
6. Persist the instance URL and prefill it on later login. Persist authenticated credentials across shell restart/reboot in the OS keyring, never plaintext files. Seerr session cookie is HttpOnly and cannot be safely extracted; use the Seerr API key through its supported `X-Api-Key` auth path, prompting users for the key (with instructions for creating it) during sign-in/setup, if needed for durable auth.

## Security decision

Use `secret-tool`/Freedesktop Secret Service for the Seerr API key. Test Secret Service availability and operation before claiming persistence. Store one secret per normalized server URL as an attribute, distinguish plugin/schema with stable service attributes, never log the secret, and clear it on sign-out. Persist only non-secret instance URL and non-sensitive preference in `~/.config/omarchy/seerr-quick-requests.json` (0600 if writing directly). Do not store API key/token in `QtCore.Settings`, shell.json, or JSON. If credential helper absent or keyring locked, present actionable error and leave onboarding functional using session-cookie login; no plaintext fallback. Since API key grants server-wide API access rather than a narrow session, warn users clearly and prefer user session until they elect durable key auth. Verify actual Seerr checks `X-Api-Key` on protected endpoints per OpenAPI; don't assume API key identity maps to a normal user unless `/auth/me` confirms.

## Swarm slices

1. **API/auth, media data, persistence — `SeerrApi.qml` only.** Add mixed TV/movie search, mediaType-aware create/dedupe, all-media requests, sensible request labels data, poster/release fields through search cache and details lookup only if required, persist URL. Add Secret Service integration using installed `secret-tool` through QML Process or safe equivalent. No passwords/tokens in files/logs. Report API key permission/me semantics and fallback. Own only API file; coordinator documents user steps/security.
2. **Panel UI, artwork, keyboard accessibility — `Panel.qml` only.** Search TV+movies, display title + year + left poster, request list with titles rather than IDs where available (when request API omits them, map IDs against search or use title lookup); fix requested status copy; header “Seerr Requests”; focus search on open; add spacing; keyboard up/down selection in results, Tab from search to first result/button, forward Tab through actions and out; maintain typing/Enter in text input and Escape close. Show persistent key-auth option/help/fallback with API interface once settled. Consume API shared contract in context; do not edit API/Bar.
3. **Bar icon — `BarWidget.qml` only.** Replace “TV” with Seerr-resembling icon using existing Nerd Font glyph support or QML vector shape without dependency; accessible tooltip remains “Quick Seerr requests”. Keep all bar widget lifecycle and popup click intact.
4. **Coordinator** merges API interface, writes docs, test script for media/credential behavior, validates plugin and runtime, updates local installation (already symlinked locally; rescan shell).

Agents are separate ownership slices; avoid overlapping edits. First coordinate credential/API contract explicitly before concurrent edits.

## Acceptance / verification

- Plugin manifest validates; `qmllint` all QML passes; `node test-api.js` covers URL base/subpath, both request media types/payload shape, result title/year/type/art normalization, status display model, and credential-free config invariant as practical.
- Real Omarchy panel opens with search focused and adequate gap; title and year visible; poster loaded where provided; keyboard arrows move selection and activate; Tab out of search follows controls/results and Escape closes.
- Movie + TV requests submit correct Seerr payload; pending/approved/available never labelled “Not requested”; request list remains request-only according to clear policy (requested by current account vs visible permission-scope).
- Local keyring store/lookup/clear exercise uses a throwaway unique secret and cleans it after; no actual Seerr API key. Verify restart persistence via API-key fixture or Secret Service presence and make no claim of actual API key auth without Seerr.
- Local plugin rescan/reload, real popup open/close IPC, and no new plugin QML diagnostics. Update `README.md` with API key creation, keyring requirement, limitations, install and hotkey. Commit plan before implementation and commit completed changes.

## Risks

- Seerr API key authentication may authenticate the server rather than normal user for `/auth/me`; acceptance must confirm. If X-Api-Key does not provide usable `auth/me` or permission-shaped request list, saved API key must not silently impersonate a user; retain cookie flow and report durable auth blocker.
- Secret Service may be unavailable/locked in a given desktop session. Never silently store token elsewhere.
- The user asks for reboot persistence. Keyring persistence depends on their login keyring being persistent/unlocked after reboot; say so explicitly.