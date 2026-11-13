# skills

自寫的全域 [Agent Skills](https://agentskills.io)，經 `npx skills` 安裝到各裝置。

## 目錄

一 skill 一目錄：`skills/<name>/SKILL.md`。這是 `npx skills` 的慣例掃描位置。

| skill | 說明 |
|---|---|
| `bmad-goal` | 依序跑完 BMAD 的 create-story → dev-story → code-review |
| `nt` | Notion 任務看板（Projects / Tasks）：認領、開立任務，回報進度與卡住 |

## 安裝

```
npx skills add lllloo/skills -g --skill <name>
```

固定帶 `--skill`，逐支安裝。實體落在 `~/.agents/skills/<name>/`，各工具的探索點
symlink 由 `npx skills` 自建。更新走 `npx skills update -g`。

