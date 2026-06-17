#!/usr/bin/env bash
R=$'\e[38;2;224;86;59m'
RH=$'\e[38;2;239;106;79m'
D=$'\e[38;2;51;55;63m'
K=$'\e[38;2;63;69;80m'
S=$'\e[38;2;139;145;156m'
T=$'\e[38;2;196;204;218m'
DIM=$'\e[38;2;91;102;120m'
G=$'\e[38;2;91;191;115m'
X=$'\e[0m'

clock=$(date +%H:%M)
day=$(LC_TIME=C date "+%A · %-d %b")

up=$(awk '{print int($1)}' /proc/uptime)
ud=$((up/86400)); uh=$(((up%86400)/3600)); um=$(((up%3600)/60))
if [ "$ud" -gt 0 ]; then upt="${ud}d ${uh}h"; else upt="${uh}h ${um}m"; fi

read -ra a < /proc/stat
sleep 0.08
read -ra b < /proc/stat
t1=0; for v in "${a[@]:1}"; do t1=$((t1+v)); done
t2=0; for v in "${b[@]:1}"; do t2=$((t2+v)); done
id1=$((a[4]+a[5])); id2=$((b[4]+b[5]))
dt=$((t2-t1)); di=$((id2-id1))
cpu=$(( dt>0 ? 100*(dt-di)/dt : 0 ))

ctemp="--"
for hw in /sys/class/hwmon/*; do
    if [ "$(cat "$hw/name" 2>/dev/null)" = "k10temp" ]; then
        for lbl in "$hw"/temp*_label; do
            [ "$(cat "$lbl" 2>/dev/null)" = "Tctl" ] && ctemp=$(( $(cat "${lbl%_label}_input") / 1000 ))
        done
        [ "$ctemp" = "--" ] && [ -r "$hw/temp1_input" ] && ctemp=$(( $(cat "$hw/temp1_input") / 1000 ))
        break
    fi
done

gpu="--"; gtemp="--"
if command -v nvidia-smi >/dev/null 2>&1; then
    g=$(nvidia-smi --query-gpu=utilization.gpu,temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -1)
    gpu=$(echo "$g" | awk -F, '{gsub(/ /,"");print $1}')
    gtemp=$(echo "$g" | awk -F, '{gsub(/ /,"");print $2}')
fi

mt=$(awk '/MemTotal/{print $2}' /proc/meminfo)
ma=$(awk '/MemAvailable/{print $2}' /proc/meminfo)
mu=$((mt-ma))
rused=$(awk "BEGIN{printf \"%.1f\",$mu/1048576}")
rtot=$(awk "BEGIN{printf \"%.0f\",$mt/1048576}")
rpct=$((100*mu/mt))

read -r dpct davail < <(df -BG --output=pcent,avail / 2>/dev/null | tail -1)
dpct=${dpct// /}; davail=${davail// /}; davail=${davail%G}

i3="${R}${clock}${X}"
i4="${DIM}${day} · up ${upt}${X}"
i6="${DIM}cpu  ${G}${cpu}%${DIM} · ${ctemp}°C${X}"
i7="${DIM}gpu  ${G}${gpu}%${DIM} · ${gtemp}°C${X}"
i8="${DIM}ram  ${T}${rused} ${DIM}/ ${rtot} GB · ${T}${rpct}%${X}"
i9="${DIM}disk ${T}${dpct} ${DIM}· ${davail} GB free${X}"

echo
printf '%s\n' "${K}      ╱▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔╲${X}"
printf '%s\n' "${K}   ▗▄████████████████████▄▖${X}"
printf '%s\n' "${D}      ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀${X}        ${i3}"
printf '%s\n' "${R}        ███   ${D}▐▌${R}   ███${X}          ${i4}"
printf '%s\n' "${R}    ▄▄▄▄███▄▄▄▄▄▄▄▄███▄▄▄▄${X}"
printf '%s\n' "${RH}    ▀▀▀▀███▀▀▀▀▀▀▀▀███▀▀▀▀${X}      ${i6}"
printf '%s\n' "${R}        ███        ███${X}          ${i7}"
printf '%s\n' "${R}        ███        ███${X}          ${i8}"
printf '%s\n' "${R}        ███        ███${X}          ${i9}"
printf '%s\n' "${R}        ███        ███${X}"
printf '%s\n' "${S}       ▟███▙      ▟███▙${X}"
echo
