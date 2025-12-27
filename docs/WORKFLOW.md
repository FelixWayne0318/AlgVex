# Claude Code 工作流程指南

本文档介绍如何使用 GitHub + Claude Code + Slack 集成工作流。

## 工作流概述

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   GitHub    │────▶│ Claude Code │────▶│    Slack    │
│  (PR/Issue) │     │  (AI 编码)   │     │   (通知)    │
└─────────────┘     └─────────────┘     └─────────────┘
```

## 推荐工作方式：PR 评论模式

### 为什么推荐 PR 评论？

| 方式 | 分支行为 | 适用场景 |
|------|---------|---------|
| Issue 评论 @claude | 每次创建新分支 | 快速原型、独立任务 |
| **PR 评论 @claude** | **推送到现有分支** | **迭代开发、代码审查** |

### 操作步骤

1. **创建功能分支**
   ```bash
   git checkout -b feature/my-feature
   git push -u origin feature/my-feature
   ```

2. **创建 Pull Request**
   - 在 GitHub 网页端：点击 "New pull request"
   - 选择你的功能分支 → main

3. **在 PR 中 @claude**
   ```
   @claude 请帮我实现用户登录功能
   ```

4. **Claude 响应**
   - 阅读代码上下文
   - 直接推送到 PR 分支
   - 在评论中反馈结果

5. **迭代修改**
   - 继续在同一 PR 中 @claude
   - 所有更改保持在同一分支

## 移动端使用指南

### GitHub Mobile App 限制

GitHub Mobile 应用**不支持**直接创建新分支。替代方案：

#### 方案 A：使用移动浏览器
1. 在 Safari/Chrome 打开 github.com
2. 导航到仓库 → 点击分支下拉菜单
3. 输入新分支名称 → 点击 "Create branch"

#### 方案 B：桌面创建，移动操作
1. 在电脑上创建分支和 PR
2. 在手机 GitHub App 中找到 PR
3. 添加评论 @claude 进行操作

#### 方案 C：Issue 快速模式
1. 在 GitHub App 中创建 Issue
2. 评论 @claude + 任务描述
3. Claude 自动创建分支并工作

## 触发方式汇总

| 触发方式 | 命令示例 |
|---------|---------|
| Issue 评论 | `@claude 请修复登录 bug` |
| PR 评论 | `@claude 请添加单元测试` |
| PR 代码审查 | `@claude 这段代码有什么问题？` |
| 分配 Issue | 将 Issue 分配给 `claude[bot]` |
| 清理分支 | `@claude cleanup` |

## 常见问题解答

### Q: Claude 每次都创建新分支怎么办？
A: 使用 PR 评论模式，Claude 会推送到现有 PR 分支。

### Q: 如何查看 Claude 的工作进度？
A:
- GitHub Actions 页面查看运行日志
- Slack 频道接收完成通知
- PR 评论区查看结果反馈

### Q: Claude 的回复太慢？
A: 当前配置最大 20 轮对话，超时 30 分钟。复杂任务可能需要几分钟。

### Q: 如何控制 Claude 的权限？
A: 在 `claude.yml` 中配置 `allowed_tools` 限制可用工具。

## 最佳实践

1. **任务描述清晰**：告诉 Claude 具体要做什么
2. **分步操作**：复杂任务拆分成多个小请求
3. **代码审查**：Claude 的修改仍需人工审核
4. **定期清理**：使用 `@claude cleanup` 删除已合并分支

## 相关链接

- [Claude Code Action 文档](https://github.com/anthropics/claude-code-action)
- [GitHub Actions 文档](https://docs.github.com/actions)
