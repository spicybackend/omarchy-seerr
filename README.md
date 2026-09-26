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

Enter your Seerr instance URL and API key (the URL is saved and prefilled next time). Create an API key in **Seerr → Settings → General**; [Seerr's API documentation](https://docs.seerr.dev/api/seerr-api/) documents `X-Api-Key` authentication. After `/auth/me` verifies the key, choose one:

- **Keyring:** encrypted by your desktop Secret Service; requires an unlocked login keyring after reboot.
- **Plain text:** stored in `~/.config/omarchy/seerr-quick-requests.json`; any process/user that can read that file can use the broad Seerr API key. The UI requires a separate confirmation.
- **Don't save:** usable only until the current Omarchy shell exits.

The instance URL is saved separately. Sign out from **Settings** to remove the saved credential.

## Included

- Requested TV shows and movies, with request/availability status.
- Mixed TV/movie search, release year, poster thumbnails, and typed requests.
- API-key persistence in the desktop keyring and saved instance URL.

This is a third-party Omarchy Quattro plugin (`manifest.json` schema v1). Seerr enforces the key's permissions and quotas. Keyring persistence requires a working Secret Service and an unlocked login keyring after reboot.
