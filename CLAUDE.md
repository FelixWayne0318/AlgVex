# Claude Code 配置指南

## 项目概述

AlgVex 是一个由 Claude Code 驱动的 AI 量化投资研究平台，集成了 Qlib 和 Hummingbot。

## 代码风格规范

### Shell 脚本
- **错误处理**: 所有脚本必须包含 `set -euo pipefail`
- **退出码检查**: 关键命令必须检查退出码
- **用户提示**: 使用带颜色的输出（GREEN、RED、YELLOW、NC 变量）
- **输入验证**: 版本号等输入必须使用正则表达式验证

示例：
```bash
#!/bin/bash
set -euo pipefail

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# 捕获退出码
output=$(git pull origin "$VERSION" 2>&1)
exit_code=$?
if [ "$exit_code" -eq 0 ]; then
    echo -e "${GREEN}✅ 成功${NC}"
fi
```

### GitHub Actions 工作流
- **超时设置**: 所有 job 必须设置 `timeout-minutes`
  - 交互式任务: 30 分钟
  - 自动修复任务: 20 分钟
  - 审查/分析任务: 10-15 分钟
- **权限控制**: 明确定义最小权限集
- **并发控制**: 使用 `concurrency` 防止重复运行
- **错误处理**: JSON 解析前必须验证格式和非空

### YAML 文件
- 缩进使用 2 个空格
- 多行字符串使用 `|` 或 `|2` 格式
- 变量引用使用 `${{ }}` 语法

### 文档
- **语言**: 使用中文（面向国内用户）
- **结构**: 清晰的章节划分，使用表格和代码块
- **链接**: 提供相关文档的内部链接

## 审查重点

### 1. 安全性
- ❌ **禁止硬编码凭据** - 必须使用 secrets
- ✅ **验证 `.gitignore`** - 确保排除 `.env` 等敏感文件
- ✅ **最小权限原则** - 工作流权限仅授予必需的访问
- ✅ **OIDC 认证** - 使用 `id-token: write`

### 2. 错误处理
- ✅ **JSON 解析保护**:
  ```yaml
  - name: Validate JSON
    run: |
      if [ -z '${{ steps.output.result }}' ]; then
        echo "valid=false" >> $GITHUB_OUTPUT
      elif echo '${{ steps.output.result }}' | jq -e . >/dev/null 2>&1; then
        echo "valid=true" >> $GITHUB_OUTPUT
      fi
  ```
- ✅ **变量空值检查**: 使用 `[ -n "$var" ]` 检查
- ✅ **步骤失败容错**: 对非关键步骤使用 `continue-on-error: true`

### 3. Shell 脚本特殊注意
- ❌ **禁止在条件语句后使用 PIPESTATUS**
  ```bash
  # 错误示例
  if git pull | grep "up to date"; then
      ...
  elif [ "${PIPESTATUS[0]}" -eq 0 ]; then  # Bug: PIPESTATUS 已被重置

  # 正确示例
  output=$(git pull 2>&1)
  exit_code=$?
  if echo "$output" | grep "up to date"; then
      ...
  elif [ "$exit_code" -eq 0 ]; then
  ```

### 4. 工作流设计
- ✅ **防止循环**: CI 自动修复检查分支名 `!startsWith(github.event.workflow_run.head_branch, 'claude-fix-')`
- ✅ **条件执行**: 使用 `if` 条件控制工作流执行
- ✅ **Sticky comments**: 使用 `use_sticky_comment: "true"` 避免重复评论

## 项目特定规则

### 分支命名
- 主分支: `main`
- 功能分支: `feature/<功能名>`
- 修复分支: `fix/<问题描述>`
- Claude 自动修复分支: `claude-fix-<原分支>-<run_id>`

### Commit 消息
- 使用中文描述
- 格式: `<类型>: <描述>`
  - 类型: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`
- 示例: `fix: 修复 PIPESTATUS 逻辑错误`

### 工作流触发
- **跳过审查**: PR 标题包含 `[skip review]` 或 `[wip]`
- **触发 Claude**: 评论中包含 `@claude`

## Claude Code 首选模式

### 模型选择策略
- **复杂任务**（CI 自动修复、代码重构、架构设计）: 使用 `claude-opus-4-5-20251101`
- **简单任务**（Issue 分类、重复检测）: 使用默认 Sonnet
- **自动升级**: 优先使用最新模型，如不满足需求可降级

### 工具权限配置
- **交互式响应** (`claude.yml`): WebSearch, WebFetch, GitHub 读取工具
- **PR 审查** (`pr-review.yml`): 仅 GitHub 相关工具（安全限制）
- **CI 自动修复** (`ci-failure-auto-fix.yml`): Edit, Write, Read, Bash, GitHub 工具

### Prompt 设计原则
1. **明确任务边界**: 清晰定义 Claude 需要做什么
2. **提供上下文**: 包含仓库、PR/Issue 编号、分支名等
3. **结构化输出**: 对需要解析的输出使用 JSON schema
4. **多步骤指导**: 将复杂任务分解为清晰的步骤

## 测试和验证

### Shell 脚本
- 使用 ShellCheck 进行静态分析
- 测试边界情况（空输入、无效版本号、网络失败）

### YAML 文件
- 使用 yamllint 检查格式
- 验证所有必需字段存在

### 工作流测试
- 在分支中测试新工作流
- 验证权限配置是否足够
- 检查超时设置是否合理

## 文档维护

### 何时更新文档
- ✅ 添加新工作流时更新 `docs/WORKFLOWS-GUIDE.md`
- ✅ 修改配置时更新 `README.md`
- ✅ 发现问题时更新此 `CLAUDE.md`

### 文档检查清单
- [ ] README.md 与实际代码一致
- [ ] 所有 Secret 配置有说明
- [ ] 新功能有使用示例
- [ ] 链接有效且指向正确位置

## 常见问题和解决方案

### 工作流失败
1. 检查日志中的具体错误信息
2. 验证 Secret 配置是否正确
3. 确认权限配置是否足够
4. 检查超时是否过短

### JSON 解析错误
1. 添加 `continue-on-error: true`
2. 使用 jq 验证 JSON 格式
3. 检查字段是否存在后再使用

### Git 操作失败
1. 确认 git 身份配置正确
2. 检查分支是否存在
3. 验证是否有未提交的更改

## 参考资源

- [GitHub Actions 官方文档](https://docs.github.com/en/actions)
- [Claude Code Action 文档](https://github.com/anthropics/claude-code-action)
- [Qlib 官方文档](https://qlib.readthedocs.io/)
- [Hummingbot 官方文档](https://docs.hummingbot.org/)
- [ShellCheck](https://www.shellcheck.net/)

---

**最后更新**: 2025-12-29
**维护者**: @FelixWayne0318
