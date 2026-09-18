#!/usr/bin/env bash
# dsh-model-optimum —— 一键安装（Linux/macOS；镜像 install.ps1）
#
# 形态照 `dsh-omc/install.sh`：分步 + 环境预检 + 逐包报状态。
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKGS_DIR="$ROOT/packages"
PROFILE="${PROFILE:-web}"
# DSH_HOME 优先：部署环境 homedir 可能与 DSH_HOME 不一致
DSH_HOME="${DSH_HOME:-$HOME/.dsh}"
# ★ 必须 export —— 否则子进程会用 os.homedir() 重新推（本机实测两者可能不同账号）
export DSH_HOME

if [ -t 1 ]; then
  C_CYAN=$'\e[36m'; C_GREEN=$'\e[32m'; C_YELLOW=$'\e[33m'; C_RED=$'\e[31m'; C_RESET=$'\e[0m'
else
  C_CYAN=''; C_GREEN=''; C_YELLOW=''; C_RED=''; C_RESET=''
fi
info() { printf '%s=== %s ===%s\n' "$C_CYAN" "$1" "$C_RESET"; }
ok()   { printf '%s✓ %s%s\n'  "$C_GREEN" "$1" "$C_RESET"; }
warn() { printf '%s! %s%s\n'  "$C_YELLOW" "$1" "$C_RESET"; }
err()  { printf '%s✗ %s%s\n'  "$C_RED" "$1" "$C_RESET"; }

PASS_LIST=(); FAIL_LIST=(); SKIP_LIST=()

info '[0/3] 环境预检'
command -v node >/dev/null 2>&1 && ok "node: $(node --version)" || { err '未找到 node'; exit 1; }
if command -v dsh >/dev/null 2>&1; then DSH_CMD=(dsh); ok "dsh: $(command -v dsh)"
else warn 'dsh 不在 PATH —— 回退 `npx @deepseek-ai/dsh`'; DSH_CMD=(npx '@deepseek-ai/dsh'); fi
echo "仓库目录 : $ROOT"
echo "DSH_HOME  : $DSH_HOME"
echo "profile   : $PROFILE"
[ "${DRY_RUN:-0}" = "1" ] && warn 'DRY_RUN=1 —— 只打印，不执行'

info '[1/3] 逐包装配（packages/）'
for d in "$PKGS_DIR"/*/; do
  name="$(basename "$d")"
  if [ ! -f "$d/package.json" ]; then warn "$name：无 package.json（跳过）"; SKIP_LIST+=("$name"); continue; fi
  if [ "${DRY_RUN:-0}" = "1" ]; then ok "$name：将执行 ${DSH_CMD[*]} plugin --profile $PROFILE add $d"; PASS_LIST+=("$name"); continue; fi
  if "${DSH_CMD[@]}" plugin --profile "$PROFILE" add "$d" >/dev/null 2>&1; then ok "$name"; PASS_LIST+=("$name")
  else err "$name（可单独重试：${DSH_CMD[*]} plugin --profile $PROFILE add $d）"; FAIL_LIST+=("$name"); fi
done

info '[2/3] 能力自检（这两个包没有 dsh.bundle ⇒ 需注入）'
for d in "$PKGS_DIR"/*/; do
  name="$(basename "$d")"
  pj="$d/package.json"
  [ -f "$pj" ] || continue
  if grep -q '"bundle"' "$pj" 2>/dev/null; then ok "$name：有 dsh.bundle（官方装配路径有效）"
  else warn "$name：**无 dsh.bundle** ⇒ 走"装配成 bundle"不会激活 ⇒ 需注入：dev_inject_plugin $d"; fi
done

info '[3/3] 汇总'
echo "── 合计：装了 ${#PASS_LIST[@]} 个 · 跳过 ${#SKIP_LIST[@]} 个 · 失败 ${#FAIL_LIST[@]} 个 ──"
for x in "${PASS_LIST[@]:-}"; do [ -n "$x" ] && echo "  ✅ $x"; done
for x in "${SKIP_LIST[@]:-}"; do [ -n "$x" ] && echo "  ⏭  $x（跳过）"; done
for x in "${FAIL_LIST[@]:-}"; do [ -n "$x" ] && echo "  ❌ $x（失败）"; done
echo
echo '⇒ 下一步：**新开一个会话**（当前窗口的预设列表不会变）'
[ "${#FAIL_LIST[@]}" -gt 0 ] && { err '有包装配失败（本脚本可重复运行，幂等）'; exit 1; }
