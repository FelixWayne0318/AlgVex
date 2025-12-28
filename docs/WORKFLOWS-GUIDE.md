# Claude Code 模块化工作流完整指南

本文档详细介绍 AlgVex 仓库中所有 GitHub Actions 工作流模块的功能、配置和使用方法。

## 目录

- [架构概览](#架构概览)
- [工作流模块列表](#工作流模块列表)
- [模块详解](#模块详解)
  - [1. claude.yml - 交互式响应](#1-claudeyml---交互式响应)
  - [2. pr-review.yml - PR 自动审查](#2-pr-reviewyml---pr-自动审查)
  - [3. issue-triage.yml - Issue 自动分类](#3-issue-triageyml---issue-自动分类)
  - [4. issue-deduplication.yml - Issue 重复检测](#4-issue-deduplicationyml---issue-重复检测)
  - [5. ci.yml - 持续集成](#5-ciyml---持续集成)
  - [6. ci-failure-auto-fix.yml - CI 失败自动修复](#6-ci-failure-auto-fixyml---ci-失败自动修复)
  - [7. test-failure-analysis.yml - 测试失败分析](#7-test-failure-analysisyml---测试失败分析)
  - [8. manual-code-analysis.yml - 手动代码分析](#8-manual-code-analysisyml---手动代码分析)
- [工作流触发关系](#工作流触发关系)
- [配置说明](#配置说明)
- [故障排除](#故障排除)

---

## 架构概览

```
GitHub 事件
    │
    ├─── Issue 评论 @claude ──────────▶ claude.yml
    │
    ├─── PR 评论 @claude ─────────────▶ claude.yml
    │
    ├─── 新 Issue 创建 ───────────────▶ issue-triage.yml
    │                                   issue-deduplication.yml
    │
    ├─── PR 创建/更新 ────────────────▶ pr-review.yml
    │                                   ci.yml
    │
    ├─── CI 失败 ─────────────────────▶ ci-failure-auto-fix.yml
    │                                   test-failure-analysis.yml
    │
    └─── 手动触发 ────────────────────▶ manual-code-analysis.yml
```

---

## 工作流模块列表

| 文件 | 功能 | 触发条件 |
|------|------|----------|
| `claude.yml` | @claude 交互响应 | Issue/PR 评论中 @claude |
| `pr-review.yml` | PR 自动代码审查 | PR 创建、更新、ready_for_review |
| `issue-triage.yml` | Issue 自动分类标签 | 新 Issue 创建 |
| `issue-deduplication.yml` | Issue 重复检测 | 新 Issue 创建 |
| `ci.yml` | 基础 CI 检查 | Push 到 main 或 PR |
| `ci-failure-auto-fix.yml` | CI 失败自动修复 | CI workflow 失败 |
| `test-failure-analysis.yml` | 测试失败分析 | CI workflow 失败 |
| `manual-code-analysis.yml` | 手动代码分析 | 手动触发 |

---

## 模块详解

### 1. claude.yml - 交互式响应

**功能**：响应用户在 Issue 或 PR 中 @claude 的请求，执行代码编写、问题解答等任务。

**触发条件**：
- Issue 评论包含 `@claude`
- PR 评论包含 `@claude`
- PR Review 评论包含 `@claude`
- 新 Issue 标题或内容包含 `@claude`

**使用示例**：
```
@claude 请帮我实现一个用户登录功能

@claude 这段代码有什么问题？请帮我修复

@claude 请为这个函数添加单元测试
```

**关键配置**：
```yaml
timeout-minutes: 30          # 最长运行 30 分钟
use_sticky_comment: "true"   # 使用固定评论，避免刷屏
allowed_bots: "dependabot[bot],renovate[bot]"  # 允许的 bot
```

**分支行为**：
- 在 **Open PR** 中评论：推送到现有 PR 分支
- 在 **Issue** 中评论：创建新分支 `claude/issue-{number}-{timestamp}`

---

### 2. pr-review.yml - PR 自动审查

**功能**：自动对新创建或更新的 PR 进行代码审查。

**触发条件**：
- PR 创建 (`opened`)
- PR 更新 (`synchronize`)
- PR 标记为 ready for review (`ready_for_review`)
- PR 重新打开 (`reopened`)

**跳过条件**：
- PR 标题包含 `[skip review]`
- PR 标题包含 `[wip]`

**审查重点**：
1. **代码质量** - 最佳实践、可读性、可维护性
2. **安全性** - 漏洞检测、输入验证、权限检查
3. **性能** - 瓶颈识别、查询效率、资源使用
4. **测试** - 测试覆盖率、边界情况、测试质量
5. **文档** - 代码注释、README 更新、API 文档

**关键配置**：
```yaml
timeout-minutes: 15          # 最长运行 15 分钟
track_progress: true         # 显示进度追踪
```

---

### 3. issue-triage.yml - Issue 自动分类

**功能**：自动为新创建的 Issue 添加分类标签。

**触发条件**：
- 新 Issue 创建 (`issues: opened`)

**处理逻辑**：
1. 读取 Issue 标题和内容
2. 分析 Issue 类型（bug、feature、question、documentation）
3. 判断优先级（low、medium、high、critical）
4. 识别相关组件或代码区域
5. 自动添加对应标签

**关键配置**：
```yaml
timeout-minutes: 10
allowed_non_write_users: "*"  # 允许所有用户创建 Issue
```

---

### 4. issue-deduplication.yml - Issue 重复检测

**功能**：检测新创建的 Issue 是否与现有 Issue 重复。

**触发条件**：
- 新 Issue 创建 (`issues: opened`)

**检测标准**：
- 相同的 bug 或错误报告
- 相同的功能请求（即使措辞不同）
- 相同的问题
- 描述相同根本问题的 Issue

**处理逻辑**：
1. 获取新 Issue 详情
2. 搜索相似的现有 Issue
3. 如果发现重复：
   - 添加评论，链接到原始 Issue
   - 添加 `duplicate` 标签
   - 建议用户关注原始 Issue
4. 如果不是重复：不做任何操作

---

### 5. ci.yml - 持续集成

**功能**：基础的持续集成检查。

**触发条件**：
- Push 到 `main` 分支
- PR 目标为 `main` 分支

**检查内容**：
- README.md 文件存在性
- Workflow 文件数量统计

**可扩展**：可以添加更多检查项，如：
- 代码风格检查（ESLint、Prettier）
- 单元测试运行
- 类型检查（TypeScript）
- 构建验证

---

### 6. ci-failure-auto-fix.yml - CI 失败自动修复

**功能**：当 CI 失败时，自动分析错误并尝试修复。

**触发条件**：
- CI workflow 运行完成且结论为 `failure`
- 存在关联的 PR
- 分支名不以 `claude-fix-` 开头（防止循环）

**处理流程**：
1. 检出失败的分支
2. 创建修复分支 `claude-fix-{branch}-{run_id}`
3. 获取 CI 失败详情和错误日志
4. Claude 分析错误原因
5. 尝试自动修复
6. 提交并推送修复

**关键配置**：
```yaml
timeout-minutes: 20
claude_args: "--allowedTools 'Edit,MultiEdit,Write,Read,Glob,Grep,LS,Bash(git:*),Bash(npm:*),Bash(npx:*),Bash(gh:*)'"
```

---

### 7. test-failure-analysis.yml - 测试失败分析

**功能**：分析 CI 失败是否为 Flaky 测试（不稳定测试）。

**触发条件**：
- CI workflow 运行完成且结论为 `failure`

**分析标准**：
- 超时错误
- 竞态条件
- 网络错误
- 间歇性的断言失败
- 之前提交中通过的测试

**输出结果**：
```json
{
  "is_flaky": true/false,
  "confidence": 0.0-1.0,
  "summary": "一句话解释"
}
```

**自动重试**：
- 如果判断为 Flaky 测试且置信度 >= 0.7
- 自动重新触发 CI workflow

---

### 8. manual-code-analysis.yml - 手动代码分析

**功能**：手动触发的代码分析工具。

**触发方式**：
1. 进入 GitHub → Actions
2. 选择 "Manual Code Analysis"
3. 点击 "Run workflow"
4. 选择分析类型

**分析类型**：
| 类型 | 说明 |
|------|------|
| `summarize-commit` | 总结最新提交的变更内容 |
| `security-review` | 安全漏洞审查 |

---

## 工作流触发关系

```
                    ┌──────────────────┐
                    │    用户操作       │
                    └────────┬─────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
        ▼                    ▼                    ▼
┌───────────────┐   ┌───────────────┐   ┌───────────────┐
│ Issue 评论    │   │ 创建 PR       │   │ 创建 Issue    │
│ @claude       │   │               │   │               │
└───────┬───────┘   └───────┬───────┘   └───────┬───────┘
        │                   │                   │
        ▼                   ▼                   ▼
┌───────────────┐   ┌───────────────┐   ┌───────────────┐
│ claude.yml    │   │ pr-review.yml │   │issue-triage   │
│               │   │ ci.yml        │   │issue-dedup    │
└───────────────┘   └───────┬───────┘   └───────────────┘
                            │
                            ▼
                    ┌───────────────┐
                    │ CI 失败？      │
                    └───────┬───────┘
                            │ 是
                            ▼
                    ┌───────────────┐
                    │ci-failure-fix │
                    │test-analysis  │
                    └───────────────┘
```

---

## 配置说明

### 认证配置

所有 Claude 工作流使用 OAuth Token 认证：

```yaml
claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
```

确保在仓库 Settings → Secrets and variables → Actions 中配置了 `CLAUDE_CODE_OAUTH_TOKEN`。

### 并发控制

每个工作流都配置了并发控制，防止同一 PR/Issue 的多个运行相互冲突：

```yaml
concurrency:
  group: claude-${{ github.event.issue.number || github.event.pull_request.number }}
  cancel-in-progress: false
```

### 超时设置

| 工作流 | 超时时间 |
|--------|----------|
| claude.yml | 30 分钟 |
| pr-review.yml | 15 分钟 |
| issue-triage.yml | 10 分钟 |
| issue-deduplication.yml | 10 分钟 |
| ci-failure-auto-fix.yml | 20 分钟 |
| test-failure-analysis.yml | 10 分钟 |
| manual-code-analysis.yml | 15 分钟 |

---

## 故障排除

### 问题：Workflow 未触发

**检查项**：
1. Workflow 文件是否在 `main` 分支的 `.github/workflows/` 目录
2. YAML 语法是否正确
3. 触发条件是否满足
4. 是否有权限问题

### 问题：Claude 响应超时

**解决方案**：
1. 拆分复杂任务为多个小请求
2. 调整 `timeout-minutes` 配置
3. 使用 `--max-turns` 限制对话轮数

### 问题：CI 失败自动修复未触发

**检查项**：
1. CI workflow 名称必须是 `"CI"`
2. 必须有关联的 PR（main 分支直接推送不触发）
3. 分支名不能以 `claude-fix-` 开头

### 问题：重复的评论刷屏

**解决方案**：
确保配置了 `use_sticky_comment: "true"`，Claude 会更新同一条评论而不是创建新评论。

---

## 相关链接

- [Claude Code Action 官方文档](https://github.com/anthropics/claude-code-action)
- [GitHub Actions 文档](https://docs.github.com/actions)
- [AlgVex 工作流使用指南](./WORKFLOW.md)
