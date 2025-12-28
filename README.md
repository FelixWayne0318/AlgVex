# AlgVex

AI-powered quantitative investment research platform powered by Claude Code and Qlib.

## 📚 文档

- [工作流使用指南](docs/WORKFLOW.md) - Claude Code 基础工作流程
- [完整工作流指南](docs/WORKFLOWS-GUIDE.md) - 8个工作流模块详细说明
  - Claude 交互式响应
  - PR 自动审查
  - Issue 自动分类
  - Issue 重复检测
  - CI 持续集成
  - CI 失败自动修复
  - 测试失败分析
  - 手动代码分析
  - **新增**: Qlib 集成说明

## 🤖 GitHub Actions 工作流

本项目集成了 8 个自动化工作流，由 Claude Code 驱动：

| 工作流 | 功能 | 触发方式 |
|--------|------|----------|
| `claude.yml` | @claude 交互响应 | Issue/PR 评论 @claude |
| `pr-review.yml` | PR 自动代码审查 | PR 创建/更新 |
| `issue-triage.yml` | Issue 自动分类 | 新 Issue 创建 |
| `issue-deduplication.yml` | Issue 重复检测 | 新 Issue 创建 |
| `ci.yml` | 基础 CI 检查 | Push/PR |
| `ci-failure-auto-fix.yml` | CI 失败自动修复 | CI 失败 |
| `test-failure-analysis.yml` | 测试失败分析 | CI 失败 |
| `manual-code-analysis.yml` | 手动代码分析 | 手动触发 |

详细说明请查看 [完整工作流指南](docs/WORKFLOWS-GUIDE.md)

## 📊 Qlib 集成

本项目集成了微软开源的 AI 驱动量化投资平台 [Qlib](https://github.com/microsoft/qlib)。

**当前 Qlib 版本**: v0.9.7 (2024-08-15)

### 快速开始

使用提供的脚本快速设置 Qlib:

```bash
# 克隆 Qlib v0.9.7
chmod +x scripts/setup-qlib.sh
./scripts/setup-qlib.sh

# 或指定其他版本
./scripts/setup-qlib.sh v0.9.6
```

更多集成方式和使用说明，请查看 [Qlib 集成说明](docs/WORKFLOWS-GUIDE.md#qlib-集成说明)

## 🚀 使用 Claude Code

### 在 Issue 中使用

```
@claude 请帮我实现用户登录功能
```

### 在 PR 中使用

```
@claude 请添加单元测试
@claude 这段代码有什么问题？
```

详细使用方法请查看 [工作流使用指南](docs/WORKFLOW.md)

## 🔗 相关链接

- [Claude Code Action](https://github.com/anthropics/claude-code-action)
- [Qlib 官方文档](https://qlib.readthedocs.io/)
- [Qlib GitHub 仓库](https://github.com/microsoft/qlib)

<!-- workflow test -->
