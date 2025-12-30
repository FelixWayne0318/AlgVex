# Claude Code 配置指南

## 项目概述

AlgVex 是一个由 Claude Code 驱动的 AI 量化投资研究平台，集成了 Qlib 和 Hummingbot。

## 工作流架构

本项目使用官方 [claude-code-action](https://github.com/anthropics/claude-code-action) 实现，所有工作流完全按照官方示例配置。

### 工作流列表

| 文件 | 官方示例 | 功能 |
|------|----------|------|
| `claude.yml` | claude.yml | @claude 交互响应 |
| `pr-review.yml` | pr-review-comprehensive.yml | PR 自动审查 |
| `issue-deduplication.yml` | issue-deduplication.yml | Issue 重复检测 |
| `issue-triage.yml` | issue-triage.yml | Issue 自动分类 |
| `test-failure-analysis.yml` | test-failure-analysis.yml | Flaky 测试检测 |
| `ci-failure-auto-fix.yml` | ci-failure-auto-fix.yml | CI 失败自动修复 |
| `manual-code-analysis.yml` | manual-code-analysis.yml | 手动代码分析 |
| `ci.yml` | (自定义) | 基础 CI 检查 |

### 触发关系

```
GitHub 事件 ──► 工作流响应

@claude 提及 ──────────────► claude.yml
PR 创建/更新 ──────────────► pr-review.yml + ci.yml
Issue 创建 ────────────────► issue-deduplication.yml + issue-triage.yml
CI 失败 ───────────────────► test-failure-analysis.yml + ci-failure-auto-fix.yml
手动触发 ──────────────────► manual-code-analysis.yml
```

## 认证配置

所有 Claude 工作流使用 OAuth Token：

```yaml
claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
```

### 配置步骤

1. 访问 [Claude Code](https://claude.ai/code) 获取 OAuth Token
2. 进入仓库 **Settings** → **Secrets and variables** → **Actions**
3. 添加 `CLAUDE_CODE_OAUTH_TOKEN` secret

## 代码风格规范

### Shell 脚本
- 必须包含 `set -euo pipefail`
- 使用颜色输出（GREEN、RED、YELLOW、NC）
- 版本号使用正则验证

### YAML 文件
- 缩进使用 2 个空格
- 使用 `|` 处理多行字符串
- heredoc 内容需要缩进（避免 YAML 别名错误）

### 提交消息
- 格式: `<类型>: <描述>`
- 类型: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`

## 参考资源

- [Claude Code Action](https://github.com/anthropics/claude-code-action)
- [Qlib 官方文档](https://qlib.readthedocs.io/)
- [Hummingbot 官方文档](https://docs.hummingbot.org/)

---

**最后更新**: 2025-12-30
**维护者**: @FelixWayne0318
