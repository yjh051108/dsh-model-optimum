# dsh-model-optimum —— 一键安装（Windows；镜像 install.sh）
#
# 用法： .\install.ps1      ·  $env:DRY_RUN='1'; .\install.ps1 （只看不装）
# ⚠️ 执行策略：powershell -ExecutionPolicy Bypass -File .\install.ps1

$ErrorActionPreference = 'Continue'

$Root    = Split-Path -Parent $MyInvocation.MyCommand.Path
$PkgsDir = Join-Path $Root 'packages'
$Profile = if ($env:PROFILE) { $env:PROFILE } else { 'web' }
# ★ DSH_HOME 优先 —— 不要用 $HOME/$env:USERPROFILE 直接推（本机实测可能指向不同账号）
$DshHome = if ($env:DSH_HOME) { $env:DSH_HOME } else { Join-Path $HOME '.dsh' }
# ★ 必须回写环境变量 —— 否则子进程用 os.homedir() 重新推
$env:DSH_HOME = $DshHome
$DryRun  = ($env:DRY_RUN -eq '1')

function Info($m) { Write-Host "=== $m ===" -ForegroundColor Cyan }
function Ok($m)   { Write-Host "OK $m" -ForegroundColor Green }
function Warn($m) { Write-Host "! $m" -ForegroundColor Yellow }
function Err($m)  { Write-Host "X $m" -ForegroundColor Red }

$pass = @(); $fail = @(); $skip = @()

Info '[0/3] 环境预检'
$node = Get-Command node -ErrorAction SilentlyContinue
if (-not $node) { Err '未找到 node'; exit 1 }
Ok "node: $(node --version)"
$dsh = Get-Command dsh -ErrorAction SilentlyContinue
if (-not $dsh) { Warn 'dsh 不在 PATH —— 回退 npx @deepseek-ai/dsh'; $DshCmd = @('npx','@deepseek-ai/dsh') }
else { Ok "dsh: $($dsh.Source)"; $DshCmd = @('dsh') }
Write-Host "仓库目录 : $Root"
Write-Host "DSH_HOME  : $DshHome"
Write-Host "profile   : $Profile"
if ($DryRun) { Warn 'DRY_RUN=1 —— 只打印，不执行' }

Info '[1/3] 逐包装配（packages/）'
foreach ($d in (Get-ChildItem $PkgsDir -Directory | Sort-Object Name)) {
  $name = $d.Name
  if (-not (Test-Path (Join-Path $d.FullName 'package.json'))) { Warn "$name：无 package.json（跳过）"; $skip += $name; continue }
  if ($DryRun) { Ok "$name：将执行 $($DshCmd -join ' ') plugin --profile $Profile add $($d.FullName)"; $pass += $name; continue }
  & $DshCmd[0] $DshCmd[1..($DshCmd.Count-1)] plugin --profile $Profile add $d.FullName *> $null
  if ($LASTEXITCODE -eq 0) { Ok $name; $pass += $name } else { Err "$name（可单独重试）"; $fail += $name }
}

Info '[2/3] ★ 激活自检（**不是"有 dsh.bundle 就算过"**）'
# 为什么不能只查 `dsh.bundle` 字段：symbiote 曾把 insert.name 写成 'dsh-symbiote'（少了 @dsh-external/ 前缀）
#   => loader 的 _init() 会 import('dsh-symbiote') => ERR_MODULE_NOT_FOUND => 进了 bundles 也不激活。
#   依据：cordis-plugin-loader/lib/index.js: plugin = await this.parent.tree.import(this.options.name, ...)
foreach ($d in (Get-ChildItem $PkgsDir -Directory | Sort-Object Name)) {
  $pj = Join-Path $d.FullName 'package.json'
  if (-not (Test-Path $pj)) { continue }
  $j = Get-Content $pj -Raw -Encoding UTF8 | ConvertFrom-Json
  if (-not $j.dsh.bundle.patch) {
    Err "$($d.Name)：无 dsh.bundle => dsh plugin add 会成功但【不进 dsh.profile.bundles】=> 不激活"
    $fail += "$($d.Name):no-bundle"; continue
  }
  $patchPath = Join-Path $d.FullName $j.dsh.bundle.patch
  if (-not (Test-Path $patchPath)) {
    Err "$($d.Name)：patch 文件不在（$patchPath）=> 它是 files 里的漏项"
    $fail += "$($d.Name):patch-missing"; continue
  }
  $pt = Get-Content $patchPath -Raw -Encoding UTF8
  $m = [regex]::Match($pt, '(?m)^\s+name:\s*[''"]?([^''"\r\n]+)')
  $insname = if ($m.Success) { $m.Groups[1].Value.Trim() } else { '' }
  if ($insname -ne $j.name) {
    Err "$($d.Name)：[insert.name]($insname) != [package.json.name]($($j.name)) => loader import() 会失败 => 不激活"
    $fail += "$($d.Name):name-mismatch"; continue
  }
  Ok "$($d.Name)：[insert.name] == 包名（$($j.name)）· patch 随包"
}

Info '[3/3] 汇总'
Write-Host "── 合计：装了 $($pass.Count) 个 · 跳过 $($skip.Count) 个 · 失败 $($fail.Count) 个 ──"
foreach ($x in $pass) { Write-Host "  OK $x" }
foreach ($x in $skip) { Write-Host "  -- $x（跳过）" }
foreach ($x in $fail) { Write-Host "  XX $x（失败）" }
Write-Host ''
Write-Host '=> 下一步：新开一个会话（当前窗口的预设列表不会变）'
if ($fail.Count -gt 0) { Err '有包装配失败（本脚本可重复运行，幂等）'; exit 1 }
