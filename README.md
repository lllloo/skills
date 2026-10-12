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

## 安裝

```
npx skills add lllloo/skills -g --skill <name>
```

固定帶 `--skill`，逐支安裝。實體落在 `~/.agents/skills/<name>/`，各工具的探索點
symlink 由 `npx skills` 自建。更新走 `npx skills update -g`。

