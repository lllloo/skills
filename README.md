# skills

自寫的全域 [Agent Skills](https://agentskills.io)，經 `npx skills` 安裝到各裝置。

設定同步工具在另一個 repo：[lllloo/ai-config-sync](https://github.com/lllloo/ai-config-sync)，
其中的 `skills-lock.json` 記錄各裝置實際安裝了哪些 skill（含本 repo 與外部來源）。

## 目錄

一 skill 一目錄：`skills/<name>/SKILL.md`。這是 `npx skills` 的慣例掃描位置。

| skill | 說明 |
|---|---|
| `bmad-goal` | 依序跑完 BMAD 的 create-story → dev-story → code-review |
| `herdr-agent` | 在 Herdr 內開新 tab 交派任務給另一個 coding agent |
| `map` | 產出本地 HTML 架構圖（模組邊界、狀態機、循序圖、ER 切片） |
| `map-fast` | 用內建 elkjs 算佈局，產出可平移縮放的關係圖 |
| `project-map` | 建立並增量更新可互動的專案地圖 |

## 安裝

```
npx skills add lllloo/skills -g --skill <name>
```

固定帶 `--skill`，逐支安裝。實體落在 `~/.agents/skills/<name>/`，各工具的探索點
symlink 由 `npx skills` 自建。更新走 `npx skills update -g`。

## 測試

```
npm test
```

零外部相依，只用 Node.js 內建模組。目前涵蓋 `map` skill 的責任邊界回歸斷言。
