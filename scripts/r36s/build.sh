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
apt-get install -y --no-install-recommends \
	build-essential git ca-certificates pkg-config python3 python3-pip python3-setuptools \
	libsdl2-dev libcurl4-openssl-dev zlib1g-dev libpng-dev libopus-dev

# cmake do buster é 3.13; o projeto pede >= 3.14.
python3 -m pip install -U pip
python3 -m pip install cmake ninja

git config --global --add safe.directory "$SRC"

echo "== glibc do container: $(ldd --version | head -1)"
echo "== gcc: $(gcc --version | head -1)"

# -lstdc++fs: o gcc 8 precisa disso para std::filesystem.
CPUFLAGS="-mcpu=cortex-a35 -O2"
cmake -S "$SRC" -B "$BUILD" -G Ninja \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_C_FLAGS="$CPUFLAGS" \
	-DCMAKE_CXX_FLAGS="$CPUFLAGS" \
	-DCMAKE_EXE_LINKER_FLAGS="-static-libstdc++ -static-libgcc" \
	-DCMAKE_CXX_STANDARD_LIBRARIES="-lstdc++fs" \
	-DCMAKE_PROJECT_INCLUDE="$SRC/scripts/r36s/sdl2-shim.cmake" \
	-DSRB2_CONFIG_GLES2=ON \
	-DSRB2_CONFIG_ENABLE_WEBM_MOVIES=OFF \
	-DSRB2_CONFIG_ENABLE_DISCORDRPC=OFF

cmake --build "$BUILD" -j"$(nproc)"

BIN=$(find "$BUILD/bin" -maxdepth 1 -type f -perm -u+x | head -1)
echo "== binário: $BIN"
strip "$BIN" || true
cp "$BIN" "$OUT/ringracers"

# Mostra a versão máxima de glibc exigida (deve ser <= a do ArkOS).
objdump -T "$OUT/ringracers" | grep -o 'GLIBC_[0-9.]*' | sort -uV | tail -3 || true
ldd "$OUT/ringracers" || true
