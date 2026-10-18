#!/bin/bash
# Roda DENTRO de um container arm64 antigo (debian:buster por padrão), para que o
# binário só dependa de símbolos de glibc antigos e rode no ArkOS do R36S.
#
# Uso (feito pelo workflow):
#   docker run --rm -v "$PWD":/src -v "$PWD/out":/out debian:buster bash /src/scripts/r36s/build.sh
set -euo pipefail

SRC=/src
BUILD=/tmp/build
OUT=/out
SDL_VER=2.30.9
SDL_PREFIX=/opt/sdl2
mkdir -p "$OUT"

# debian:buster saiu do mirror principal; usa o arquivo.
if grep -q buster /etc/os-release 2>/dev/null; then
	# Precisa incluir updates e security: a imagem já vem com pacotes (ex. zlib1g)
	# da versão de segurança, e sem esses repositórios as dependências -dev conflitam.
	cat > /etc/apt/sources.list <<'EOF'
deb http://archive.debian.org/debian buster main
deb http://archive.debian.org/debian buster-updates main
deb http://archive.debian.org/debian-security buster/updates main
EOF
	echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99archive
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update
# Sem libsdl2-dev: o SDL2 do buster (2.0.9) é velho demais; compilamos um novo abaixo.
apt-get install -y --no-install-recommends \
	build-essential git curl ca-certificates pkg-config python3 python3-pip python3-setuptools \
	libcurl4-openssl-dev zlib1g-dev libpng-dev libopus-dev \
	libasound2-dev libudev-dev libdrm-dev libgbm-dev libegl1-mesa-dev libgles2-mesa-dev

# cmake do buster é 3.13; o projeto pede >= 3.14.
python3 -m pip install -U pip
python3 -m pip install cmake ninja

git config --global --add safe.directory "$SRC"

echo "== glibc do container: $(ldd --version | head -1)"
echo "== gcc: $(gcc --version | head -1)"

CPUFLAGS="-mcpu=cortex-a35 -O2"

# --- SDL2 novo, estático, com KMSDRM + GLES (sem X11/Wayland) ---
# O jogo usa SDL_GetErrorMsg (2.0.14+) e SDL_WINDOWEVENT_DISPLAY_CHANGED (2.0.18+).
# libEGL/libgbm/libdrm são carregados via dlopen em tempo de execução (os do aparelho).
mkdir -p /tmp/sdl && cd /tmp/sdl
curl -fsSL "https://github.com/libsdl-org/SDL/releases/download/release-${SDL_VER}/SDL2-${SDL_VER}.tar.gz" | tar xz
cmake -S "SDL2-${SDL_VER}" -B sdl-build -G Ninja \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_C_FLAGS="$CPUFLAGS" \
	-DCMAKE_INSTALL_PREFIX="$SDL_PREFIX" \
	-DSDL_SHARED=OFF -DSDL_STATIC=ON -DSDL_STATIC_PIC=ON -DSDL_TEST=OFF \
	-DSDL_X11=OFF -DSDL_WAYLAND=OFF \
	-DSDL_KMSDRM=ON -DSDL_OPENGLES=ON -DSDL_OPENGL=OFF -DSDL_VULKAN=OFF \
	-DSDL_PULSEAUDIO=OFF -DSDL_PIPEWIRE=OFF -DSDL_JACK=OFF -DSDL_SNDIO=OFF \
	-DSDL_DBUS=OFF -DSDL_IBUS=OFF
cmake --build sdl-build -j"$(nproc)"
cmake --install sdl-build
cd /

# --- Ring Racers ---
# Opções espelham o build Android (android/app/build.gradle): só o backend RHI.
# -lstdc++fs: o gcc 8 precisa disso para std::filesystem.
cmake -S "$SRC" -B "$BUILD" -G Ninja \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_C_FLAGS="$CPUFLAGS" \
	-DCMAKE_CXX_FLAGS="$CPUFLAGS" \
	-DCMAKE_EXE_LINKER_FLAGS="-static-libstdc++ -static-libgcc" \
	-DCMAKE_CXX_STANDARD_LIBRARIES="-lstdc++fs" \
	-DSDL2_DIR="$SDL_PREFIX/lib/cmake/SDL2" \
	-DSRB2_CONFIG_GLES2=ON \
	-DSRB2_CONFIG_HWRENDER=OFF \
	-DSRB2_CONFIG_USEASM=OFF \
	-DSRB2_CONFIG_EXECINFO=OFF \
	-DSRB2_CONFIG_ENABLE_WEBM_MOVIES=OFF \
	-DSRB2_CONFIG_ENABLE_DISCORDRPC=OFF

# -k 0: não para no primeiro erro, para o log mostrar todos os problemas de uma vez.
cmake --build "$BUILD" -j"$(nproc)" -- -k 0

BIN=$(find "$BUILD/bin" -maxdepth 1 -type f -perm -u+x | head -1)
echo "== binário: $BIN"
strip "$BIN" || true
cp "$BIN" "$OUT/ringracers"

# Mostra a versão máxima de glibc exigida (deve ser <= a do ArkOS).
objdump -T "$OUT/ringracers" | grep -o 'GLIBC_[0-9.]*' | sort -uV | tail -3 || true
ldd "$OUT/ringracers" || true
