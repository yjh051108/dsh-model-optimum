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

info '[2/3] ★ 激活自检（**不是"有 dsh.bundle 就算过"**）'
# ★★★ **为什么不能只查 `dsh.bundle` 字段存不存在**（2026-09-19 · 我踩过）：
# ```
# 【现场】`symbiote` 加了 `dsh.bundle` ⇒ `dsh.profile.bundles` 里有它 ⇒ **看起来"激活了"**
#   而 ★★ **它的 `insert.name` 写成了 `'dsh-symbiote'`（照源码的 `export const name`）** ⇒
#      **少了 `@dsh-external/` 前缀** ⇒ ★★★ **loader 会 `import('dsh-symbiote')` ⇒ `ERR_MODULE_NOT_FOUND`** ❌
#   ⇒ ★ 依据（DSH 本体源码逐字）：`cordis-plugin-loader/lib/index.js` 的 `_init()`：
#     `plugin = await this.parent.tree.import(this.options.name, …)`
#     ⇒ ★★ **`insert.name` 是【模块名】⇒ 必须 == `package.json.name`** ✅
# 【★ 读数】在装着该包的 profile 目录下：`import('@dsh-external/dsh-symbiote')` ⇒ OK ·
#   `import('dsh-symbiote')` ⇒ FAIL `ERR_MODULE_NOT_FOUND` ✅
# ⇒ ⇒ ★★★ **即："进了 `bundles`"只证明"过了 `reconcilePlugins()`" —— 不到"激活"** ✅
#   ⇒ 所以本步要**真解析一次**（**在 profile 目录里** —— 那里有完整解析链）
# ```
for d in "$PKGS_DIR"/*/; do
  name="$(basename "$d")"
  pj="$d/package.json"
  [ -f "$pj" ] || continue
  if ! grep -q '"bundle"' "$pj" 2>/dev/null; then
    err "$name：无 dsh.bundle ⇒ dsh plugin add 会成功但【不进 dsh.profile.bundles】⇒ 不激活"
    FAIL_LIST+=("$name:no-bundle")
    continue
  fi
  # ⚠️ **不许用 `node -e "require('$pj')"`** —— `$pj` 在 Git Bash 里是 `/d/...` 形态，
  #   而 Node 的 `require` **不认 Git Bash 路径** ⇒ 抛异常 ⇒
  #   `set -e` 下它在【赋值语句的命令替换】里 ⇒ ★★ **整个脚本静默退出** ❌（我实测：exit=1 而印着"失败 0"）
  #   ⇒ ★ 正解：**用 `node` 读【标准输入】**（把 JSON 从管道喂给它，不让 Node 解析路径）✅
  pkgname="$(node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>console.log(JSON.parse(s).name))' < "$pj" 2>/dev/null)"
  patchfile="$(node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>console.log(JSON.parse(s).dsh.bundle.patch))' < "$pj" 2>/dev/null)"
  if [ -z "$patchfile" ]; then err "$name：dsh.bundle.patch 读不到"; FAIL_LIST+=("$name:no-patch"); continue; fi
  # ★ patch 文件必须【真随包发布】（`files` 里要含它，否则 npm 包里没有 ⇒ 装了没用）
  if [ ! -f "$d/$patchfile" ]; then
    err "$name：patch 文件不在（$d/$patchfile）⇒ 它是 files 里的漏项"; FAIL_LIST+=("$name:patch-missing"); continue
  fi
  # ⚠️ patch 的路径可能带 `./` ⇒ 归一后再拼（否则 `-f "$d/./cordis.patch.yml"` 虽对但难读）
  insname="$(grep -oE "^[[:space:]]+name:[[:space:]]*['\"]?[^'\"]+" "$d/$patchfile" 2>/dev/null | head -1 | sed -E "s/.*name:[[:space:]]*['\"]?//")"
  if [ "$insname" != "$pkgname" ]; then
    err "$name：[insert.name]($insname) != [package.json.name]($pkgname) ⇒ loader import() 会失败 ⇒ 不激活"
    FAIL_LIST+=("$name:name-mismatch")
    continue
  fi
  # ⚠️ 下面这条**不许用反引号**（在双引号里会被当命令替换 ⇒ `insert.name: command not found`）
  ok "$name：[insert.name] == 包名（$pkgname）· patch 随包 ✅"
done

info '[3/3] 汇总'
echo "── 合计：装了 ${#PASS_LIST[@]} 个 · 跳过 ${#SKIP_LIST[@]} 个 · 失败 ${#FAIL_LIST[@]} 个 ──"
for x in "${PASS_LIST[@]:-}"; do [ -n "$x" ] && echo "  ✅ $x"; done
for x in "${SKIP_LIST[@]:-}"; do [ -n "$x" ] && echo "  ⏭  $x（跳过）"; done
for x in "${FAIL_LIST[@]:-}"; do [ -n "$x" ] && echo "  ❌ $x（失败）"; done
echo
echo '⇒ 下一步：**新开一个会话**（当前窗口的预设列表不会变）'
# ⚠️ **必须用 `if`，不许用 `[ … ] && { … }`**：
#   ```
#   【实测】末行写 `[ "${#FAIL_LIST[@]}" -gt 0 ] && { err …; exit 1; }`
#     ⇒ 当失败为 0 时 `[ 0 -gt 0 ]` = false ⇒ **短路 ⇒ 复合命令返回 1**
#     ⇒ ★★★ **而它是脚本最后一条 ⇒ 脚本 exit 1（成功也报失败）** ❌
#       ⇒ 而上面明明印着"失败 0 个" ⇒ **使用者会以为装挂了**（`B193`）
#   ```
if [ "${#FAIL_LIST[@]}" -gt 0 ]; then
  err '有包装配失败（本脚本可重复运行，幂等）'
  exit 1
fi
exit 0
