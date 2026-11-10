# macbench.sh's image: the build image plus the game on the host's own Mono, drawn by llvmpipe on Xvfb, and Linux perf
FROM glosports-stardew

RUN apt-get update && apt-get install -y --no-install-recommends \
    xvfb imagemagick libsdl2-2.0-0 libasound2-dev libgl1-mesa-dri libegl1 libgles2 linux-perf \
    && rm -rf /var/lib/apt/lists/*
