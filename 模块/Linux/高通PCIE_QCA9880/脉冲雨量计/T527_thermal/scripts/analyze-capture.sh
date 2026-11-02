#!/bin/bash
# =============================================================================
# analyze-capture.sh —— 分析 S00thslog 抓回来的开机采样日志（本地侧，用 bash/awk）
#
# 用法：
#   ./analyze-capture.sh captures/ths-boot-YYYYmmdd-HHMMSS.log
#
# 输出：
#   1) 每次启动的采样段（按 uptime 回退切分）：样本数/时间范围/极值
#   2) 每个采样段的 cpul(c1)/cpub(c0) 原始码最小值与出现时刻
#      （码越小温度越高：2101→47C、1900→60C、1500→86C、1200→106C、1000→119C、825→130C；
#        注：code<=1991 走 (2825-code)*0.065 这一支，故 130C 对应 code≈825）
#   3) 可疑行（温度 >=60C 或 raw_c1<1950）明细，最多 30 条
#   4) 判定提示：出现"只持续不到 2 秒的采样段"通常意味着该次启动在 8.6s 被热保护关机
# =============================================================================
set -u
F=${1:-}
[ -n "$F" ] && [ -f "$F" ] || { echo "用法: $0 <ths-boot-*.log>"; exit 1; }

code2c() { awk -v v="$1" 'BEGIN{ if(v>1991) printf "%.1f",(2736-v)*0.074; else printf "%.1f",(2825-v)*0.065 }'; }

echo "文件: $F"
echo "总行数: $(wc -l < "$F")"

awk '
/^\[THS\] up=/ {
    split($2, a, "="); up = a[2] + 0
    if (up < prev) { seg++ }
    prev = up
    if (!(seg in first)) { first[seg] = up; firstline[seg] = NR }
    last[seg] = up; cnt[seg]++
    for (i = 1; i <= NF; i++) {
        if ($i ~ /^raw_c1=/) { split($i, b, "="); v = b[2] + 0
            if (v > 0 && (minc1[seg] == "" || v < minc1[seg])) { minc1[seg] = v; minc1at[seg] = up } }
        if ($i ~ /^raw_c0=/) { split($i, b, "="); v = b[2] + 0
            if (v > 0 && (minc0[seg] == "" || v < minc0[seg])) { minc0[seg] = v; minc0at[seg] = up } }
        if ($i ~ /^z0=/) { split($i, b, "="); v = b[2] + 0
            if (v > maxz0[seg]) { maxz0[seg] = v; maxz0at[seg] = up } }
        if ($i ~ /^z1=/) { split($i, b, "="); v = b[2] + 0
            if (v > maxz1[seg]) { maxz1[seg] = v; maxz1at[seg] = up } }
    }
}
END {
    segs = (seg == "" ? 0 : seg)
    printf "\n=== 采样段数: %d (按 uptime 回退切分) ===\n", segs
    for (s = 0; s <= segs; s++) {
        if (cnt[s] == "") continue
        printf "\n--- 段 %d: %d 个样本, up %.2f ~ %.2f s, 持续 %.2f s (起始行 %d) ---\n",
               s, cnt[s], first[s], last[s], last[s] - first[s], firstline[s]
        printf "  cpul(ch1) 最小码 = %s (%s C) @up=%s\n", (minc1[s]==""?"NA":minc1[s]),
               (minc1[s]==""?"NA":sprintf("%.1f",(minc1[s]>1991?(2736-minc1[s])*0.074:(2825-minc1[s])*0.065))), minc1at[s]
        printf "  cpub(ch0) 最小码 = %s (%s C) @up=%s\n", (minc0[s]==""?"NA":minc0[s]),
               (minc0[s]==""?"NA":sprintf("%.1f",(minc0[s]>1991?(2736-minc0[s])*0.074:(2825-minc0[s])*0.065))), minc0at[s]
        printf "  z0(cpul) 最高 = %.1f C @up=%s   z1(cpub) 最高 = %.1f C @up=%s\n",
               maxz0[s]/1000, maxz0at[s], maxz1[s]/1000, maxz1at[s]
        if (last[s] - first[s] < 2.0)
            printf "  ** 警告: 该段只持续 %.2f s —— 极可能是这次启动在 8.6s 被热保护关机 **\n", last[s] - first[s]
    }
}
' "$F"

echo
echo "=== 可疑行（最多 30 条）==="
grep -n "可疑" "$F" | head -30 || echo "（无）"

echo
echo "=== 各段结束标记 ==="
grep -n "^\[THS\] done" "$F" | head -10 || echo "（无）"

echo
echo "判读：某段 cpul 最小码骤降到 1000 附近而同期 cpub 码仍 ~2000 → 传感器/寄存器读数异常（假高温）；"
echo "      两通道同步缓慢下降、并随负载回落 → 真实升温。"
