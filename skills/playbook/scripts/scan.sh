#!/usr/bin/env bash
# playbook 卡片庫的唯讀查詢：一律讀 origin/main 快照的 Git tree，不動工作樹。
# exit：0 成功；1 grep 無命中；2 錯誤（不能當作「沒有卡片」）。
set -euo pipefail

REPO="${PLAYBOOK_REPO:-$HOME/code/playbook}"

die() { echo "$*" >&2; exit 2; }
g() { git -C "$REPO" "$@"; }

usage() {
  cat >&2 <<'EOF'
用法：
  scan.sh snapshot [--strict]   fetch origin/main 並印出快照 commit；--strict 時 fetch 失敗即停止
  scan.sh list <sha>            每張卡一行：<title> — <description>  (cards/<slug>.md)
  scan.sh meta <sha>            每張卡的路徑與 frontmatter
  scan.sh grep <sha> <詞>...    正文全文搜尋（不分大小寫、固定字串、多詞為 OR），印出命中路徑
  scan.sh show <sha> <slug|路徑> 讀檔；slug 對應 cards/<slug>.md，以 .md 結尾則視為 repo 內路徑
EOF
  exit 2
}

[ -d "$REPO/.git" ] || die "playbook repo 不存在：$REPO。請使用者自行執行 gh repo clone lllloo/playbook ~/code/playbook"

# 印出快照中所有卡片路徑
cards() {
  local all
  all=$(g ls-tree -r --name-only "$1" -- cards/) || die "讀取快照 $1 失敗，不能當作沒有卡片。"
  grep -E '^cards/[^/]+\.md$' <<<"$all" || true
}

# 從 stdin 取出 frontmatter（首行 --- 到下一個 ---）
frontmatter() { awk 'NR==1 && /^---$/ {fm=1; next} fm && /^---$/ {exit} fm'; }

# 取 frontmatter 的單行欄位值並去掉外層引號
field() { sed -n "s/^$1:[[:space:]]*//p" | head -n1 | sed -E 's/^"(.*)"$/\1/; s/^'\''(.*)'\''$/\1/'; }

cmd=${1:-}; [ $# -gt 0 ] && shift
case "$cmd" in
  snapshot)
    if ! g fetch -q origin '+refs/heads/main:refs/remotes/origin/main'; then
      [ "${1:-}" = --strict ] && die "fetch 失敗：提案不能拿離線快取當基底，停止。"
      echo "警告：fetch 失敗，只能用快取 origin/main，可能過期。" >&2
    fi
    g rev-parse --verify -q 'refs/remotes/origin/main^{commit}' || die "無 origin/main 快取，停止。"
    ;;
  list|meta)
    [ $# -eq 1 ] || usage
    sha=$1; files=$(cards "$sha")
    if [ -z "$files" ]; then echo "playbook 目前沒有卡片"; exit 0; fi
    while IFS= read -r f; do
      fm=$(g show "$sha:$f" | frontmatter)
      if [ "$cmd" = meta ]; then
        printf '== %s\n%s\n' "$f" "$fm"
      else
        printf '%s — %s  (%s)\n' "$(field title <<<"$fm")" "$(field description <<<"$fm")" "$f"
      fi
    done <<<"$files"
    ;;
  grep)
    [ $# -ge 2 ] || usage
    sha=$1; shift
    pats=(); for p in "$@"; do pats+=(-e "$p"); done
    rc=0; out=$(g grep -i -l -F "${pats[@]}" "$sha" -- 'cards/*.md') || rc=$?
    case $rc in
      0) printf '%s\n' "$out" | sed "s|^$sha:||" ;;
      1) exit 1 ;;
      *) die "git grep 失敗（exit $rc），不能當作無命中。" ;;
    esac
    ;;
  show)
    [ $# -eq 2 ] || usage
    case "$2" in *.md) path=$2 ;; *) path="cards/$2.md" ;; esac
    g show "$1:$path"
    ;;
  *) usage ;;
esac
