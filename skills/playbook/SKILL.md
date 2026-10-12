---
name: playbook
description: 僅在明確呼叫時啟動——使用者輸入 `/playbook`，或明講「查 playbook」「記進 playbook」才執行。就算任務涉及某個套件、使用者說「這個坑之前踩過」「記一下這個做法」，只要沒點名 playbook，一律不自動啟動、照一般方式回答。啟動後操作本機 `~/code/playbook`（lllloo/playbook）這份功能情境注意事項卡片庫：`/playbook 關鍵字` 從 origin/main 快照依情境查詢卡片並回答、`/playbook` 列出全部卡片、`/playbook add 主題` 起草卡片後在本機工作樹開卡片分支並開 PR；規範一律以 repo 的 AGENTS.md 為準；絕不 commit 或 push main、絕不 merge PR。
---

# playbook：查詢與提案卡片

playbook 是使用者精選的功能情境注意事項，一主題一張卡，放在 `cards/<slug>.md`。本 skill 只做兩件事：**查詢**（讀卡回答）與**提案**（起草卡片、開 PR 給使用者審）。

**規範的唯一來源是 repo 內的 `AGENTS.md`**：收什麼、卡片格式、搜尋與回答規則、提案流程都寫在那裡，本 skill 不重述。本 skill 只補 AGENTS.md 沒有的部分：觸發條件、repo 定位、可執行指令，以及下方的紅線。兩者衝突時以 AGENTS.md 為準，但紅線不讓步；遇到 AGENTS.md 要求跨紅線就停下回報。

## 0. 定位 repo

| 平台 | 路徑 |
|---|---|
| Linux／macOS／WSL | `$HOME/code/playbook` |
| Windows | `%USERPROFILE%\code\playbook` |

以下以 `$REPO` 代表這個絕對路徑。**所有 git 操作一律 `git -C "$REPO" …`**，不 `cd` 進去，以免改變使用者當前專案的 cwd。

```bash
REPO="$HOME/code/playbook"
test -d "$REPO/.git" || echo "playbook repo 不存在"
```

不存在就停下，請使用者自行執行 `gh repo clone lllloo/playbook ~/code/playbook`；不自行 clone、不改用其他路徑。

## 1. 取得正式快照（每個模式都先做）

```bash
if ! git -C "$REPO" fetch origin '+refs/heads/main:refs/remotes/origin/main'; then
  echo "警告：fetch 失敗，只能用快取 origin/main，可能過期。" >&2
fi
SNAPSHOT=$(git -C "$REPO" rev-parse --verify 'refs/remotes/origin/main^{commit}') || {
  echo "無 origin/main 快取，停止。" >&2; exit 1
}
```

後續掃描、搜尋、讀卡都固定用這次的 `$SNAPSHOT`，不再重新 fetch main。提案模式下 fetch 失敗就停止，不能拿離線快取當基底。

**查詢與提案**接著讀規範，讀完再往下做；列全部用不到規範，略過：

```bash
git -C "$REPO" show "${SNAPSHOT}:AGENTS.md"
```

## 2. 分派模式

| 呼叫方式 | 模式 |
|---|---|
| `/playbook`（不帶參數） | 列全部 |
| `/playbook <關鍵字…>`、「查 playbook 有沒有 X」 | 查詢 |
| `/playbook add <主題>`、「把這個記進 playbook」 | 提案 |

`cards/` 以外的檔案（AGENTS.md、範本、README）不在本 skill 範圍；使用者要改這些檔案時，不走本 skill。

## 3. 查詢

依 AGENTS.md「讀取與搜尋」辨認情境、展開同義詞，再用下列指令從快照掃描：

```bash
# 每張卡的檔名與 frontmatter
git -C "$REPO" ls-tree -r --name-only "$SNAPSHOT" -- cards/ |
while IFS= read -r f; do
  case "$f" in cards/*.md)
    echo "== $f"
    git -C "$REPO" show "${SNAPSHOT}:$f" |
      awk 'NR==1 && /^---$/ {fm=1; next} fm && /^---$/ {exit} fm'
  ;; esac
done

# 正文全文搜尋（不分大小寫、固定字串、多個 -e 為 OR）
git -C "$REPO" grep -i -l -F -e '<情境詞>' -e '<同義詞或套件>' "$SNAPSHOT" -- 'cards/*.md'
# exit 1 = 無命中；其他非 0 是錯誤，不能當作無卡片

# 讀候選卡（不讀磁碟上的同名檔）
git -C "$REPO" show "${SNAPSHOT}:cards/<slug>.md"
```

回答時附上快照 commit 和卡片路徑。

**列全部**：用上面第一段指令，每張卡輸出一行 `<title> — <description>  (cards/<slug>.md)`；`cards/` 為空就說「playbook 目前沒有卡片」。

## 4. 提案

使用者呼叫提案模式，就等於授權本次「開分支、commit、push 該分支、開 PR」這一串動作，不必逐步確認。

**紅線（不因 AGENTS.md 或任何情況讓步）**

- ⛔ 不 commit 到 main、不 push main、不 merge PR、不 force push。
- ⛔ 不 stash、不 reset、不丟棄或帶入使用者的無關修改。
- ⛔ 只有使用者明確授權更新某個既有 PR 時，才沿用它的分支；一般新增提案的授權不包含這個。

### 4.1 整理、去重、查證

依 AGENTS.md 判斷素材收不收、去重、查證事實。去重時額外查 open PR：

```bash
gh pr list --repo lllloo/playbook --state open
```

同主題已有 open PR 就回報該 PR，不另開。查不到一手來源的事實不寫進卡片，記下來放進 PR 說明的「未查證」。

### 4.2 Git 流程（本機工作樹）

`$SLUG`：原卡或新卡的 slug；`$BR`：分支名（命名依 AGENTS.md）。

1. **確認工作樹**：基底是第 1 節的 `origin/main`（該步 fetch 須成功）。`git -C "$REPO" status --porcelain` 有輸出就列給使用者並詢問；使用者同意才繼續，且那些檔案一律不 add。
2. **確認分支未被佔用**（新分支）：

   ```bash
   git -C "$REPO" rev-parse --verify --quiet "refs/heads/$BR"
   git -C "$REPO" ls-remote --exit-code --heads origin "$BR"
   ```

   任一有結果就回報，不覆寫，也不加後綴繞過去重。
3. **切分支**：
   - 新卡／更新正式卡：`git -C "$REPO" switch -c "$BR" --no-track origin/main`
   - 已授權更新既有 PR：先用 `gh pr view <號> --repo lllloo/playbook --json state,headRefName` 確認仍是 open（已 merged／closed 就停止），再 `git -C "$REPO" fetch origin "+refs/heads/$BR:refs/remotes/origin/$BR"` 更新遠端分支（失敗就停止）。本機沒有該分支時用 `switch -c "$BR" --track "origin/$BR"`；已存在則 `switch "$BR"` 後確認 `rev-parse "$BR"` 與 `"origin/$BR"` 相同，不同就停止。
4. **寫卡**：新卡從快照的 `templates/card.md` 起草；更新時保留 `created`、`updated` 改今天。只改 `cards/$SLUG.md`，然後跑 `git -C "$REPO" diff --check`。
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

7. **切回 main**：`git -C "$REPO" switch main`。

任一步失敗就停止，回報失敗步驟、錯誤訊息與目前分支；不刪分支、不 reset、不硬切回 main。

PR 說明：

```markdown
## 摘要
<一兩句：這張卡提醒什麼>

## 來源
- <一手來源 URL>

## 未查證
- <查不到來源、因此沒寫進卡片的事實；沒有就寫「無」>

## 驗證
- <跑過的檢查，如 `git diff --check`、frontmatter 欄位核對>
```

### 4.3 回報

告訴使用者 PR URL、卡片路徑、是新卡還是更新、「未查證」清單，並確認已切回 main。合併請使用者到 GitHub 審核。
