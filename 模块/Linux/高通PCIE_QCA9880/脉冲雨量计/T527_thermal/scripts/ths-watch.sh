#!/bin/sh
# =============================================================================
# ths-watch.sh —— T527(OKT527-C) 运行时温度快照/巡检（排障用，不改内核）
#
# 用途：
#   1) 稳态基线：sh ths-watch.sh base 10
#   2) 满载对照：for i in 1 2 3 4 5 6 7 8; do (while :; do :; done) & done ; sh ths-watch.sh load 30
#   3) 与外部测温（红外枪/热电偶量 SoC 表面）同步记录做交叉校验
#
# 输出字段：
#   z0..z5    thermal_zone*/temp  → z0=cpul z1=cpub z2=gpu z3=npu z4=ddr z5=axp2202(PMU)
#   raw_c0/1  ths1 原始码（0x020094C0=cpub / 0x020094C4=cpul，十进制）+ 换算温度
#   calib     校准寄存器 0x020094A0/0x020094A4（默认应为 0x800；实测非默认=校准已写入）
#   ntc_avg   GPADC CH3 温度传感器 8 次平均(mV)，℃ =(mV-500)/10，并给出 min/max 看噪声
#   freq      policy*/scaling_cur_freq（板子上是 policy0/policy4）
# =============================================================================

LABEL=${1:-snap}
COUNT=${2:-10}
GPADC=/sys/class/gpadc/gpadc_chip0/data

rd()  { cat "$1" 2>/dev/null; }
raw() { devmem "$1" 2>/dev/null; }

code2c() {
	awk -v v="$1" 'BEGIN{
		if (v !~ /^[0-9]+$/) { printf "?"; exit }
		if (v > 1991) printf "%.1f", (2736 - v) * 0.074
		else          printf "%.1f", (2825 - v) * 0.065
	}' 2>/dev/null
}
mc2c() {
	awk -v t="$1" 'BEGIN{ if (t !~ /^-?[0-9]+$/) printf "?"; else printf "%.1f", t/1000 }' 2>/dev/null
}
now() { date '+%H:%M:%S' 2>/dev/null || cut -d' ' -f1 /proc/uptime; }

i=0
while [ "$i" -lt "$COUNT" ]; do
	i=$((i + 1))
	out="[$LABEL] $(now) up=$(cut -d' ' -f1 /proc/uptime)"

	z=0
	while [ "$z" -le 5 ]; do
		t=$(rd /sys/class/thermal/thermal_zone$z/temp)
		if [ -n "$t" ]; then out="$out z$z=$(mc2c "$t")C"; else out="$out z$z=NA"; fi
		z=$((z + 1))
	done

	h0=$(raw 0x020094C0); h1=$(raw 0x020094C4)
	case "$h0" in 0x[0-9a-fA-F]*) c0=$((0x${h0#0x})) ;; *) c0="?" ;; esac
	case "$h1" in 0x[0-9a-fA-F]*) c1=$((0x${h1#0x})) ;; *) c1="?" ;; esac
	out="$out raw_c0=$c0($(code2c "$c0")C) raw_c1=$c1($(code2c "$c1")C)"
	out="$out calib=$(raw 0x020094A0)/$(raw 0x020094A4)"

	# GPADC CH3：单次读数噪声大，取 8 次平均并给出 min/max
	echo 3 > $GPADC 2>/dev/null
	sum=0; cnt=0; mn=; mx=; k=0
	while [ "$k" -lt 8 ]; do
		v=$(rd $GPADC | awk '{print $NF}')
		case "$v" in
			''|*[!0-9]*) ;;
			*) sum=$((sum + v)); cnt=$((cnt + 1))
			   if [ -z "$mn" ] || [ "$v" -lt "$mn" ]; then mn=$v; fi
			   if [ -z "$mx" ] || [ "$v" -gt "$mx" ]; then mx=$v; fi ;;
		esac
		k=$((k + 1))
	done
	if [ "$cnt" -gt 0 ]; then
		avg=$((sum / cnt))
		out="$out ntc_avg=${avg}mV($(awk -v v="$avg" 'BEGIN{printf "%.1f",(v-500)/10}')C,min=$mn,max=$mx)"
	else
		out="$out ntc_avg=NA"
	fi

	fq=""
	for p in /sys/devices/system/cpu/cpufreq/policy*; do
		[ -d "$p" ] || continue
		fq="$fq $(basename "$p")=$(rd $p/scaling_cur_freq)"
	done
	out="$out freq:${fq:-NA}"

	echo "$out"
	if [ "$i" -lt "$COUNT" ]; then
		sleep 1
	fi
done
