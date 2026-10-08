# playbook 卡片格式規格

本檔是 playbook 卡片的完整規格，自包含：不依賴 playbook repo 內任何檔案即可照寫。

## 收什麼

使用者精選的「踩坑 → 確定做法」，一則一檔。只收**已確認可行**的做法。

- 收：踩過的坑與實際驗證過的解法。例：pdf.js 渲染中日文需設 `cMapUrl`。
- 不收：研究筆記、推測、方案比較、「可能可以試試」、一般教學。

素材不符合時，直接告訴使用者這則不適合進 playbook，不硬寫。

## 位置與檔名

- 路徑：`cards/<slug>.md`，平鋪，不開子資料夾。
- `<slug>`：純 ASCII，小寫英數與 `-`，以套件／工具名開頭較好找。例：`pdfjs-cjk-cmap.md`。
- 一個主題一張卡。已有同主題卡片時更新那張，不另開。

## frontmatter

YAML，欄位**依此順序**，五個都必填：

| 欄位 | 格式 | 規則 |
|---|---|---|
| `title` | 字串 | 主題名，可中文 |
| `description` | 字串 | 一句話；**必須含套件／工具名**（如 `pdfjs-dist`），讓 grep 找得到 |
| `tags` | YAML list | 小寫、`-` 連接，例 `[pdfjs, cjk, font]` |
| `created` | `YYYY-MM-DD` | 建立日；更新卡片時**不改** |
| `updated` | `YYYY-MM-DD` | 最後修改日；新建時與 `created` 相同 |

## 正文

一律繁體中文，技術名詞保留英文。章節依此順序，標題文字照抄：

1. `## 問題`：症狀。使用者實際看到什麼（錯誤訊息原文、畫面現象、版本條件）。
2. `## 做法`：可直接抄的 code／設定，附必要的版本前提。
3. `## 原因`：為什麼會這樣、為什麼這樣解。
4. `## 來源`（選填）：官方文件、release notes、原始碼等一手來源 URL。

不加其他頂層章節。做法若有前提或例外，寫在「做法」內。

## 事實查證

「做法」與「原因」中的事實（API 名、參數、預設值、版本行為）必須能對上官方一手來源，並列進 `## 來源`。查不到一手來源的事實**不寫進卡片**，改在 PR 說明的「未查證」段落列出。

## 範例

````markdown
---
title: pdf.js 渲染中日文變空白或亂碼
description: pdfjs-dist 渲染含中日韓字型的 PDF 時，需設定 cMapUrl 與 cMapPacked 才能正確顯示文字
tags: [pdfjs, pdfjs-dist, cjk, cmap]
created: 2026-10-08
updated: 2026-10-08
---

## 問題

用 `pdfjs-dist` 渲染含中文的 PDF，文字變空白或亂碼，console 出現 CMap 相關警告。

## 做法

```js
const pdf = await pdfjsLib.getDocument({
  url,
  cMapUrl: '/cmaps/',   // 指向 pdfjs-dist/cmaps 的靜態檔
  cMapPacked: true,
}).promise
```

建置時把 `node_modules/pdfjs-dist/cmaps/` 複製到靜態資源目錄。

## 原因

CJK 字型常用預先定義的 CMap 對應字元碼，pdf.js 預設不內建這些檔案，需由 `cMapUrl` 指定載入位置。

## 來源

- <官方文件 URL>
````

（範例中的 API 細節僅示意格式；實際寫卡仍須依「事實查證」一節查證。）
