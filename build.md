# Build and install Ghostty with Docker

This Dockerfile builds Ghostty for an **Ubuntu 26.04** host without installing
Zig on the host. Run these commands from the repository root on a host with
Docker Buildx available. The host still needs Ghostty's GTK runtime libraries.

```sh
docker buildx build --target artifact --output type=local,dest=ghostty-output .
```

The exported installation is under `ghostty-output/usr/local`. Install it for
the current user (no `sudo` required):

```sh
install -Dm755 ghostty-output/usr/local/bin/ghostty "$HOME/.local/bin/ghostty"
mkdir -p "$HOME/.local/share"
# Includes ~/.local/share/ghostty, the generated desktop file, icons,
# D-Bus service, and other desktop integration files.
cp -a ghostty-output/usr/local/share/. "$HOME/.local/share/"
```

The desktop file is now at
`~/.local/share/applications/com.mitchellh.ghostty.desktop`. Ensure
`~/.local/bin` is on your `PATH` so its `Exec=ghostty` command works. Log out
and back in if your desktop does not show the launcher immediately.
