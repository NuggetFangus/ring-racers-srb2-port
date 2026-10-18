#!/bin/bash
# Script de lançamento para o ArkOS (R36S). Coloque em <roms>/ports/RingRacers.sh
# e a pasta "ringracers" (binário + .pk3 oficiais) ao lado dele.

if [ -d "/roms2/ports/ringracers" ]; then
	GAMEDIR="/roms2/ports/ringracers"
else
	GAMEDIR="/roms/ports/ringracers"
fi
cd "$GAMEDIR" || exit 1

# Config, saves e addons ficam dentro da pasta do jogo (.ringracers).
export HOME="$GAMEDIR"
# Onde o jogo procura os .pk3 oficiais.
export SRB2WADDIR="$GAMEDIR"
# SDL2 do ArkOS usa KMSDRM por padrão; descomente se precisar forçar.
# export SDL_VIDEODRIVER=kmsdrm

# O ArkOS espera que a porta use /dev/tty1 e libere a tela ao sair.
printf "\033c" > /dev/tty1

./ringracers -width 640 -height 480 > "$GAMEDIR/log.txt" 2>&1

printf "\033c" > /dev/tty1
