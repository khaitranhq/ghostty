# Build and install Ghostty with Docker

This Dockerfile builds a Ghostty Debian package for an **Ubuntu 26.04** host
without installing Zig on the host. Run this command from the repository root
on a host with Docker Buildx available.

```sh
docker buildx build --target artifact --output type=local,dest=ghostty-output .
```

The exported package is `ghostty-output/ghostty.deb`. Install it on Ubuntu 26.04
with its runtime dependencies:

```sh
sudo apt install ./ghostty-output/ghostty.deb
```

On a `vX.Y.Z` tag push, the Ubuntu 26.04 release workflow also attaches
`ghostty-vX.Y.Z-ubuntu-26.04-x86_64.deb` to the GitHub Release. Download it and
install it with `sudo apt install ./ghostty-vX.Y.Z-ubuntu-26.04-x86_64.deb`.
The package installs under `/usr/local`, including the desktop integration
files. Log out and back in if your desktop does not show the launcher immediately.
