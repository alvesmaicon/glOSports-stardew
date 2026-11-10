# The port's build image: Debian with the armhf cross compiler and libraries, Mono's C# compiler for the port's own
# assemblies and qemu-arm to run the console's Mono. Native on amd64 and arm64 hosts (Apple Silicon under Colima).
FROM debian:trixie

RUN dpkg --add-architecture armhf && apt-get update && apt-get install -y --no-install-recommends \
    build-essential crossbuild-essential-armhf pkg-config git ca-certificates curl file zip unzip python3 \
    cmake ninja-build mono-mcs mono-runtime qemu-user \
    libasound2-dev:armhf libdrm-dev:armhf libegl-dev:armhf libgles-dev:armhf libgbm-dev:armhf \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /repo
