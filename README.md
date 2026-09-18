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

> ⚠️ **这两个包都【没有】`dsh.bundle`** ⇒ **走"装配成 bundle"不会激活**（**不是报错，是不生效**）
> ⇒ 需要走**注入**路径：`dev_inject_plugin <包目录>`（**需环境里常驻注入器** —— 见 `dsh-omc`）。

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
