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
│   ├── pull_request_template.md         # PR 模板
│   └── workflows/
│       ├── claude.yml                   # Claude Code (PR) 工作流
│       └── claude-issue.yml             # Claude Code (Issue) 只读工作流
├── docs/
│   └── WORKFLOW.md                      # 详细工作流程指南
├── README.md                            # 项目主说明文档
├── STRUCTURE.md                         # 仓库结构说明
├── SUMMARY.md                           # 本总结文档
├── WORKFLOW_ANALYSIS.md                 # 工作流详细分析报告
├── 123.md                               # 测试文件
└── .gitignore                           # Python 项目忽略配置
```

## Claude Code 工作流

### 工作流配置文件

| 文件 | 名称 | 用途 |
|------|------|------|
| `.github/workflows/claude.yml` | Claude Code (PR) | PR 评论触发，支持 PLAN/APPLY 双模式 |
| `.github/workflows/claude-issue.yml` | Claude Code (Issue Read-Only) | Issue 评论触发，只读分析模式 |

### 运行模式详解

#### 1. PR 工作流 (`claude.yml`)

**触发条件：**
- PR 会话评论包含 `@claude`
- PR 代码审查评论包含 `@claude`

**模式切换：**
| 模式 | 触发条件 | 权限 | 功能 |
|------|---------|------|------|
| **PLAN** (默认) | 评论不含 "apply" | 只读 | 分析代码、生成计划、不修改文件 |
| **APPLY** | 评论包含 "apply" | 读写 | 分析代码、修改文件、推送到 PR 分支 |

**PLAN 模式工具限制：**
- 允许：`Glob`, `Grep`, `Read`, `LS`, `View`
- 禁止：`Edit`, `MultiEdit`, `Write`, `Bash`, `WebSearch`, `WebFetch`

**APPLY 模式工具限制：**
- 禁止：`WebSearch`, `WebFetch`
- 其他工具均可使用

#### 2. Issue 工作流 (`claude-issue.yml`)

**触发条件：**
- Issue 评论包含 `@claude`（非 PR 的 Issue）

**特性：**
- 只读权限 (`contents: read`)
- 自动读取 Actions 日志进行分析
- 支持通过 `run_id=xxxxx` 或 Actions URL 指定特定运行

**工具限制：**
- 允许：`Glob`, `Grep`, `Read`, `LS`, `View`
- 禁止：`Edit`, `MultiEdit`, `Write`, `Bash`, `WebSearch`, `WebFetch`

### 工作流特性

| 特性 | PR 工作流 | Issue 工作流 |
|------|----------|-------------|
| 超时时间 | 30 分钟 | 20 分钟 |
| 对话轮数 | 20 轮 | 12 轮 |
| 并发控制 | 按 PR 编号分组 | 按 Issue 编号分组 |
| Slack 通知 | 支持 | 支持 |
| CI 上下文 | 自动读取 PR 关联的 Actions 日志 | 支持手动指定 run_id |

### 安全特性

1. **命令注入防护**：用户评论通过环境变量传递，保存到临时文件后再读取
2. **权限分离**：PLAN 模式和 Issue 模式严格限制为只读
3. **API 错误处理**：所有 GitHub API 调用包含错误检查和警告输出
4. **动态分支检测**：使用 `github.event.repository.default_branch` 避免硬编码

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
3. 在 PR 评论区输入：
   - `@claude 分析这段代码` → PLAN 模式（只分析）
   - `@claude apply 修复这个 bug` → APPLY 模式（分析 + 修改）
4. Claude 在评论中回复结果

### 方式二：Issue 评论

1. 创建 Issue
2. 在评论区输入 `@claude` + 任务描述
3. 可选：添加 `run_id=xxxxx` 指定要分析的 Actions 运行
4. Claude 进行只读分析并回复

## 配置要求

### 必需的 Secrets

| Secret 名称 | 用途 | 必需 |
|------------|------|------|
| `CLAUDE_CODE_OAUTH_TOKEN` | Claude Code 认证 | ✅ 是 |
| `SLACK_WEBHOOK_URL` | Slack 通知 | ❌ 可选 |

### 权限要求

工作流需要以下权限才能正常运行：
- `contents: write/read`
- `pull-requests: write/read`
- `issues: write`
- `id-token: write`
- `actions: read`

## 故障排除

### 工作流不触发？

1. **检查 Secrets**：确保 `CLAUDE_CODE_OAUTH_TOKEN` 已配置
2. **检查权限**：仓库设置 → Actions → General → 确保 Actions 已启用
3. **检查触发条件**：评论必须包含 `@claude` 关键字
4. **检查分支**：`issue_comment` 事件使用默认分支（main）上的工作流文件

### PR 评论无反应？

1. 确保 PR 处于 **Open** 状态（已关闭的 PR 不触发工作流）
2. 确保评论在 PR 会话中，而不是 Issue
3. 检查工作流文件是否已合并到 main 分支

### Issue 评论无反应？

1. 确保 Issue 不是 PR（PR 会话评论由 claude.yml 处理）
2. 确保工作流文件在 main 分支上且格式正确
3. 检查 GitHub Actions 是否已启用

## 技术栈

- **CI/CD**：GitHub Actions
- **AI 助手**：Claude Code (`anthropics/claude-code-action@v1`)
- **通知**：Slack (`slackapi/slack-github-action@v2.0.0`)
- **语言环境**：Python（根据 .gitignore 配置）

## 相关资源

- [Claude Code Action 官方文档](https://github.com/anthropics/claude-code-action)
- [GitHub Actions 文档](https://docs.github.com/actions)
- [详细工作流程指南](docs/WORKFLOW.md)
- [工作流分析报告](WORKFLOW_ANALYSIS.md)

---

**最后更新：** 2025-12-28
