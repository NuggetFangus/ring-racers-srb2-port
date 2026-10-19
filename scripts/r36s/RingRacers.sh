#!/bin/bash
# Script de lançamento para o ArkOS (R36S). Coloque em <roms>/ports/RingRacers.sh
# e a pasta "ringracers" (binário + libs + dados do jogo) ao lado dele.
# SELECT + START fecha o jogo.

if [ -d "/roms2/ports/ringracers" ]; then
	GAMEDIR="/roms2/ports/ringracers"
else
	GAMEDIR="/roms/ports/ringracers"
fi
cd "$GAMEDIR" || exit 1

# Config, saves e addons ficam dentro da pasta do jogo (.ringracers).
export HOME="$GAMEDIR"
# Onde o jogo procura os .pk3 oficiais (bios.pk3 aqui e o resto em data/).
export SRB2WADDIR="$GAMEDIR"
# Bibliotecas que vêm junto com o jogo (libpng com APNG, curl, opus...) têm prioridade
# sobre as do sistema, que podem estar faltando ou ser de outra versão.
export LD_LIBRARY_PATH="$GAMEDIR/libs:$LD_LIBRARY_PATH"
# SDL2 do ArkOS usa KMSDRM por padrão; descomente se precisar forçar.
# export SDL_VIDEODRIVER=kmsdrm

# Mapeamento de controles do ArkOS: sem ele o SDL pode não reconhecer o gamepad do
# aparelho como "controle", e aí nem os botões nem o atalho SELECT+START funcionam.
for db in /opt/inttools/gamecontrollerdb.txt \
          /roms/ports/PortMaster/gamecontrollerdb.txt \
          /roms2/ports/PortMaster/gamecontrollerdb.txt; do
	if [ -f "$db" ]; then
		export SDL_GAMECONTROLLERCONFIG_FILE="$db"
		break
	fi
done

# Desempenho: coloca a CPU no governor "performance" enquanto o jogo roda e restaura
# o original ao sair. Silencioso se não houver permissão (o jogo roda do mesmo jeito).
OLD_GOV=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null)
set_gov() {
	for f in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
		[ -e "$f" ] || continue
		echo "$1" | sudo -n tee "$f" >/dev/null 2>&1 || echo "$1" > "$f" 2>/dev/null
	done
}
if [ -n "$OLD_GOV" ]; then
	set_gov performance
	trap 'set_gov "$OLD_GOV"' EXIT
fi

# O ArkOS espera que a porta use /dev/tty1 e libere a tela ao sair.
printf "\033c" > /dev/tty1

echo "governor original: ${OLD_GOV:-desconhecido}; gamepad db: ${SDL_GAMECONTROLLERCONFIG_FILE:-nenhum}" > "$GAMEDIR/log.txt"
./ringracers -width 640 -height 480 >> "$GAMEDIR/log.txt" 2>&1

printf "\033c" > /dev/tty1
