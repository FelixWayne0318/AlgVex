# 仓库结构

```
AlgVex/
├── .github/
│   ├── pull_request_template.md         # PR 模板
│   └── workflows/
│       ├── claude.yml                   # Claude Code (PR) 工作流
│       └── claude-issue.yml             # Claude Code (Issue) 只读工作流
├── docs/
│   └── WORKFLOW.md                      # 工作流程指南
├── README.md                            # 项目说明
├── STRUCTURE.md                         # 本文件 - 仓库结构
├── SUMMARY.md                           # 仓库内容总结
├── WORKFLOW_ANALYSIS.md                 # 工作流详细分析报告
├── 123.md                               # 测试文件
└── .gitignore                           # Python 项目忽略配置
```

## 核心文件说明

### `.github/workflows/claude.yml`

Claude Code PR 工作流配置，支持两种模式：

| 模式 | 触发条件 | 功能 |
|------|---------|------|
| **PLAN** (默认) | PR 评论 `@claude` 不含 "apply" | 只读分析，不修改代码 |
| **APPLY** | PR 评论 `@claude` 包含 "apply" | 分析 + 修改 + 推送 |

### `.github/workflows/claude-issue.yml`

Claude Code Issue 只读工作流：

| 触发方式 | 权限 | 功能 |
|---------|------|------|
| Issue 评论 `@claude` | 只读 | 分析代码、读取 Actions 日志 |

### `docs/WORKFLOW.md`

详细的使用指南，包括：
- 工作流概述
- PR 评论模式说明
- 移动端使用指南
- 常见问题解答

### `WORKFLOW_ANALYSIS.md`

工作流详细分析报告，包含：
- 功能分析
- 逻辑检查
- 改进建议

## 如何测试 @claude

### 在 PR 中测试：
```
@claude 分析这段代码有什么问题
```

### 带 APPLY 模式：
```
@claude apply 根目录新建 test.md，内容为 hello world
```

### 在 Issue 中测试：
```
@claude 分析最近的 Actions 运行日志
```
