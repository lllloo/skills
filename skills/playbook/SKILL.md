---
name: playbook
description: 僅在明確呼叫時啟動——使用者輸入 `/playbook`，或明講「查 playbook」「記進 playbook」才執行；只是涉及某個套件、說「這個坑之前踩過」「記一下這個做法」而沒點名 playbook 時，一律不啟動、照一般方式回答。啟動後操作本機 `~/code/playbook`（lllloo/playbook）功能情境注意事項卡片庫：`/playbook 關鍵字` 查詢卡片、`/playbook` 列出全部、`/playbook add 主題` 起草卡片並開 PR。
---

# playbook：查詢與提案卡片

playbook 是使用者精選的功能情境注意事項，一主題一張卡，放在 `cards/<slug>.md`。本 skill 只做兩件事：**查詢**（讀卡回答）與**提案**（起草卡片、開 PR 給使用者審）。

**規範的唯一來源是 repo 內的 `AGENTS.md`**：收什麼、卡片格式、搜尋與回答規則、去重、分支命名、PR 內容都寫在那裡，本 skill 不重述。本 skill 只補可執行指令與下方紅線。兩者衝突時以 AGENTS.md 為準，但紅線不讓步；遇到 AGENTS.md 要求跨紅線就停下回報。

## 0. 工具與 repo

repo 預設在 `$HOME/code/playbook`（Windows 為 `%USERPROFILE%\code\playbook`，需在 Git Bash 執行），以下稱 `$REPO`。所有 git 操作一律 `git -C "$REPO" …`，不 `cd` 進去，以免改變使用者當前專案的 cwd。

唯讀操作都用本 skill 目錄下的 `scripts/scan.sh`（以下稱 `scan.sh`，路徑請用 skill 的 base directory 組成絕對路徑）。它只讀 Git tree、不動工作樹；repo 不存在時會提示使用者自行 clone，照轉達即可，不自行 clone、不改用其他路徑。

| 指令 | 用途 |
|---|---|
| `scan.sh snapshot [--strict]` | fetch `origin/main`，印出快照 commit |
| `scan.sh list <sha>` | 每張卡一行 `<title> — <description>  (cards/<slug>.md)` |
| `scan.sh meta <sha>` | 每張卡的路徑與 frontmatter |
| `scan.sh grep <sha> <詞>...` | 正文全文搜尋（不分大小寫、多詞為 OR），印出命中路徑 |
| `scan.sh show <sha> <slug\|路徑>` | 讀卡（slug）或讀 repo 內檔案（如 `AGENTS.md`） |

exit code：0 成功、1 grep 無命中、2 錯誤。**exit 2 不能當作「沒有卡片」**，要把錯誤訊息轉告使用者。

## 1. 分派模式

| 呼叫方式 | 模式 |
|---|---|
| `/playbook`（不帶參數） | 列全部 |
| `/playbook <關鍵字…>`、「查 playbook 有沒有 X」 | 查詢 |
| `/playbook add <主題>`、「把這個記進 playbook」 | 提案 |

每個模式都先跑 `scan.sh snapshot` 取得快照 `$SNAPSHOT`，之後掃描、搜尋、讀卡都固定用它，不再重新 fetch main。fetch 失敗時 script 會警告「快取可能過期」，回答時要轉述這一點。

`cards/` 以外的檔案（AGENTS.md、範本、README）不在本 skill 範圍；使用者要改這些檔案時，不走本 skill。

## 2. 列全部

`scan.sh list "$SNAPSHOT"`，原樣列給使用者並附快照 commit。用不到 AGENTS.md，不必讀。

## 3. 查詢

1. `scan.sh show "$SNAPSHOT" AGENTS.md`，依「讀取與搜尋」辨認情境、展開中英同義詞、症狀與套件名。
2. `scan.sh meta "$SNAPSHOT"` 比對檔名與 frontmatter；`scan.sh grep "$SNAPSHOT" <情境詞> <同義詞> <套件>…` 搜正文。
3. 對所有候選卡 `scan.sh show "$SNAPSHOT" <slug>` 讀全文後回答，附快照 commit 與卡片路徑。

## 4. 提案

使用者呼叫提案模式，就等於授權本次「開分支、commit、push 該分支、開 PR」這一串動作，不必逐步確認。

**紅線（不因 AGENTS.md 或任何情況讓步）**

- ⛔ 不 commit 到 main、不 push main、不 merge PR、不 force push。
- ⛔ 不 stash、不 reset、不丟棄或帶入使用者的無關修改。
- ⛔ 只有使用者明確授權更新某個既有 PR 時，才沿用它的分支；一般新增提案的授權不包含這個。

### 4.1 準備

1. 快照改用 `scan.sh snapshot --strict`：提案不能拿離線快取當基底。
2. 讀 AGENTS.md，依它判斷素材收不收、去重、查證事實。去重除了查快照，也查 open PR：`gh pr list --repo lllloo/playbook --state open`。
3. 決定 `$SLUG`（原卡或新卡）與分支 `$BR`：
   - 新卡：`card/<slug>`。
   - 更新正式卡：`card/<slug>-<簡短後綴>`（後綴描述這次的改動，如 `-worker-src`）。舊 PR merge 後本機常殘留 `card/<slug>` 分支，所以更新不沿用無後綴的名稱。

### 4.2 Git 流程

1. **記下原位置、確認工作樹**：

   ```bash
   ORIG=$(git -C "$REPO" symbolic-ref -q --short HEAD || git -C "$REPO" rev-parse HEAD)
   git -C "$REPO" status --porcelain
   ```

   有輸出就列給使用者並詢問；同意才繼續，且那些檔案一律不 add。
2. **確認分支未被佔用**（新分支）：

   ```bash
   git -C "$REPO" rev-parse --verify --quiet "refs/heads/$BR"
   git -C "$REPO" ls-remote --exit-code --heads origin "$BR"
   ```

   新卡被佔用就回報、不覆寫（多半是有人正在提同主題）。更新正式卡被佔用時換一個後綴；去重已在 4.1 用 open PR 查過。
3. **切分支**：
   - 新卡／更新正式卡：`git -C "$REPO" switch -c "$BR" --no-track "$SNAPSHOT"`
   - 已授權更新既有 PR：先用 `gh pr view <號> --repo lllloo/playbook --json state,headRefName` 確認仍是 open（已 merged／closed 就停止），再 `git -C "$REPO" fetch origin "+refs/heads/$BR:refs/remotes/origin/$BR"`（失敗就停止）。本機沒有該分支時用 `switch -c "$BR" --track "origin/$BR"`；已存在則 `switch "$BR"` 後確認 `rev-parse "$BR"` 與 `"origin/$BR"` 相同，不同就停止。
4. **寫卡**：新卡從 `scan.sh show "$SNAPSHOT" templates/card.md` 起草；更新時保留 `created`、`updated` 改今天。只改 `cards/$SLUG.md`，然後跑 `git -C "$REPO" diff --check`。
5. **提交與推送**：

   ```bash
   git -C "$REPO" add "cards/$SLUG.md"
   git -C "$REPO" commit -m "新增卡片：<title>"   # 更新用「更新卡片：<title>」
   git -C "$REPO" push -u origin "$BR"
   ```

   hook 失敗不加 `--no-verify`；修正後重試，修不了就停下。
6. **開 PR**（既有 PR 只推送、不另開）：

   ```bash
   gh pr create --repo lllloo/playbook --base main --head "$BR" \
     --title "新增卡片：<title>" --body-file <scratchpad 暫存檔>
   ```

   PR 說明用四段：`## 摘要`（一兩句：這張卡提醒什麼）、`## 來源`（一手來源 URL）、`## 未查證`（查不到來源、因此沒寫進卡片的事實；沒有就寫「無」）、`## 驗證`（跑過的檢查）。
7. **切回原位置**：`git -C "$REPO" checkout "$ORIG"`。

任一步失敗就停止，回報失敗步驟、錯誤訊息與目前分支；不刪分支、不 reset、不硬切回去。

### 4.3 回報

告訴使用者 PR URL、卡片路徑、是新卡還是更新、「未查證」清單，並確認已切回原位置。合併請使用者到 GitHub 審核。
