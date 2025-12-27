# 仓库结构

```
AlgVex/
├── .github/
│   ├── pull_request_template.md    # PR 模板
│   └── workflows/
│       └── claude.yml              # Claude Code 工作流配置
├── docs/
│   └── WORKFLOW.md                 # 工作流程指南
├── 123.md                          # 测试文件
└── README.md                       # 项目说明
```

## 核心文件说明

### `.github/workflows/claude.yml`

Claude Code GitHub Action 配置，支持两种模式：

| 模式 | 触发方式 | 功能 |
|------|---------|------|
| PR 读写模式 | PR 评论 @claude | 分析代码 + 修改文件 + 推送 |
| Issue 分析模式 | Issue 评论 @claude | 只读分析 + 读取 Actions 日志 |

### `docs/WORKFLOW.md`

详细的使用指南，包括：
- 工作流概述
- PR 评论模式说明
- 移动端使用指南
- 常见问题解答

## 如何测试 @claude

在此 PR 的评论区输入：
```
@claude 根目录新建 acc.md，内容为 hello bike
```
