# 优化项实施指南

本文档提供详细的步骤来实施以下三个优化项：
1. ✅ CLAUDE.md 配置文件（已完成）
2. 🟡 可重用工作流
3. 🟡 Opus 模型配置

---

## 1. CLAUDE.md 配置文件 ✅

**状态**: 已完成并提交到分支 `claude/issue-46-20251229-0626`

`CLAUDE.md` 文件包含：
- 代码风格规范（Shell、YAML、文档）
- 审查重点（安全性、错误处理、工作流设计）
- 项目特定规则（分支命名、Commit 消息）
- Claude Code 首选模式（模型选择、工具权限、Prompt 设计）
- 测试和验证清单
- 常见问题和解决方案

---

## 2. 可重用工作流实施方案

### 2.1 创建可重用工作流

在 `.github/workflows/` 目录创建以下文件：

#### 文件：`.github/workflows/reusable-claude-task.yml`

```yaml
name: Reusable Claude Task

on:
  workflow_call:
    inputs:
      prompt:
        required: true
        type: string
        description: "Claude 要执行的任务提示"

      allowed_tools:
        required: false
        type: string
        default: "Edit,MultiEdit,Write,Read,Glob,Grep,LS"
        description: "允许 Claude 使用的工具列表"

      timeout_minutes:
        required: false
        type: number
        default: 15
        description: "任务超时时间（分钟）"

      use_opus_model:
        required: false
        type: boolean
        default: false
        description: "是否使用 Opus 模型（复杂任务推荐）"

      checkout_ref:
        required: false
        type: string
        default: ""
        description: "要检出的分支或 ref"

      allowed_non_write_users:
        required: false
        type: string
        default: ""
        description: "允许的非写入用户列表"

      use_sticky_comment:
        required: false
        type: boolean
        default: true
        description: "是否使用粘性评论"

      track_progress:
        required: false
        type: boolean
        default: false
        description: "是否跟踪进度"

    secrets:
      CLAUDE_CODE_OAUTH_TOKEN:
        required: true
        description: "Claude Code OAuth Token"

    outputs:
      result:
        description: "Claude 执行结果"
        value: ${{ jobs.claude-task.outputs.result }}

jobs:
  claude-task:
    runs-on: ubuntu-latest
    timeout-minutes: ${{ inputs.timeout_minutes }}
    permissions:
      contents: write
      pull-requests: write
      issues: write
      id-token: write
      actions: read

    outputs:
      result: ${{ steps.claude.outputs.result }}

    steps:
      - name: Checkout repository
        uses: actions/checkout@v5
        with:
          fetch-depth: 1
          ref: ${{ inputs.checkout_ref }}

      - name: Determine model
        id: model
        run: |
          if [ "${{ inputs.use_opus_model }}" == "true" ]; then
            # 使用最新的 Opus 模型
            echo "model_arg=--model claude-opus-4-5-20251101" >> $GITHUB_OUTPUT
          else
            # 使用默认 Sonnet 模型（不指定参数）
            echo "model_arg=" >> $GITHUB_OUTPUT
          fi

      - name: Run Claude Code
        id: claude
        uses: anthropics/claude-code-action@v1
        with:
          claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
          allowed_bots: "dependabot[bot],renovate[bot],claude[bot]"
          allowed_non_write_users: ${{ inputs.allowed_non_write_users }}
          use_sticky_comment: ${{ inputs.use_sticky_comment }}
          track_progress: ${{ inputs.track_progress }}
          prompt: ${{ inputs.prompt }}
          claude_args: |
            ${{ steps.model.outputs.model_arg }}
            --allowedTools "${{ inputs.allowed_tools }}"
```

### 2.2 使用可重用工作流的示例

#### 示例 1: 更新 `issue-triage.yml` 使用可重用工作流

**原文件**（简化版）:
```yaml
jobs:
  triage:
    runs-on: ubuntu-latest
    timeout-minutes: 10
    permissions:
      contents: read
      issues: write
      id-token: write
    steps:
      - uses: actions/checkout@v5
      - uses: anthropics/claude-code-action@v1
        with:
          claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
          prompt: |
            Analyze this new issue...
```

**更新后**:
```yaml
jobs:
  triage:
    uses: ./.github/workflows/reusable-claude-task.yml
    with:
      prompt: |
        Analyze this new issue and apply appropriate labels.

        Issue: #${{ github.event.issue.number }}
        Repository: ${{ github.repository }}

        Your task:
        1. Read the issue title and body
        2. Determine the appropriate labels based on:
           - Type: bug, feature, question, documentation
           - Priority: low, medium, high, critical
           - Area: which component or area of the codebase

        Apply the labels using the GitHub API.
        If the issue is unclear, add a comment asking for clarification.

      allowed_tools: "mcp__github__get_issue,mcp__github__add_issue_comment"
      timeout_minutes: 10
      use_opus_model: false
      allowed_non_write_users: "*"

    secrets:
      CLAUDE_CODE_OAUTH_TOKEN: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
```

#### 示例 2: 使用 Opus 模型进行 CI 自动修复

**更新 `ci-failure-auto-fix.yml` 的 Claude step**:
```yaml
- name: Fix CI failures with Claude
  if: steps.validate_details.outputs.valid == 'true'
  id: claude
  uses: anthropics/claude-code-action@v1
  with:
    claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
    prompt: |
      CI workflow failed. Please analyze and fix the issues.

      Failed CI Run: ${{ steps.validate_details.outputs.run_url }}
      Failed Jobs: ${{ steps.validate_details.outputs.failed_jobs }}
      PR Number: ${{ github.event.workflow_run.pull_requests[0].number }}
      Branch Name: ${{ steps.branch.outputs.branch_name }}
      Base Branch: ${{ github.event.workflow_run.head_branch }}
      Repository: ${{ github.repository }}

      Error logs:
      ${{ steps.failure_details.outputs.result }}

      Please:
      1. Analyze the error logs
      2. Identify the root cause
      3. Make the necessary fixes
      4. Commit and push the changes
    claude_args: |
      --model claude-opus-4-5-20251101
      --allowedTools "Edit,MultiEdit,Write,Read,Glob,Grep,LS,Bash(git:*),Bash(npm:*),Bash(npx:*),Bash(gh:*)"
```

---

## 3. Opus 模型配置方案

### 3.1 模型选择策略

根据 `CLAUDE.md` 中定义的策略：

| 任务类型 | 推荐模型 | 工作流 |
|---------|---------|--------|
| **复杂任务** | `claude-opus-4-5-20251101` | `ci-failure-auto-fix.yml`<br>`manual-code-analysis.yml` (security-review) |
| **中等复杂度** | `claude-opus-4-5-20251101` (可选) | `pr-review.yml`<br>`test-failure-analysis.yml` |
| **简单任务** | 默认 Sonnet | `issue-triage.yml`<br>`issue-deduplication.yml` |
| **交互式** | 用户可选 | `claude.yml` |

### 3.2 具体实施步骤

#### 步骤 1: 更新 `ci-failure-auto-fix.yml`

在 `claude_args` 中添加模型参数：

```yaml
claude_args: |
  --model claude-opus-4-5-20251101
  --allowedTools "Edit,MultiEdit,Write,Read,Glob,Grep,LS,Bash(git:*),Bash(npm:*),Bash(npx:*),Bash(gh:*)"
```

**完整的 step**:
```yaml
- name: Fix CI failures with Claude
  if: steps.validate_details.outputs.valid == 'true'
  id: claude
  uses: anthropics/claude-code-action@v1
  with:
    claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
    prompt: |
      CI workflow failed. Please analyze and fix the issues.

      Failed CI Run: ${{ steps.validate_details.outputs.run_url }}
      Failed Jobs: ${{ steps.validate_details.outputs.failed_jobs }}
      PR Number: ${{ github.event.workflow_run.pull_requests[0].number }}
      Branch Name: ${{ steps.branch.outputs.branch_name }}
      Base Branch: ${{ github.event.workflow_run.head_branch }}
      Repository: ${{ github.repository }}

      Error logs:
      ${{ steps.failure_details.outputs.result }}

      Please:
      1. Analyze the error logs
      2. Identify the root cause
      3. Make the necessary fixes
      4. Commit and push the changes
    claude_args: |
      --model claude-opus-4-5-20251101
      --allowedTools "Edit,MultiEdit,Write,Read,Glob,Grep,LS,Bash(git:*),Bash(npm:*),Bash(npx:*),Bash(gh:*)"
```

#### 步骤 2: 更新 `manual-code-analysis.yml`

为 security-review 使用 Opus 模型：

```yaml
- name: Run Code Analysis
  uses: anthropics/claude-code-action@v1
  with:
    claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
    prompt: |
      Repository: ${{ github.repository }}
      Analysis Type: ${{ github.event.inputs.analysis_type }}

      ${{ github.event.inputs.analysis_type == 'security-review' && 'Perform a comprehensive security review of the latest commit...' || 'Summarize the latest commit...' }}
    claude_args: |
      ${{ github.event.inputs.analysis_type == 'security-review' && '--model claude-opus-4-5-20251101' || '' }}
      --allowedTools "Read,Grep,Glob,Bash(git:*)"
```

#### 步骤 3: 可选 - 为 PR Review 添加模型选择

在 `pr-review.yml` 中添加条件模型选择：

```yaml
- name: Check PR complexity
  id: complexity
  run: |
    # 获取 PR 修改的文件数和行数
    FILES_CHANGED=$(gh pr view ${{ github.event.pull_request.number }} --json files --jq '.files | length')
    ADDITIONS=$(gh pr view ${{ github.event.pull_request.number }} --json additions --jq '.additions')

    # 如果文件数 > 10 或新增行数 > 500，视为复杂 PR
    if [ "$FILES_CHANGED" -gt 10 ] || [ "$ADDITIONS" -gt 500 ]; then
      echo "use_opus=true" >> $GITHUB_OUTPUT
      echo "PR 复杂度高，使用 Opus 模型"
    else
      echo "use_opus=false" >> $GITHUB_OUTPUT
      echo "PR 复杂度正常，使用默认模型"
    fi
  env:
    GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}

- name: PR Review with Progress Tracking
  uses: anthropics/claude-code-action@v1
  with:
    claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
    allowed_bots: "claude[bot]"
    track_progress: true
    use_sticky_comment: "true"
    prompt: |
      REPO: ${{ github.repository }}
      PR NUMBER: ${{ github.event.pull_request.number }}

      Perform a comprehensive code review...

    claude_args: |
      ${{ steps.complexity.outputs.use_opus == 'true' && '--model claude-opus-4-5-20251101' || '' }}
      --allowedTools "mcp__github_inline_comment__create_inline_comment,Bash(gh pr comment:*),Bash(gh pr diff:*),Bash(gh pr view:*)"
```

#### 步骤 4: 在 `claude.yml` 中添加模型自动升级逻辑

```yaml
- name: Run Claude Code
  id: claude
  uses: anthropics/claude-code-action@v1
  with:
    claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
    use_sticky_comment: "true"
    allowed_bots: "dependabot[bot],renovate[bot],claude[bot]"
    claude_args: |
      --model claude-opus-4-5-20251101
      --allowedTools "WebSearch,WebFetch,Bash(gh search:*),mcp__github__get_issue,mcp__github__search_issues,mcp__github__list_issues,mcp__github__create_issue_comment"
```

**注释**: 对于交互式场景，默认使用 Opus 提供最佳体验。如果遇到成本问题，可以在评论中指定 `@claude --model claude-sonnet-4-5-20250929` 来降级。

---

## 4. 完整实施清单

### 4.1 立即可执行（已完成）
- [x] 创建 `CLAUDE.md` 配置文件
- [x] 创建 `docs/OPTIMIZATION-IMPLEMENTATION.md` 实施指南

### 4.2 需要手动创建的文件

**优先级：高**（推荐实施）
- [ ] 创建 `.github/workflows/reusable-claude-task.yml`
- [ ] 更新 `.github/workflows/ci-failure-auto-fix.yml` 使用 Opus 模型
- [ ] 更新 `.github/workflows/manual-code-analysis.yml` 在 security-review 时使用 Opus

**优先级：中**（可选实施）
- [ ] 更新 `.github/workflows/issue-triage.yml` 使用可重用工作流
- [ ] 更新 `.github/workflows/issue-deduplication.yml` 使用可重用工作流
- [ ] 在 `.github/workflows/pr-review.yml` 中添加基于复杂度的模型选择

**优先级：低**（根据需求实施）
- [ ] 更新 `.github/workflows/claude.yml` 默认使用 Opus
- [ ] 更新 `.github/workflows/test-failure-analysis.yml` 使用 Opus

### 4.3 测试验证

创建文件后，按以下步骤测试：

1. **验证 YAML 语法**
   ```bash
   yamllint .github/workflows/reusable-claude-task.yml
   ```

2. **测试可重用工作流**
   - 在测试分支创建一个新 Issue
   - 验证 `issue-triage.yml` 正确调用可重用工作流
   - 检查标签是否正确添加

3. **测试 Opus 模型**
   - 创建一个有意失败的 PR 触发 CI
   - 验证 `ci-failure-auto-fix.yml` 使用 Opus 模型
   - 检查修复质量是否提升

4. **监控成本**
   - 记录使用 Opus 前后的 API 调用成本
   - 评估是否需要调整模型策略

---

## 5. 模型降级策略

如果发现 Opus 成本过高或响应时间过长，可以按以下策略降级：

### 5.1 自动降级条件
```yaml
- name: Determine model with fallback
  id: model
  run: |
    # 检查是否在高峰时段（可选）
    HOUR=$(date +%H)

    # 检查 PR 复杂度
    if [ "${{ inputs.use_opus_model }}" == "true" ]; then
      # 如果在非高峰时段或复杂任务，使用 Opus
      if [ "$HOUR" -lt 8 ] || [ "$HOUR" -gt 18 ]; then
        echo "model=claude-opus-4-5-20251101" >> $GITHUB_OUTPUT
      else
        # 高峰时段降级为 Sonnet
        echo "model=claude-sonnet-4-5-20250929" >> $GITHUB_OUTPUT
      fi
    else
      echo "model=" >> $GITHUB_OUTPUT  # 使用默认
    fi
```

### 5.2 手动降级
在 `claude_args` 中指定：
```yaml
claude_args: |
  --model claude-sonnet-4-5-20250929
  --allowedTools "..."
```

---

## 6. 监控和优化

### 6.1 监控指标
- Claude API 调用次数
- 每个工作流的平均执行时间
- 成功率（任务完成 vs 失败）
- 成本（如果可用）

### 6.2 优化建议
1. **定期审查**: 每月审查一次模型使用情况
2. **成本控制**: 设置预算告警
3. **A/B 测试**: 对比 Opus vs Sonnet 的修复质量
4. **用户反馈**: 收集团队对自动化质量的反馈

---

## 7. 常见问题

### Q1: 如何知道任务是否使用了 Opus 模型？
**A**: 检查工作流日志，Claude Code Action 会显示使用的模型名称。

### Q2: 可重用工作流调用失败怎么办？
**A**:
1. 检查 `.github/workflows/reusable-claude-task.yml` 是否在 `main` 分支
2. 验证 `secrets` 是否正确传递
3. 查看调用者工作流的日志

### Q3: Opus 模型成本过高怎么办？
**A**:
1. 仅对关键任务使用 Opus（CI 自动修复、安全审查）
2. 简单任务使用 Sonnet
3. 考虑实施时段降级策略（见 5.1）

### Q4: 如何更新到更新的模型？
**A**: 当新模型发布时（如 `claude-opus-5-0-...`），在 `claude_args` 中更新模型名称：
```yaml
--model claude-opus-5-0-YYYYMMDD
```

---

## 8. 下一步

完成上述实施后，建议：

1. **文档更新**: 在 `README.md` 中添加关于可重用工作流的说明
2. **团队培训**: 确保团队了解何时使用 Opus vs Sonnet
3. **持续优化**: 根据使用情况调整策略

---

**创建日期**: 2025-12-29
**最后更新**: 2025-12-29
**维护者**: @FelixWayne0318
