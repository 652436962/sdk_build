#!/bin/sh
# =============================================================================
# watchdog-test.sh —— T527(OKT527-C A1) 硬件看门狗(HW watchdog)测试脚本
#
# 硬件接线（A1 版本板载硬件狗）：
#   供电  PE8 = gpio136   输出高电平为看门狗供电
#   喂狗  PE7 = gpio135   周期翻转；翻转间隔须 < 看门狗超时(60S)
#   超时  60S
#
# 参考：openharmony_T527/GY-C220D_采集器硬件外设.md →「A1版本添加硬件看门狗」
#
# 用法：
#   sh watchdog-test.sh start       上电 + 后台喂狗（默认每 30S 翻转喂狗脚）
#   sh watchdog-test.sh stop        停止喂狗 + 断电（安全停止）
#   sh watchdog-test.sh status      查看两个 GPIO 与喂狗进程状态
#   sh watchdog-test.sh feed        手动喂狗一次（翻转喂狗脚）
#   sh watchdog-test.sh test [SEC]  保持供电但不喂狗，观察是否复位（默认等 70S）
#   sh watchdog-test.sh perm        放开 GPIO 文件权限（免 root 操作）
#
# 移植到其它开发板：只修改下方「板级硬件配置（宏定义）」一节即可。
# 说明：写 GPIO 的 value/direction 需要 root；普通用户可先执行 `perm`
#       或配置 udev 规则 `SUBSYSTEM=="gpio", MODE="0666"`。
# =============================================================================
set -u

# =============================================================================
# 板级硬件配置（宏定义）—— 更换开发板时只需修改本节
# =============================================================================
WDT_BOARD="OKT527-C (A1)"	# 目标板卡
WDT_PWR_PIN="PE8"		# 看门狗供电引脚
WDT_PWR_GPIO=136		# 供电引脚 sysfs GPIO 编号
WDT_FEED_PIN="PE7"		# 看门狗喂狗引脚
WDT_FEED_GPIO=135		# 喂狗引脚 sysfs GPIO 编号
WDT_TIMEOUT=60			# 看门狗超时时间(秒)
WDT_HALF=30			# 喂狗翻转半周期(秒)，须 < WDT_TIMEOUT
# =============================================================================

GPIO=/sys/class/gpio
# pid 文件所在目录：OpenHarmony(鸿蒙) 根文件系统的 /tmp 为只读，无法写入 pid 文件，
# 故按可写性在候选目录中自动选择（Linux 命中 /tmp，鸿蒙命中 /data/local/tmp）。
PIDDIR=
for _d in /tmp /var/tmp /data/local/tmp; do
	( : > "$_d/.wdt-pid.test" ) 2>/dev/null && { rm -f "$_d/.wdt-pid.test"; PIDDIR="$_d"; break; }
done
[ -n "$PIDDIR" ] || PIDDIR=/tmp
PIDFILE="$PIDDIR/watchdog-feed.pid"

say() { echo "[watchdog] $*"; }
err() { echo "[watchdog] ERROR: $*" >&2; }

need_root() {
	[ "$(id -u)" = "0" ] || { err "需要 root 权限，请用 sudo 运行"; exit 1; }
}

gdir() { echo "$GPIO/gpio$1"; }

export_gpio() {
	d=$(gdir "$1")
	[ -d "$d" ] && return 0
	echo "$1" > "$GPIO/export" 2>/dev/null || { err "导出 gpio$1 失败"; return 1; }
	n=0
	while [ ! -d "$d" ] && [ "$n" -lt 20 ]; do sleep 0.1; n=$((n + 1)); done
	[ -d "$d" ] || { err "gpio$1 目录未生成"; return 1; }
}

set_out() { export_gpio "$1" && echo out > "$(gdir "$1")/direction" 2>/dev/null; }
set_val() { echo "$2" > "$(gdir "$1")/value" 2>/dev/null; }

power_on()  { set_out "$WDT_PWR_GPIO" && set_val "$WDT_PWR_GPIO" 1 && say "供电 $WDT_PWR_PIN(gpio$WDT_PWR_GPIO)=1"; }
power_off() { set_val "$WDT_PWR_GPIO" 0 && say "供电 $WDT_PWR_PIN(gpio$WDT_PWR_GPIO)=0"; }

feed_once() {
	set_out "$WDT_FEED_GPIO" || return 1
	cur=$(cat "$(gdir "$WDT_FEED_GPIO")/value" 2>/dev/null)
	[ "$cur" = "1" ] && nxt=0 || nxt=1
	set_val "$WDT_FEED_GPIO" "$nxt" || return 1
	say "喂狗 $WDT_FEED_PIN(gpio$WDT_FEED_GPIO) -> $nxt"
}

feed_loop() {
	while :; do
		feed_once >/dev/null 2>&1 || exit 1
		sleep "$WDT_HALF"
	done
}

running() {
	[ -f "$PIDFILE" ] || return 1
	p=$(cat "$PIDFILE" 2>/dev/null)
	[ -n "$p" ] && kill -0 "$p" 2>/dev/null
}

do_start() {
	need_root
	say "板卡: $WDT_BOARD"
	power_on || exit 1
	set_out "$WDT_FEED_GPIO" || exit 1
	set_val "$WDT_FEED_GPIO" 0
	if running; then
		say "喂狗进程已在运行 (pid $(cat "$PIDFILE"))"
	else
		# 重定向标准 IO，避免后台喂狗进程占住调用方(如 hdc shell)的会话
		feed_loop >/dev/null 2>&1 </dev/null &
		echo $! > "$PIDFILE"
		say "已后台喂狗：每 ${WDT_HALF}S 翻转 $WDT_FEED_PIN(gpio$WDT_FEED_GPIO)，pid $(cat "$PIDFILE")"
	fi
}

do_stop() {
	if running; then
		kill "$(cat "$PIDFILE")" 2>/dev/null && say "已停止喂狗进程 (pid $(cat "$PIDFILE"))"
		rm -f "$PIDFILE"
	else
		say "无运行中的喂狗进程"
	fi
	power_off
}

do_feed() { need_root; feed_once; }

do_status() {
	say "板卡: $WDT_BOARD (超时 ${WDT_TIMEOUT}S)"
	for g in "$WDT_PWR_GPIO" "$WDT_FEED_GPIO"; do
		d=$(gdir "$g")
		if [ -d "$d" ]; then
			say "gpio$g: direction=$(cat "$d/direction" 2>/dev/null) value=$(cat "$d/value" 2>/dev/null)"
		else
			say "gpio$g: 未导出"
		fi
	done
	if running; then
		say "喂狗进程: running (pid $(cat "$PIDFILE"), 间隔 ${WDT_HALF}S)"
	else
		say "喂狗进程: 未运行"
	fi
}

do_test() {
	sec=${1:-70}
	need_root
	# 保持供电，仅停止喂狗 → 看门狗应在超时内复位
	if running; then kill "$(cat "$PIDFILE")" 2>/dev/null; rm -f "$PIDFILE"; fi
	power_on
	say "已停止喂狗(保持供电)，预期约 ${WDT_TIMEOUT}S 后复位；等待 ${sec}S..."
	sleep "$sec"
	say "若未复位：检查 $WDT_PWR_PIN 供电、$WDT_FEED_PIN 接线，或确认板卡是否已焊装看门狗"
}

do_perm() {
	need_root
	for g in "$WDT_PWR_GPIO" "$WDT_FEED_GPIO"; do
		export_gpio "$g" || continue
		d=$(gdir "$g")
		chmod 666 "$d/value" "$d/direction" 2>/dev/null && say "已放开 gpio$g 权限"
	done
	say "完成（也可用 udev 规则持久化：SUBSYSTEM==\"gpio\", MODE=\"0666\"）"
}

case "${1:-}" in
	start)  do_start ;;
	stop)   do_stop ;;
	status) do_status ;;
	feed)   do_feed ;;
	test)   shift; do_test "${1:-70}" ;;
	perm)   do_perm ;;
	*) echo "用法: $0 {start|stop|status|feed|test [SEC]|perm}"; exit 2 ;;
esac
