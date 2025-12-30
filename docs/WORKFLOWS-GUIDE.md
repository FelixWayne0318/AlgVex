# Claude Code 工作流指南

本文档详细介绍 AlgVex 仓库中所有 GitHub Actions 工作流的功能和使用方法。

## 目录

- [架构概览](#架构概览)
- [工作流列表](#工作流列表)
- [模块详解](#模块详解)
- [配置说明](#配置说明)
- [故障排除](#故障排除)

---

## 架构概览

所有 Claude 工作流采用**独立设计**，基于 [claude-code-action 官方示例](https://github.com/anthropics/claude-code-action)。

```
GitHub 事件
    │
    ├─── Issue/PR 评论 @claude ─────▶ claude.yml
    │
    ├─── 新 Issue 创建 ─────────────▶ issue-triage.yml
    │                               ▶ issue-deduplication.yml
    │
    ├─── PR 创建/更新 ──────────────▶ pr-review.yml
    │                               ▶ ci.yml
    │
    ├─── CI 失败 ───────────────────▶ test-failure-analysis.yml
    │                               ▶ ci-failure-auto-fix.yml
    │
    └─── 手动触发 ──────────────────▶ manual-code-analysis.yml
```

**设计原则**：每个工作流独立运行，不依赖其他工作流的输出。

---

## 工作流列表

| 文件 | 功能 | 触发条件 |
|------|------|----------|
| `claude.yml` | @claude 交互响应 | Issue/PR 评论中 @claude |
| `pr-review.yml` | PR 自动代码审查 | PR 创建、更新、ready_for_review |
| `issue-triage.yml` | Issue 自动分类 | 新 Issue 创建 |
| `issue-deduplication.yml` | Issue 重复检测 | 新 Issue 创建 |
| `ci.yml` | 基础 CI 检查 | Push 到 main 或 PR |
| `test-failure-analysis.yml` | Flaky 测试检测 | CI 失败 |
| `ci-failure-auto-fix.yml` | CI 失败自动修复 | CI 失败 |
| `manual-code-analysis.yml` | 手动代码分析 | 手动触发 |

---

## 模块详解

### 1. claude.yml - 交互式响应

**功能**：响应 @claude 请求，执行代码编写、问题解答等任务。

**触发条件**：
- Issue/PR 评论包含 `@claude`
- PR Review 包含 `@claude`
- Issue 标题或内容包含 `@claude`

**使用示例**：
```
@claude 请帮我实现一个用户登录功能
@claude 这段代码有什么问题？
```

---

### 2. pr-review.yml - PR 自动审查

**功能**：自动对 PR 进行代码审查，支持进度追踪。

**触发条件**：
- PR 创建 (`opened`)
- PR 更新 (`synchronize`)
- PR 标记为 ready (`ready_for_review`)

**审查重点**：
1. 代码质量
2. 安全性
3. 性能
4. 测试覆盖
5. 文档完整性

---

### 3. issue-triage.yml - Issue 自动分类

**功能**：自动为新 Issue 添加分类标签。

**触发条件**：新 Issue 创建

**分类维度**：
- 类型：bug、feature、question、documentation
- 优先级：low、medium、high、critical
- 组件区域

---

### 4. issue-deduplication.yml - Issue 重复检测

**功能**：检测新 Issue 是否与现有 Issue 重复。

**触发条件**：新 Issue 创建

**处理逻辑**：
1. 获取新 Issue 详情
2. 搜索相似的现有 Issue
3. 如果发现重复：添加评论和 `duplicate` 标签
4. 如果不是重复：不做操作

---

### 5. ci.yml - 持续集成

**功能**：基础 CI 检查。

**触发条件**：
- Push 到 `main` 分支
- PR 目标为 `main` 分支

**检查内容**：
- README.md 存在性
- Workflow 文件格式
- Shell 脚本检查 (ShellCheck)
- YAML 格式检查 (yamllint)

---

### 6. test-failure-analysis.yml - Flaky 测试检测

**功能**：分析 CI 失败是否为 Flaky 测试。基于官方 Auto-Retry Flaky Tests 示例。

**触发条件**：CI 完成且失败

**分析标准**：
- 超时错误
- 竞态条件
- 网络错误
- 间歇性断言失败

**输出**：
```json
{
  "is_flaky": true/false,
  "confidence": 0.0-1.0,
  "summary": "一句话解释"
}
```

**自动重试**：如果判断为 Flaky 且置信度 >= 0.7，自动重新触发 CI。

---

### 7. ci-failure-auto-fix.yml - CI 失败自动修复

**功能**：自动分析 CI 错误并尝试修复。

**触发条件**：
- CI 失败
- 有关联的 PR
- 分支名不以 `claude-auto-fix-ci-` 开头

**处理流程**：
1. 检出失败分支
2. 创建修复分支
3. 获取 CI 失败日志
4. Claude 分析并修复
5. 提交修复

---

### 8. manual-code-analysis.yml - 手动代码分析

**功能**：手动触发的代码分析。

**分析类型**：
- `summarize-commit`：总结最新提交
- `security-review`：安全漏洞审查

**触发方式**：
1. GitHub → Actions
2. 选择 "Claude Commit Analysis"
3. 点击 "Run workflow"

---

## 配置说明

### 认证配置

所有 Claude 工作流使用 OAuth Token：

```yaml
claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
```

在仓库 Settings → Secrets → Actions 中配置 `CLAUDE_CODE_OAUTH_TOKEN`。

### 权限配置

标准权限配置：

```yaml
permissions:
  contents: read/write  # 仓库内容
  pull-requests: write  # PR 管理
  issues: write         # Issue 管理
  id-token: write       # OIDC 认证
  actions: read/write   # Actions 访问
```

### 超时设置

| 工作流 | 超时 |
|--------|------|
| claude.yml | 默认 |
| pr-review.yml | 默认 |
| issue-triage.yml | 10 分钟 |
| issue-deduplication.yml | 10 分钟 |
| ci-failure-auto-fix.yml | 默认 |
| test-failure-analysis.yml | 默认 |
| manual-code-analysis.yml | 默认 |

---

## 故障排除

### Workflow 未触发

检查项：
1. Workflow 文件在 `.github/workflows/` 目录
2. YAML 语法正确
3. 触发条件满足
4. 权限配置正确

### Claude 响应超时

解决方案：
1. 拆分复杂任务
2. 调整 timeout-minutes

### CI 失败修复未触发

检查项：
1. CI workflow 名称是 "CI"
2. 有关联的 PR
3. 分支名不以 `claude-auto-fix-ci-` 开头

---

## 相关链接

- [claude-code-action 官方文档](https://github.com/anthropics/claude-code-action)
- [GitHub Actions 文档](https://docs.github.com/actions)
