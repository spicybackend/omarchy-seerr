# Seerr Quick Requests

A small Omarchy Quattro bar popup for searching and requesting TV shows from Seerr.

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

## First sign-in
Open the popup, enter your Seerr instance URL (including any reverse-proxy path), email and local Seerr password, then sign in. The URL is retained; the password is never saved. The session cookie lives only in the running shell process, so sign in again after an Omarchy shell restart. Use **Settings → Sign out** to clear the current session.
Configure a local Seerr account in Seerr first; Plex/Jellyfin OAuth sign-in is not included. Cross-origin instances must allow credentialed CORS; same-origin is the safest configuration. Use HTTPS for remote instances and review the unsandboxed plugin source before enabling it.

## Included

- Requested TV shows and their request/availability status.
- Search Seerr's media catalog and submit TV requests.
- Available/downloaded state from Seerr's media record.
- Instance URL/session onboarding and settings sign-out.

This is a third-party plugin for current Omarchy Quattro (`manifest.json` schema v1). It makes requests using the signed-in user's Seerr permissions; Seerr may reject requests because of permissions, quotas, or server configuration. Movies and request administration are out of scope.
