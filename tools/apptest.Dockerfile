# apptest.sh's image: only what goodluckOS has for the app (glibc, libgcc and zlib for armhf, BusyBox), with
# qemu-arm to run it and Python to unpack the zip; no Mono of its own, which the port's would load libraries from.
# As on the console, sh is a setuid BusyBox (glibc drops LD_LIBRARY_PATH in a new sh) and the app runs as player
FROM debian:trixie-slim

RUN dpkg --add-architecture armhf && apt-get update && apt-get install -y --no-install-recommends \
    qemu-user busybox python3 libc6:armhf libgcc-s1:armhf zlib1g:armhf \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -u 1000 player && chmod u+s /bin/busybox && ln -sf /bin/busybox /bin/sh
