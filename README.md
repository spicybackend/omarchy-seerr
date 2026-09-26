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

Enter your Seerr instance URL and API key (the URL is saved and prefilled next time). Create an API key in **Seerr → Settings → General**; [Seerr's API documentation](https://docs.seerr.dev/api/seerr-api/) documents `X-Api-Key` authentication. The plugin verifies it with `/auth/me`, then stores the key in your desktop Secret Service keyring; it is never written to the plugin config.

The key grants broad Seerr API access. Keep your login keyring unlocked after reboot. If Seerr does not accept API-key authentication for `/auth/me`, or Secret Service is unavailable, the plugin cannot sign in. Local email/password and cookie sign-in are intentionally not supported. Sign out from **Settings** to remove the saved key.

## Included

- Requested TV shows and movies, with request/availability status.
- Mixed TV/movie search, release year, poster thumbnails, and typed requests.
- API-key persistence in the desktop keyring and saved instance URL.

This is a third-party Omarchy Quattro plugin (`manifest.json` schema v1). Seerr enforces the key's permissions and quotas. Keyring persistence requires a working Secret Service and an unlocked login keyring after reboot.
