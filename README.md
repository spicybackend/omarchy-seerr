# Seerr Quick Requests

A compact Omarchy Quattro bar popup for requesting TV shows and movies from Seerr.

## Install

```sh
omarchy plugin add https://github.com/<owner>/omarchy-seerr.git --enable
```

The plugin adds the **TV** button to the bar's center section when enabled. If needed, move it with:

```sh
omarchy bar move io.github.omarchy-seerr.plugin --section center
```

Click the bar button to toggle the popup. It uses Omarchy's shared theme colors and scaling.

## Hotkey

Add this to `~/.config/hypr/bindings.conf` (or your Omarchy user keybinding file):

```ini
bind = SUPER SHIFT ALT, R, exec, omarchy-shell shell toggle io.github.omarchy-seerr.plugin '{}'
```

Reload Hyprland configuration after adding the binding. The plugin does not edit user keybind files automatically.

## Sign-in and persistence

Enter your Seerr instance URL and API key (the URL is saved and prefilled next time). Create the key in **Seerr → Settings → General**; [Seerr's API documentation](https://docs.seerr.dev/api/seerr-api/) documents `X-Api-Key` authentication. After Seerr verifies the key with `/auth/me`, you are signed in and can choose:

- **Save in keyring:** recommended; the API key is stored in the desktop Secret Service and protected by your login keyring. It must be unlocked after reboot.
- **Use this session only:** the key is kept in memory until the current shell exits.

The instance URL is saved separately. **Settings → Sign out** removes the saved key. Local email/password and cookie sign-in are not supported.

## Keyring setup and troubleshooting

Keyring storage uses the freedesktop Secret Service via `secret-tool`. On Omarchy it is usually provided by `gnome-keyring-daemon` and should work without manual setup as long as your login keyring is unlocked.

### Quality profile permissions

Quality profile dropdowns read your configured Radarr/Sonarr servers from Seerr settings. The API key must have permission to read settings. In **Seerr → Settings → General → API Key**, make sure the key includes the **Settings** permission (or grant an admin-level key). Without it, the dropdowns will not populate and requests will fall back to the server default profile.

Check that the service is running:

```sh
pgrep -a gnome-keyring-daemon
secret-tool lookup service omarchy-seerr-quick-requests server http://umbrel:5056
```

If the lookup prints your key, the plugin can read it. If the save still fails, the most common cause is a **locked login keyring**. Unlock it with your user password:

```sh
secret-tool lookup service anything anything
```

A graphical unlock prompt should appear. If no prompt appears, make sure a keyring daemon is running:

```sh
/usr/lib/polkit-gnome-authentication-agent-1 &
gnome-keyring-daemon --start --components=secrets --daemonize
```

On systems without a graphical keyring, use **Use this session only**.

## Included

- Requested TV shows and movies, with request/availability status (including "Not yet released" for upcoming titles).
- Mixed TV/movie search, release year, poster thumbnails, and typed requests.
- Per-request **Remove** button to delete the Seerr request record (does not delete downloaded files).
- Settings for default movie and TV **quality profiles** (requires an API key with permission to read Seerr settings).
- API-key persistence in the desktop keyring and saved instance URL.

This is a third-party Omarchy Quattro plugin (`manifest.json` schema v1). Seerr enforces the key's permissions and quotas. Keyring persistence requires a working Secret Service and an unlocked login keyring after reboot.
