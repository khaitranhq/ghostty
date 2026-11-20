# Build Ghostty for an Ubuntu 26.04 host without installing Zig on the host.
FROM ubuntu:26.04 AS build

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    curl \
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

# DESTDIR preserves the /usr/local layout for copying onto the host.
RUN DESTDIR=/output zig build --prefix /usr/local \
    -Doptimize=ReleaseFast -Dcpu=baseline \
    && /output/usr/local/bin/ghostty +version

FROM scratch AS artifact
COPY --from=build /output/ /
