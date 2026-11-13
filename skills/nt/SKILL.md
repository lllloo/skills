---
name: nt
description: Notion 任務看板（Projects / Tasks）：認領、開立任務，回報進度與卡住。只在使用者輸入 /nt、或提到 Notion 任務卡、看板或 Projects / Tasks 時使用；沒提到就不要碰看板。
---

# nt：Notion 任務流程

只用 Notion MCP 的基本工具：`notion-search`、`notion-fetch`、`notion-query-data-sources`、`notion-create-pages`、`notion-update-page`。

## 呼叫方式

- `/nt`：照第 2 節 C，接任務或做下一張。
- `/nt <卡片 URL>`：照第 2 節 A。
- `/nt <文字>`：照第 2 節 B。文字是卡片標題或要做的事都行，B 會先找相符的卡，找不到才開新卡，接著認領開做。
- `/nt 新增 task <內容>`，或「新增／開 task」「記一下」這類只登記的說法：照第 3 節開卡就停，不認領、不實作。

沒用 `/nt`、而是用一般對話提到看板時，依對話內容判斷屬於 A、B、C 哪一種。

## 0. 找看板

每個 session 第一次用到看板時做一次，之後沿用結果。

1. `notion-search`，query 用 `Workbench`。
2. 在結果中挑 type 為 database、path 為 Workbench、標題為 Projects 的那一筆。
3. `notion-fetch` 這個資料庫，取得 Projects data source（`collection://…`）。Schema 裡 Tasks 關聯欄的 `dataSourceUrl` 就是 Tasks data source。
4. 找不到或找到多筆時，停下來問使用者，不要改用其他同名資料庫。

看板欄位（fetch 後應該看到）：

- Projects：Project name、Status（Planning / In progress / Paused / Done）、Repo、Tasks
- Tasks：Task name、Status（Not started / In progress / Blocked / Done）、Project（關聯 Projects）、Agent、Note、Due

欄位或狀態選項跟上面對不上時，停下來問使用者。

## 身分

Agent 欄位格式為 `名稱 @ 來源`，例如 `claude-code @ 165_jiamao`。

- 名稱：`claude-code`、`codex` 等。
- 來源：`basename "$(git rev-parse --show-toplevel)"`（在 worktree 裡就是 worktree 目錄名）；不是 git repo 時用目前資料夾名。
- Agent 字串完全相同才算自己。

Note 一律覆寫，只放最新狀態，不累加。

## 1. 對應專案

1. 取得識別：
   - git repo：`git remote get-url origin`、主 repo 路徑 `dirname "$(git rev-parse --path-format=absolute --git-common-dir)"`（在 worktree 裡也會指回主 repo）、主 repo 目錄名
   - 不是 git repo：目前資料夾的絕對路徑與資料夾名
2. 查 Projects，比對 Repo 欄。repo 網址、`owner/name`、本機路徑、目錄名任一吻合即算。
3. 吻合多個：列出來請使用者選。
4. 沒有吻合：問使用者要關聯到哪個既有專案，還是新建一個。使用者同意新建時，用 `notion-create-pages` 在 Projects 建一列：
   - Project name：預設用主 repo 目錄名（非 git 時用資料夾名），先跟使用者確認
   - Repo：有 origin 就填 origin 網址，沒有就填本機路徑
   - Status：Planning
5. 專案 Status 是 Paused：先問使用者要不要繼續；同意才改回 In progress。

## 2. 選任務

只看 Project 是這個專案的卡。依使用者的說法分三種：

**A. 指定了某張卡**：

- Agent 已填別人：告知使用者，不接。
- Status 是 Done：問使用者要重開這張，還是另開新卡。
- Project 是空的：先問使用者要關聯哪個專案（必要時照第 1 節新建），補上關聯再往下。
- Status 是 Blocked 且 Agent 是自己：照第 5 節「接續 Blocked 的卡」。
- 其他：到第 4 節認領。

**B. 給了一段文字（卡片標題或要做的事），沒給 URL**：

找標題跟這段文字相符、Status 不是 Done 的卡。找到一張就照 A 處理；找到多張就列出來問；找不到就到第 3 節開新卡，開完接第 4 節認領。

使用者只是要登記（「新增／開 task」「記一下」）時不走 B，直接到第 3 節開卡。

**C. 只說「接任務」「做下一張」，或 `/nt` 不帶參數**：

1. 有 Agent 是自己、Status 是 In progress 的卡：接續它。Blocked 的卡照第 5 節接續。有多張就列出來問。
2. 否則找 Status 為 Not started、Agent 為空的卡：
   - 只有一張：用它。
   - 多張：依 Due 由早到晚列出，請使用者選；使用者已說「自己挑」就選 Due 最早的（沒有 Due 的排最後）。
3. 都沒有：告訴使用者目前沒有可接的卡。

## 3. 開任務

用 `notion-create-pages`，parent 設為 Tasks data source：

- Task name：簡短描述要做的事
- Project：第 1 節找到或新建的專案頁 URL
- Status：Not started
- Agent：留空
- Due：使用者有給才填
- 內文：交辦內容超過一句話時，把需求與驗收條件寫進頁面內文

大型需求要拆成多張時：先把拆法（每張一句）列給使用者確認，再一次建好，全部關聯同一個專案。

開完依使用者的說法：

- 只要登記（「新增／開 task」「記一下」）：開完就停，回報卡片連結。不認領、不實作，Status 維持 Not started、Agent 留空。
- 明確要求做（`/nt <文字>` 經第 2 節 B 找不到卡而來，或明說要做）：接第 4 節，只認領當下要做的那一張。

## 4. 認領並開始

1. 寫入前先讀一次，Agent 必須是空的（或已經是自己）。
2. 用一次 `notion-update-page` 同時把 Agent 填成自己、Status 改成 In progress。
3. 寫完立刻再讀一次。Agent 不是自己就代表被別人搶先：不要再寫這張卡（不清空、不改回），回第 2 節換一張。
4. 專案 Status 是 Planning 或 Done 時，改成 In progress。

## 5. 卡住

1. Status 改成 Blocked，Note 寫具體問題或缺少的資訊。
2. 同時在對話裡向使用者提出同一個問題。Notion 上的留言你看不到，不要輪詢。
3. 等使用者在對話中回覆，不要猜。解除後 Status 改回 In progress，Note 覆寫成目前進度或清空。
4. session 要結束時仍未解除：維持 Blocked，Agent 不清空。

**接續 Blocked 的卡**：先把 Note 裡的問題在對話中問使用者，得到答案才改回 In progress 繼續。

## 6. 做完

完成判準：交辦的範圍做完，程式變更已 commit，該跑的驗證也跑過了。

1. Status 改成 Done，Agent 保留。
2. Note 覆寫成一兩句：剩下的事；沒有剩下的事就寫做了什麼、commit 或 PR 在哪。
3. 剩下的事大到能獨立成一件工作時，問使用者要不要另開一張卡。
4. 查這個專案的所有卡，全部是 Done 時，把專案 Status 改成 Done。

## 7. 中途停下

- 做不完要交還：Agent 清空、Status 改回 Not started、Note 寫做到哪裡。
- 使用者說整件不做了：不要刪卡，問使用者要怎麼處理。

## 不要做

- 不要改看板結構（欄位、狀態選項、視圖），不要新建資料庫。
- 未經使用者同意不要新增專案。
- 專案 Status 只照第 1、4、6 節的規則改；不要把專案設成 Paused。
- Task 的 Status 只用 Not started / In progress / Blocked / Done 這四個值。
- 不要寫入 Agent 是別人的卡，包括把它清空。
- 不要刪任務卡。
- 不要呼叫 Notion plugin 的 `tasks:*` 指令（build / plan / setup / explain-diff）和 `notion-spec-to-implementation`：它們用的是另一套欄位與狀態。
