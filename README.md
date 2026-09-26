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

Enter your Seerr instance URL and API key (the URL is saved and prefilled next time). Create the key in **Seerr → Settings → General**; [Seerr's API documentation](https://docs.seerr.dev/api/seerr-api/) documents `X-Api-Key` authentication. After Seerr verifies the key with `/auth/me`, choose where to save it:

- **Keyring:** recommended; stored in desktop Secret Service and protected by your login keyring. It must be unlocked after reboot.
- **Plain text:** written to `~/.config/omarchy/seerr-quick-requests.json` with owner-only permissions (`0600` file, `0700` directory). It is still unencrypted; anyone who can access your account can read and use this broad Seerr API key. A separate confirmation is required.
- **Don't save:** kept in memory only until the current shell exits.

The instance URL is saved separately. **Settings → Sign out** removes the saved key/config value. Local email/password and cookie sign-in are not supported. If Secret Service fails, choose plaintext or session-only.

## Included

- Requested TV shows and movies, with request/availability status.
- Mixed TV/movie search, release year, poster thumbnails, and typed requests.
- API-key persistence in the desktop keyring and saved instance URL.

This is a third-party Omarchy Quattro plugin (`manifest.json` schema v1). Seerr enforces the key's permissions and quotas. Keyring persistence requires a working Secret Service and an unlocked login keyring after reboot.
