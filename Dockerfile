# Build Ghostty for an Ubuntu 26.04 host without installing Zig on the host.
FROM ubuntu:26.04 AS build

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    curl \
    dpkg-dev \
    gettext \
    libadwaita-1-dev \
    libgtk-4-dev \
    libgtk4-layer-shell-dev \
    libxml2-utils \
    pkg-config \
    python3-gi \
    python3-venv \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

# Ubuntu 26.04 ships Blueprint 0.19, but this Git checkout requires >= 0.20.
# Include distro GI bindings in the venv for Blueprint's GTK introspection.
# The 0.20.4 PyPI entry point has an empty shebang; repair it in the build stage.
RUN python3 -m venv --system-site-packages /opt/blueprint \
    && /opt/blueprint/bin/pip install --no-cache-dir 'blueprint-compiler==0.20.4' \
    && sed -i '1c#!/opt/blueprint/bin/python' /opt/blueprint/bin/blueprint-compiler
ENV PATH="/opt/blueprint/bin:${PATH}"
RUN test "$(blueprint-compiler --version)" = '0.20.4'

WORKDIR /src
COPY build.zig.zon ./

# Ghostty pins the Zig version in build.zig.zon; keep Zig inside this stage.
RUN set -eu; \
    zig_version="$(sed -n -E 's/^[[:space:]]*\.minimum_zig_version = "([^"]+)".*/\1/p' build.zig.zon)"; \
    test -n "$zig_version"; \
    zig_dir="zig-$(uname -m)-linux-${zig_version}"; \
    curl -fsSL "https://ziglang.org/download/${zig_version}/${zig_dir}.tar.xz" -o /tmp/zig.tar.xz; \
    tar -xf /tmp/zig.tar.xz -C /opt; \
    ln -s "/opt/${zig_dir}/zig" /usr/local/bin/zig; \
    rm /tmp/zig.tar.xz; \
    zig version

COPY . .

# DESTDIR preserves the /usr/local layout, including share/ghostty and
# the desktop integration files under share/applications and share/icons.
RUN DESTDIR=/output zig build --prefix /usr/local \
    -Doptimize=ReleaseFast -Dcpu=baseline \
    -Dinstalled-exe-path=/usr/local/bin/ghostty \
    && /output/usr/local/bin/ghostty +version

# Derive runtime library dependencies from the built binary instead of
# pulling build dependencies into the installed package.
RUN set -eu; \
    test -f /output/usr/local/share/applications/com.mitchellh.ghostty.desktop; \
    test -d /output/usr/local/share/ghostty; \
    mkdir -p /output/DEBIAN debian; \
    printf 'Source: ghostty\n' > debian/control; \
    depends="$(dpkg-shlibdeps -O -e/output/usr/local/bin/ghostty | sed -n 's/^shlibs:Depends=//p')"; \
    version="$(sed -n -E 's/^[[:space:]]*\.version = "([^"]+)".*/\1/p' build.zig.zon)"; \
    test -n "$depends"; \
    test -n "$version"; \
    printf 'Package: ghostty\nVersion: %s\nArchitecture: %s\nMaintainer: Ghostty contributors\nDepends: %s\nDescription: Ghostty terminal emulator\n' \
        "$version" "$(dpkg --print-architecture)" "$depends" > /output/DEBIAN/control; \
    dpkg-deb --build --root-owner-group /output /ghostty.deb

FROM scratch AS artifact
COPY --from=build /ghostty.deb /ghostty.deb
