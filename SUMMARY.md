# AlgVex 仓库内容总结

## 项目概述

**AlgVex** 是一个 AI 辅助的量化研究和自动化系统，通过 GitHub + Claude Code + Slack 集成实现自动化工作流。

## 核心目标

- 通过 Claude 自动化研究与代码生成
- 使用 GitHub 作为唯一的事实来源（Single Source of Truth）
- 通过 Slack 触发工作流
- 通过 Pull Request 保持所有变更可追踪

## 执行模型

```
Slack → GitHub Issue/Comment → GitHub Actions → Claude → PR → Review
```

## 仓库结构

```
AlgVex/
├── .github/
│   ├── pull_request_template.md    # PR 模板
│   └── workflows/
│       └── claude.yml              # Claude Code 工作流配置
├── docs/
│   └── WORKFLOW.md                 # 详细工作流程指南
├── README.md                       # 项目主说明文档
├── STRUCTURE.md                    # 仓库结构说明
├── SUMMARY.md                      # 本总结文档
├── 123.md                          # 测试文件
└── .gitignore                      # Python 项目忽略配置
```

## 核心功能

### Claude Code 工作流配置 (`.github/workflows/claude.yml`)

支持两种运行模式：

| 模式 | 触发方式 | 权限 | 功能 |
|------|---------|------|------|
| **PR 读写模式** | PR 评论 `@claude` | 读写 | 分析代码、修改文件、推送到 PR 分支 |
| **Issue 分析模式** | Issue 评论 `@claude` | 只读 | 分析 main 分支代码、读取 Actions 日志 |

### 工作流特性

- **并发控制**：同一 PR/Issue 的任务不会互相取消
- **超时设置**：30 分钟
- **对话轮数**：最多 20 轮
- **Slack 通知**：任务完成后自动推送通知

## Claude 使用规则

1. **不要**直接推送到 main 分支
2. **始终**在功能分支中工作
3. **使用**清晰的提交信息
4. **优先**选择小的、可审查的更改
5. **不确定时**先询问再行动

## 如何使用

### 方式一：PR 评论（推荐）

1. 创建功能分支并推送
2. 创建 Pull Request
3. 在 PR 评论区输入 `@claude` + 任务描述
4. Claude 直接推送修改到 PR 分支

### 方式二：Issue 评论

1. 创建 Issue
2. 在评论区输入 `@claude` + 任务描述
3. Claude 进行只读分析并回复

## 技术栈

- **CI/CD**：GitHub Actions
- **AI 助手**：Claude Code (anthropics/claude-code-action@v1)
- **通知**：Slack (slackapi/slack-github-action@v2.0.0)
- **语言环境**：Python（根据 .gitignore 配置）

## 相关资源

- [Claude Code Action 官方文档](https://github.com/anthropics/claude-code-action)
- [GitHub Actions 文档](https://docs.github.com/actions)
