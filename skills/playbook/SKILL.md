---
name: playbook
description: 僅在明確呼叫時啟動——使用者輸入 `/playbook`，或明講「查 playbook」「記進 playbook」才執行。就算任務涉及某個套件、使用者說「這個坑之前踩過」「記一下這個做法」，只要沒點名 playbook，一律不自動啟動、照一般方式回答。啟動後操作本機 `~/code/playbook`（lllloo/playbook）這份「踩坑 → 確定做法」卡片庫：`/playbook 關鍵字` 從 origin/main 的 Git tree 依功能情境查詢卡片並回答、`/playbook` 列出全部卡片、`/playbook add 主題` 起草卡片後從 origin/main 的隔離工作樹開卡片分支並開 PR；絕不 commit 或 push main、絕不 merge PR。
---

# playbook：查詢與提案踩坑卡片

playbook 是使用者精選的「踩坑 → 確定做法」卡片庫，一則一檔放在 `cards/<slug>.md`。本 skill 做兩件事：**查詢**（讀卡片回答）與**提案**（起草卡片、開 PR 給使用者審）。AI 對 playbook 只有提案權，合併由使用者在 GitHub 做。

卡片格式的完整規格在 [references/card-format.md](references/card-format.md)，提案模式動筆前必讀。

## 0. 定位 repo

| 平台 | 路徑 |
|---|---|
| Linux／macOS／WSL | `$HOME/code/playbook` |
| Windows | `%USERPROFILE%\code\playbook` |

以下以 `$REPO` 代表這個絕對路徑。**所有 git 操作一律 `git -C "$REPO" …`**，不 `cd` 進去、不改變使用者當前專案的 cwd；讀寫檔案也用絕對路徑。

```bash
REPO="$HOME/code/playbook"
test -d "$REPO/.git" || echo "playbook repo 不存在"
```

不存在就停下，告訴使用者：

```
gh repo clone lllloo/playbook ~/code/playbook
git -C ~/code/playbook config core.hooksPath .githooks
```

不自行 clone、不改用其他路徑。

## 1. 分派模式

| 呼叫方式 | 模式 |
|---|---|
| `/playbook`（不帶參數） | 列出全部卡片 |
| `/playbook <關鍵字…>`、「查 playbook 有沒有 X」 | 查詢 |
| `/playbook add <主題>`、「把這個記進 playbook」 | 提案 |

## 2. 查詢模式

### 2.1 取得正式卡片快照

正式卡片只來自 `origin/main` 的 Git tree；目前 checkout 的分支、工作樹檔案及未合併 PR 都不是正式來源。查詢不切分支、不 pull、不 reset、不 stash，也不覆寫工作樹。

```bash
if ! git -C "$REPO" fetch origin '+refs/heads/main:refs/remotes/origin/main'; then
  echo "警告：fetch 失敗，只能使用快取 origin/main；可能過期。" >&2
fi
SNAPSHOT=$(git -C "$REPO" rev-parse --verify 'refs/remotes/origin/main^{commit}') || {
  echo "無 origin/main 快取，不能確定正式卡片；停止查詢。" >&2
  exit 1
}
```

fetch 失敗時附上失敗原因與「快取可能過期」警告；有快取才可繼續。無快取時不能宣稱沒有卡片，不能回退到 HEAD、本機 main、工作樹或提案分支。後續掃描、搜尋、讀卡及列全部都固定使用本次 `$SNAPSHOT`，回答附快照 commit。

### 2.2 依情境掃卡片

先辨認功能情境（如 PDF 解析／顯示、登入、檔案上傳），再展開中英同義詞、症狀與套件名稱輔助搜尋。涉及 PDF 時先搜 `PDF`，讀相關注意事項後才判斷是否使用 pdf.js；不要因尚未知道套件或套件名稱不完全相同而漏卡。

不維護索引檔，每次從同一正式快照掃：

```bash
# 每張卡的檔名與 frontmatter（title／description／tags）
git -C "$REPO" ls-tree -r --name-only "$SNAPSHOT" -- cards/ |
while IFS= read -r f; do
  case "$f" in cards/*.md)
    echo "== $f"
    git -C "$REPO" show "$SNAPSHOT:$f" |
      awk 'NR==1 && /^---$/ {fm=1; next} fm && /^---$/ {exit} fm'
  ;; esac
done

# 正文全文搜尋（不分大小寫、固定字串、多個關鍵字為 OR）
git -C "$REPO" grep -i -l -F -e '<情境詞>' -e '<同義詞或套件>' \
  "$SNAPSHOT" -- 'cards/*.md'
# exit 1 表示無命中；其他錯誤不能當作無卡片。
```

- 檔名、title、description、tags 的語意命中與全文搜尋命中都算候選。
- 讀候選卡用 `git -C "$REPO" show "$SNAPSHOT:cards/<slug>.md"`，不讀磁碟上的同名檔。

### 2.3 讀卡、回答

- 讀**所有**候選卡片全文，判斷哪些真的相關。
- 以正式快照的卡片內容為準回答，按適用條件挑出可執行檢查事項，並引用卡片路徑（如 `cards/pdfjs-cjk-cmap.md`）。
- 卡片只涵蓋問題的一部分時，講清楚哪些出自卡片、哪些不是；不是出自卡片的部分要明標，不混在一起。
- **沒有命中就直說「playbook 沒有這方面的卡片」**。不得用通用知識冒充卡片內容。使用者若想要，可再另外用一般方式回答，但要與 playbook 結果分開。

### 2.4 不帶參數：列全部

同樣先做 2.1，再列出每張卡：

```
<title> — <description>  (cards/<slug>.md)
```

正式快照中 `cards/` 為空或不存在就說「playbook 目前沒有卡片」。

## 3. 提案模式

使用者呼叫提案模式，就等於授權本次「開分支、commit、push 該分支、開 PR」這一串動作，不必再逐步確認。但以下紅線任何情況都不跨：

- ⛔ 不 commit 到 main、不 push main、不 merge PR、不 force push。
- ⛔ 保留使用者主工作樹與無關修改；使用乾淨隔離工作樹，不 stash、不 reset、不覆寫他人變更。
- ⛔ commit 遇 hook 失敗不加 `--no-verify` 繞過；修正卡片後重試，修不了就停下回報。

### 3.1 整理素材

1. 從當前對話抓出「問題 → 確定做法」：適用情境、已驗證的可執行檢查事項、必要來源／版本；寫精簡提醒，不擴寫長教學或完整程式碼。素材不足（例如還不知道做法是否真的有效）就問使用者，不自己補。
2. 素材是研究、推測、方案比較等**未確認可行**的內容 → 告訴使用者不適合進 playbook，停止。
3. 先依 2.1、2.2 查有沒有同主題卡片。有 → 本次是**更新那張卡**（沿用其 slug，`created` 不動、`updated` 改今天）；沒有 → 新卡，依規格取 slug。另以 `gh pr list --repo lllloo/playbook --state open` 查看未合併提案並讀相關 PR 內容去重；明確標示「未接受提案」，不得混入正式查詢結果。同主題已有提案就回報該 PR，不另開重複提案；只有使用者明確授權更新該既有 PR 時，才沿用其分支。一般新增提案授權不等於更新既有 PR 的授權。

### 3.2 查證事實

依 [references/card-format.md](references/card-format.md) 的「事實查證」：檢查事項中的 API 名、參數、預設值、版本行為，逐一對官方一手來源（官方文件、release notes、原始碼）。對得上的列進 `## 來源`；**查不到的不寫進卡片**，記下來放進 PR 說明的「未查證」段落。

### 3.3 Git 流程（隔離工作樹）

先讀目標 repo 的 AGENTS.md。保留使用者目前分支及未提交檔案，查 `git -C "$REPO" worktree list --porcelain`；可沿用本次任務已有、分支正確且乾淨的隔離工作樹，不接管他人工作樹。以下 `$SLUG` 是原卡或新卡的 slug，`$BR` 是選定分支，`$WT` 是本次隔離工作樹的絕對路徑，選不存在的路徑建立；所有卡片寫入、驗證與 commit 都在 `$WT`，不切換主工作樹。

1. `git -C "$REPO" fetch origin` 必須成功；提案寫入不能用離線快取當最新基底。
2. 選分支與起點：
   - **新卡**：`card/<slug>`，從最新 `origin/main` 建立。檢查本機及遠端是否已有該分支；存在就回報，不覆寫、不用後綴繞過同主題去重。
   - **更新正式卡**：仍寫原 `cards/<slug>.md`，可選不衝突的 `card/<slug>-<簡短後綴>`，從最新 `origin/main` 建立。後綴只區分更新分支，不建立同主題第二張卡；已有相關 open PR 時依第 3.1 節處理。
   - **明確授權更新既有 PR**：先核對該 PR 仍 open、head repo／分支與最新 head；若已 merged／closed 就停止回報，不新建或重開。沿用原 PR 分支，從 fetch 到的該遠端 head 起步；分支若已由他人工作樹使用，或本機同名分支有未推送／分歧內容，就停止回報，不 reset 或 force。未授權不得擅自更新。
3. 建立乾淨隔離工作樹；以下為新分支的命令，`$BR` 是已核對未佔用的分支名：

```bash
git -C "$REPO" worktree add -b "$BR" "$WT" origin/main
git -C "$WT" status --porcelain
```

既有 PR 分支尚未在本機存在時，用 `git -C "$REPO" worktree add -b "$BR" "$WT" "origin/$BR"`；本機分支已存在且與遠端 head 一致、未被其他工作樹使用時，用 `git -C "$REPO" worktree add "$WT" "$BR"`。已有本次隔離工作樹時，先核對 branch、head 與乾淨狀態；`status --porcelain` 有任何輸出就停止回報，不清除任何未提交內容。

4. 在 `$WT/cards/<slug>.md` 起草或更新，格式照 references/card-format.md；保留 created，更新 updated。只修改本次卡片，完成適用 lint、metadata 驗證及 `git -C "$WT" diff --check`。保留 main 防護 hook，不繞過失敗 hook。
5. 只 add 本次卡片，再 commit、明確 push 原分支：

```bash
git -C "$WT" add "cards/$SLUG.md"
git -C "$WT" commit -m "新增卡片：<title>"  # 更新用「更新卡片：<title>」
git -C "$WT" push -u origin "$BR"
```

6. 新提案用 `gh pr create --repo lllloo/playbook --base main --head "$BR" --title "新增卡片：<title>" --body-file <說明檔>`（更新卡片調整標題）。已授權更新既有 PR 就核實原 PR 的遠端 head，回報原 URL，不另開 PR。`gh` 一律帶 `--repo`，不依 cwd 推到其他專案。
7. 完成後保留隔離工作樹供檢視，回報其路徑。任一步失敗就停止，回報步驟、錯誤、分支與工作樹；不刪分支、不 reset、不為復原切換使用者主工作樹。

PR 說明（寫到 scratchpad 的暫存檔再 `--body-file`）：

```markdown
## 摘要
<一兩句：這張卡解決什麼坑>

## 來源
- <查證用的一手來源 URL>

## 未查證
- <查不到一手來源、因此沒寫進卡片的事實；沒有就寫「無」>
```

### 3.4 回報

完成後告訴使用者：PR URL、隔離工作樹路徑、卡片路徑（`cards/<slug>.md`）、是新卡還是更新、「未查證」清單（若有）。合併請使用者到 GitHub 審核。
