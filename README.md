# dsh-model-optimum —— 「模型单步执行最优」那套插件

> **一句话**：**让模型每一步都走对** —— 模型适配层 + 学习环观测器官。
>
> ⚠️ **这不是 OMC**（OneManCompany 公司套件）⇒ 公司的东西在 [`dsh-omc`](https://github.com/yjh051108/dsh-omc)。

---

## 一 · 这是什么

| 包 | 它做什么 |
|---|---|
| **`packages/model-fit`** | **模型适配层**：按模型特性改造 harness 身体（**尺子闸 / 工具面 / 近场重述**）—— 每次干预自带证据，被忽略则自动静默 |
| **`packages/symbiote`** | **共生体**：只读观测闭环盘档 —— 算**真 C 信誉** / **真 A 注意力税**，出**蒸馏草稿**（学习环的独立器官） |

> ★ **为什么这两个在一个仓**：**它们是【一套】** —— 目的都是
> 「**模型单步执行最优**」：`model-fit` 让**这一步**走对，`symbiote` 让**下一步**从这一步学到东西。

---

## 二 · 怎么装（**一条命令**）

```bash
git clone https://github.com/yjh051108/dsh-model-optimum
cd dsh-model-optimum
./install.sh          # Windows: .\install.ps1
```

> ★★ **这两个包都声明了 `dsh.bundle`** ⇒ **`dsh plugin add` 之后它们进 `dsh.profile.bundles` ⇒ 真激活** ✅
> ```
> 判据（可自己复核 · 两个包都这样）：
>   ① `insert.name` == `package.json.name`（`cordis.patch.yml` 里那一行）
>   ② ★ 在装着它的 profile 目录下 `import('<package.json.name>')` ⇒ 必须 **OK**
>      ⇒ ★ 而 (`insert.name` 是【模块名】) —— loader 的 `_init()` 拿它去 `import()`，
>        所以**少了 `@dsh-external/` 前缀就会 `ERR_MODULE_NOT_FOUND`**（**进了 bundles 也不激活**）
>   ③ `files` 里有 `cordis.patch.yml`（**否则 patch 不进包 ⇒ 装了照样没用**）
> ```
> ⚠️ **诚实边界**：**"进了 `dsh.profile.bundles`" 只证明"过了 `reconcilePlugins()`"** ——
> **不到"激活"**。**"激活"的判据是 ②（入口真能解析）+ 该插件的效果真出现** ✅
> ⚠️ **本仓的两个包 `private: true` 且不在 npm** ⇒ 装法是 **`dsh plugin add <你 clone 的仓>/packages/<包>`**
> （或直接跑 `./install.sh` —— 它内部就是这么做的）。

---

## 三 · 边界（**与 OMC 的关系**）

```
★ **本仓** = 「模型单步执行最优」那套（**与"公司"无关**）
★ **`dsh-omc`** = 公司相关（`teamkit` 公司层 · `org-panel` 看得见公司 · `docs/company` 方法论）
★ **其它**（`issue-watch` · `tool-output-guard` · `web-tools`）⇒ **各自独立的仓**
⇒ ★ **为什么分开**：**"一个仓 = 一个产品"** —— 混在一起 ⇒ 陌生人打开会困惑"我到底装什么"。
```

---

## 四 · 许可证

```
各包以其 package.json 的 license 字段为准（各自 LICENSE 文件在包内）。
```
