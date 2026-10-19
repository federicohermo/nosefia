FROM ubuntu:24.04@sha256:68ee22004a9109b44973313b02ff7b1de250f1de0f5ecb628d73f579aaff33ac
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential g++-mingw-w64-x86-64-posix python3 python3-venv \
    ca-certificates curl git unzip pkg-config libx11-dev libxcursor-dev \
    libxinerama-dev libxi-dev libxrandr-dev libwayland-dev libxkbcommon-dev \
    libgl1-mesa-dev libglu1-mesa-dev libasound2-dev libpulse-dev libudev-dev \
    && python3 -m venv /opt/scons \
    && /opt/scons/bin/pip install SCons==4.9.1
ENV PATH=/opt/scons/bin:$PATH
WORKDIR /work
