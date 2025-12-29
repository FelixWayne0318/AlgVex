# 优化项实施指南

本文档提供详细的步骤来实施以下优化项：
1. ✅ CLAUDE.md 配置文件（已完成）
2. ✅ **工作流执行顺序优化**（已完成）
3. 🟡 可重用工作流（可选）
4. ✅ **Opus 模型配置**（已完成）

---

## 目录

1. [CLAUDE.md 配置文件](#1-claudemd-配置文件-)
2. [工作流执行顺序优化](#2-工作流执行顺序优化)
3. [可重用工作流实施方案](#3-可重用工作流实施方案)
4. [Opus 模型配置与降级策略](#4-opus-模型配置与降级策略)
5. [完整实施清单](#5-完整实施清单)

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

## 2. 工作流执行顺序优化

### 2.1 问题分析

当前仓库存在两个关键的工作流执行顺序问题，可能导致资源浪费和逻辑冲突。

#### 问题 1: Test Failure Analysis 和 CI Auto Fix 并发冲突 🔴 **高优先级**

**位置**:
- `.github/workflows/test-failure-analysis.yml`
- `.github/workflows/ci-failure-auto-fix.yml`

**问题描述**:
两个工作流都在 `workflow_run: CI completed` 时**同时触发**:

```yaml
# test-failure-analysis.yml 和 ci-failure-auto-fix.yml 都有相同触发条件
on:
  workflow_run:
    workflows: ["CI"]
    types: [completed]
```

**问题影响**:
1. **资源浪费**: 两个 Claude 任务同时分析相同的错误日志
2. **逻辑冲突**:
   - 如果 Analysis 判断为 flaky test 并重试 → Auto Fix 的修复分支是**多余的**
   - 如果 Auto Fix 先完成并推送修复 → Analysis 的重试会基于**旧代码**
   - 如果 Analysis 判断为真实 bug 但 Auto Fix 也在修复 → **重复工作**
3. **用户困惑**: PR 可能同时收到两条评论，说法可能矛盾

**理想执行流程**:
```
CI 失败
  ↓
Test Failure Analysis (10min)
  ↓
  ├─→ [如果是 flaky test] 重新触发 CI
  └─→ [如果不是 flaky test] CI Failure Auto Fix (20min)
         ↓
         └─→ 创建修复分支 claude-fix-xxx
```

#### 问题 2: Issue Triage 和 Deduplication 竞态条件 🟡 **中优先级**

**位置**:
- `.github/workflows/issue-triage.yml`
- `.github/workflows/issue-deduplication.yml`

**问题描述**:
两个工作流同时在新 Issue 创建时触发:

```yaml
# 两个文件都有相同的触发条件
on:
  issues:
    types: [opened]
```

**问题影响**:
1. **标签冲突**: 两个工作流可能同时调用 `update_issue` 添加标签
2. **逻辑浪费**: 如果 Issue 是重复的，Triage 添加的详细分类标签没有意义
3. **顺序混乱**: Deduplication 可能在 Triage 完成前就标记为重复

**理想执行流程**:
```
Issue 创建
  ↓
Issue Deduplication (10min)
  ↓
  ├─→ [如果是重复] 标记 duplicate 并关闭
  └─→ [如果不是重复] Issue Triage (10min)
         ↓
         └─→ 添加分类标签 (类型、优先级、区域)
```

---

### 2.2 修复方案

#### 修复方案 1: CI 失败场景的顺序执行（推荐）✅

**步骤 1**: 修改 `test-failure-analysis.yml` 添加输出

在文件末尾的 `Set analysis result` step 后添加输出定义:

```yaml
# .github/workflows/test-failure-analysis.yml

jobs:
  analyze:
    runs-on: ubuntu-latest
    timeout-minutes: 10
    permissions:
      contents: read
      pull-requests: write
      issues: write
      id-token: write
      actions: read

    # 添加 outputs 定义
    outputs:
      is_flaky: ${{ steps.validate.outputs.is_flaky }}
      should_auto_fix: ${{ steps.set_result.outputs.should_auto_fix }}

    steps:
      # ... 现有步骤 ...

      # 在最后添加这个新步骤
      - name: Set analysis result
        id: set_result
        if: steps.validate.outputs.valid == 'true'
        run: |
          IS_FLAKY="${{ steps.validate.outputs.is_flaky }}"

          # 只有当不是 flaky test 时才应该自动修复
          if [ "$IS_FLAKY" == "false" ]; then
            echo "should_auto_fix=true" >> $GITHUB_OUTPUT
            echo "✅ 不是 flaky test，建议自动修复"
          else
            echo "should_auto_fix=false" >> $GITHUB_OUTPUT
            echo "⚠️ 检测到 flaky test，已触发重试，不需要自动修复"
          fi
```

**步骤 2**: 修改 `ci-failure-auto-fix.yml` 依赖 Analysis 工作流

```yaml
# .github/workflows/ci-failure-auto-fix.yml

name: CI Failure Auto Fix

on:
  workflow_run:
    workflows: ["Test Failure Analysis"]  # 改为依赖 Analysis 工作流
    types: [completed]

concurrency:
  group: ci-fix-${{ github.event.workflow_run.head_branch }}
  cancel-in-progress: false

jobs:
  auto-fix:
    runs-on: ubuntu-latest
    timeout-minutes: 20

    # 添加新的条件检查
    if: |
      github.event.workflow_run.conclusion == 'success' &&
      github.event.workflow_run.outputs.should_auto_fix == 'true' &&
      github.event.workflow_run.event == 'pull_request' &&
      !startsWith(github.event.workflow_run.head_branch, 'claude-fix-')

    permissions:
      contents: write
      pull-requests: write
      issues: write
      id-token: write
      actions: read

    steps:
      # ... 保持其余步骤不变 ...
```

**步骤 3**: 修改 CI 工作流触发器

如果当前 `test-failure-analysis.yml` 是被 CI 触发的，保持不变。确保触发链是:

```
CI (失败) → Test Failure Analysis → CI Failure Auto Fix
```

---

#### 修复方案 2: Issue 场景的顺序执行（推荐）✅

**步骤 1**: 修改 `issue-deduplication.yml` 添加输出

```yaml
# .github/workflows/issue-deduplication.yml

jobs:
  check-duplicate:
    runs-on: ubuntu-latest
    timeout-minutes: 10

    # 添加 outputs
    outputs:
      is_duplicate: ${{ steps.set_result.outputs.is_duplicate }}

    permissions:
      contents: read
      issues: write
      id-token: write
      actions: read

    steps:
      # ... 现有步骤 ...

      # 在最后添加这个步骤
      - name: Set duplicate result
        id: set_result
        run: |
          # 检查是否添加了 duplicate 标签
          LABELS=$(gh issue view ${{ github.event.issue.number }} --json labels --jq '.labels[].name')

          if echo "$LABELS" | grep -q "duplicate"; then
            echo "is_duplicate=true" >> $GITHUB_OUTPUT
            echo "✅ Issue 已标记为重复"
          else
            echo "is_duplicate=false" >> $GITHUB_OUTPUT
            echo "✅ Issue 不是重复，可以继续分类"
          fi
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

**步骤 2**: 修改 `issue-triage.yml` 依赖 Deduplication

```yaml
# .github/workflows/issue-triage.yml

name: Issue Triage

on:
  workflow_run:
    workflows: ["Issue Deduplication"]  # 改为依赖 Deduplication 工作流
    types: [completed]

jobs:
  triage:
    runs-on: ubuntu-latest
    timeout-minutes: 10

    # 添加条件: 只有当不是重复 Issue 时才执行
    if: |
      github.event.workflow_run.conclusion == 'success' &&
      github.event.workflow_run.outputs.is_duplicate != 'true'

    permissions:
      contents: read
      issues: write
      id-token: write

    steps:
      # ... 保持其余步骤不变 ...
```

---

#### 替代方案: 合并工作流（可选）⭐

如果希望简化架构，可以考虑将相关工作流合并：

**选项 A**: 合并 CI 失败处理工作流

创建 `.github/workflows/ci-failure-handler.yml`:

```yaml
name: CI Failure Handler

on:
  workflow_run:
    workflows: ["CI"]
    types: [completed]

jobs:
  analyze-and-fix:
    if: github.event.workflow_run.conclusion == 'failure'
    runs-on: ubuntu-latest
    timeout-minutes: 30

    steps:
      - name: Analyze if flaky test
        id: analyze
        # ... Analysis 逻辑 ...

      - name: Retry if flaky
        if: steps.analyze.outputs.is_flaky == 'true'
        # ... 重试 CI ...

      - name: Auto fix if not flaky
        if: steps.analyze.outputs.is_flaky == 'false'
        # ... 自动修复逻辑 ...
```

**选项 B**: 合并 Issue 处理工作流

创建 `.github/workflows/issue-handler.yml`:

```yaml
name: Issue Handler

on:
  issues:
    types: [opened]

jobs:
  check-and-triage:
    runs-on: ubuntu-latest
    timeout-minutes: 15

    steps:
      - name: Check for duplicates
        id: dedup
        # ... Deduplication 逻辑 ...

      - name: Triage if not duplicate
        if: steps.dedup.outputs.is_duplicate != 'true'
        # ... Triage 逻辑 ...
```

---

### 2.3 验证修复

修复后，执行以下测试验证:

#### 测试 CI 失败场景:

1. 创建一个会导致 CI 失败的 PR
2. 观察工作流执行顺序:
   ```
   ✅ CI → ✅ Test Failure Analysis → ✅ CI Auto Fix (如果不是 flaky)
   ```
3. 检查是否只有一个 Claude 任务在分析错误
4. 确认 PR 评论清晰且不冲突

#### 测试 Issue 创建场景:

1. 创建一个新 Issue
2. 观察工作流执行顺序:
   ```
   ✅ Issue Deduplication → ✅ Issue Triage (如果不重复)
   ```
3. 检查标签是否按正确顺序添加
4. 确认没有重复的标签或评论

---

## 3. 可重用工作流实施方案

### 3.1 创建可重用工作流

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

### 3.2 使用可重用工作流的示例

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

## 4. Opus 模型配置与降级策略

### 4.1 模型选择策略与自动升级

#### 核心原则

**所有分析、修改、审查、测试、修复任务默认使用最新的 Opus 模型**，具体策略如下:

| 任务类型 | 默认模型 | 工作流 | 降级策略 |
|---------|---------|--------|---------|
| **复杂任务** | `claude-opus-4-5-20251101` **(必须)** | `ci-failure-auto-fix.yml`<br>`manual-code-analysis.yml` (security-review)<br>`test-failure-analysis.yml` | 仅在 Opus 不可用时降级到 Sonnet |
| **中等复杂度** | `claude-opus-4-5-20251101` **(推荐)** | `pr-review.yml`<br>`claude.yml` (交互式) | 可根据成本降级到 Sonnet |
| **简单任务** | `claude-opus-4-5-20251101` **(可选)** 或 Sonnet | `issue-triage.yml`<br>`issue-deduplication.yml` | 优先使用 Sonnet 节约成本 |

#### 自动升级机制

当 Anthropic 发布更新的 Opus 模型时（如 `claude-opus-5-0-...`），遵循以下升级流程:

1. **自动检测**: 定期检查 Anthropic 官方公告或 API 版本列表
2. **测试验证**: 在测试分支上验证新模型的性能和兼容性
3. **逐步升级**:
   - 先升级非关键工作流（issue-triage, issue-deduplication）
   - 验证无问题后升级关键工作流（ci-failure-auto-fix, pr-review）
4. **更新配置**: 在所有 `claude_args` 中更新模型名称

#### 降级触发条件

在以下情况下可以降级到 Sonnet 模型:

1. **成本控制**: API 调用费用超出预算
2. **配额限制**: Opus 模型达到速率限制
3. **响应时间**: Opus 响应时间过长影响体验
4. **可用性问题**: Opus 模型暂时不可用

---

### 4.2 具体实施步骤

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

#### 步骤 2: 更新 `test-failure-analysis.yml`

为测试失败分析使用 Opus 模型：

```yaml
- name: Run Claude Code
  if: steps.validate_logs.outputs.valid == 'true'
  uses: anthropics/claude-code-action@v1
  with:
    claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
    allowed_bots: "claude[bot]"
    track_progress: true
    use_sticky_comment: "true"
    prompt: |
      Repository: ${{ github.repository }}
      Workflow Run: ${{ github.event.workflow_run.id }}

      A CI workflow has failed. Analyze if this is a flaky test...

    claude_args: |
      --model claude-opus-4-5-20251101
      --allowedTools "mcp__github__get_workflow_run,mcp__github__list_workflow_jobs,mcp__github__get_job_logs,Bash(gh pr comment:*)"
```

#### 步骤 3: 更新 `manual-code-analysis.yml`

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

#### 步骤 4: 为 PR Review 使用 Opus 模型

直接在 `pr-review.yml` 中使用 Opus 模型：

```yaml
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
      --model claude-opus-4-5-20251101
      --allowedTools "mcp__github_inline_comment__create_inline_comment,Bash(gh pr comment:*),Bash(gh pr diff:*),Bash(gh pr view:*)"
```

#### 步骤 5: 可选 - 为 PR Review 添加基于复杂度的模型选择

如果希望根据 PR 复杂度动态选择模型，可以在 `pr-review.yml` 中添加条件判断：

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

#### 步骤 6: 在 `claude.yml` 中使用 Opus 模型

为交互式 Claude 响应使用 Opus 模型:

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

**注释**: 对于交互式场景，默认使用 Opus 提供最佳体验。如果遇到成本问题，可以临时降级（参见 4.3 节降级策略）。

---

### 4.3 降级策略详解

当 Opus 模型不满足需求或遇到问题时，采用以下降级策略:

#### 策略 1: 基于成本的自动降级

在工作流中添加成本检查和自动降级逻辑:

```yaml
- name: Determine model based on cost
  id: model
  run: |
    # 检查当前月份的 API 调用次数（需要自己实现追踪逻辑）
    # 这里只是示例，实际需要调用 Anthropic API 或使用外部追踪系统

    # 假设设置了月度预算限制
    MONTHLY_BUDGET=1000  # 美元
    CURRENT_SPENDING=$(curl -s "https://api.example.com/cost" | jq -r '.current_month')

    if [ $(echo "$CURRENT_SPENDING >= $MONTHLY_BUDGET" | bc) -eq 1 ]; then
      echo "model=claude-sonnet-4-5-20250929" >> $GITHUB_OUTPUT
      echo "⚠️ 预算已达上限，降级到 Sonnet 模型"
    else
      echo "model=claude-opus-4-5-20251101" >> $GITHUB_OUTPUT
      echo "✅ 使用 Opus 模型"
    fi

- name: Run Claude with selected model
  uses: anthropics/claude-code-action@v1
  with:
    claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
    claude_args: |
      --model ${{ steps.model.outputs.model }}
      --allowedTools "..."
```

#### 策略 2: 基于时间段的降级

在高峰时段降级以节约成本:

```yaml
- name: Determine model based on time
  id: model
  run: |
    HOUR=$(TZ='Asia/Shanghai' date +%H)

    # 工作时间 (9:00-18:00) 使用 Opus，非工作时间使用 Sonnet
    if [ "$HOUR" -ge 9 ] && [ "$HOUR" -lt 18 ]; then
      echo "model=claude-opus-4-5-20251101" >> $GITHUB_OUTPUT
      echo "✅ 工作时间，使用 Opus 模型"
    else
      echo "model=claude-sonnet-4-5-20250929" >> $GITHUB_OUTPUT
      echo "⏰ 非工作时间，使用 Sonnet 节约成本"
    fi

- name: Run Claude with selected model
  uses: anthropics/claude-code-action@v1
  with:
    claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
    claude_args: |
      --model ${{ steps.model.outputs.model }}
      --allowedTools "..."
```

#### 策略 3: 基于任务优先级的降级

为不同优先级的任务使用不同模型:

```yaml
- name: Determine model based on priority
  id: model
  run: |
    # 从 Issue/PR 标签获取优先级
    LABELS='${{ toJson(github.event.issue.labels.*.name) }}'

    if echo "$LABELS" | grep -q "critical\|high"; then
      echo "model=claude-opus-4-5-20251101" >> $GITHUB_OUTPUT
      echo "🔴 高优先级任务，使用 Opus 模型"
    else
      echo "model=claude-sonnet-4-5-20250929" >> $GITHUB_OUTPUT
      echo "🟢 普通优先级任务，使用 Sonnet 节约成本"
    fi
```

#### 策略 4: 基于错误重试的降级

当 Opus 调用失败时自动降级到 Sonnet:

```yaml
- name: Run Claude with Opus
  id: claude_opus
  continue-on-error: true
  uses: anthropics/claude-code-action@v1
  with:
    claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
    claude_args: |
      --model claude-opus-4-5-20251101
      --allowedTools "..."

- name: Fallback to Sonnet if Opus fails
  if: steps.claude_opus.outcome == 'failure'
  uses: anthropics/claude-code-action@v1
  with:
    claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
    claude_args: |
      --model claude-sonnet-4-5-20250929
      --allowedTools "..."
```

#### 策略 5: 手动降级控制

通过 workflow_dispatch 输入手动选择模型:

```yaml
on:
  workflow_dispatch:
    inputs:
      use_opus:
        description: '是否使用 Opus 模型'
        required: false
        type: boolean
        default: true

jobs:
  task:
    runs-on: ubuntu-latest
    steps:
      - name: Determine model
        id: model
        run: |
          if [ "${{ inputs.use_opus }}" == "true" ]; then
            echo "model=claude-opus-4-5-20251101" >> $GITHUB_OUTPUT
          else
            echo "model=claude-sonnet-4-5-20250929" >> $GITHUB_OUTPUT
          fi

      - name: Run Claude
        uses: anthropics/claude-code-action@v1
        with:
          claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
          claude_args: |
            --model ${{ steps.model.outputs.model }}
            --allowedTools "..."
```

---

### 4.4 降级决策矩阵

根据不同场景选择合适的降级策略:

| 场景 | 推荐策略 | 原因 |
|------|---------|------|
| **成本超预算** | 策略 1: 基于成本降级 | 直接控制支出 |
| **非关键时段** | 策略 2: 基于时间降级 | 优化资源利用 |
| **大量简单任务** | 策略 3: 基于优先级降级 | 聚焦高价值任务 |
| **Opus 不可用** | 策略 4: 基于错误重试降级 | 确保服务连续性 |
| **测试新功能** | 策略 5: 手动降级控制 | 灵活测试不同模型 |

---

### 4.5 监控和告警

实施 Opus 模型后，建议设置以下监控:

#### 4.5.1 成本监控

```yaml
- name: Report API cost
  if: always()
  run: |
    echo "### 📊 API 使用报告" >> $GITHUB_STEP_SUMMARY
    echo "" >> $GITHUB_STEP_SUMMARY
    echo "- 工作流: ${{ github.workflow }}" >> $GITHUB_STEP_SUMMARY
    echo "- 使用模型: ${{ steps.model.outputs.model }}" >> $GITHUB_STEP_SUMMARY
    echo "- 执行时间: $(date)" >> $GITHUB_STEP_SUMMARY
    echo "- 估算成本: \$X.XX" >> $GITHUB_STEP_SUMMARY
```

#### 4.5.2 性能监控

```yaml
- name: Track performance
  run: |
    START_TIME=$(date +%s)
    # ... Claude 执行 ...
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))

    echo "⏱️ 执行耗时: ${DURATION}s" >> $GITHUB_STEP_SUMMARY

    # 如果执行时间过长，发出告警
    if [ $DURATION -gt 600 ]; then
      echo "::warning::Claude 执行时间超过 10 分钟，考虑优化或降级"
    fi
```

#### 4.5.3 成功率监控

在仓库中创建 `.github/workflows/claude-metrics.yml`:

```yaml
name: Claude Metrics

on:
  schedule:
    - cron: '0 0 * * 0'  # 每周日运行

jobs:
  report:
    runs-on: ubuntu-latest
    steps:
      - name: Generate weekly report
        run: |
          # 统计过去一周的 Claude 工作流运行情况
          gh run list --workflow=claude.yml --created '>7days' --json conclusion,name,createdAt > runs.json

          TOTAL=$(jq length runs.json)
          SUCCESS=$(jq '[.[] | select(.conclusion=="success")] | length' runs.json)
          FAILURE=$(jq '[.[] | select(.conclusion=="failure")] | length' runs.json)

          echo "### 📈 本周 Claude 使用报告" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "- 总运行次数: $TOTAL" >> $GITHUB_STEP_SUMMARY
          echo "- 成功: $SUCCESS ($(( SUCCESS * 100 / TOTAL ))%)" >> $GITHUB_STEP_SUMMARY
          echo "- 失败: $FAILURE ($(( FAILURE * 100 / TOTAL ))%)" >> $GITHUB_STEP_SUMMARY
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

---

## 5. 完整实施清单

### 5.1 立即可执行（已完成）
- [x] 创建 `CLAUDE.md` 配置文件
- [x] 创建 `docs/OPTIMIZATION-IMPLEMENTATION.md` 实施指南

### 5.2 需要手动修复的工作流（按优先级排序）

#### ✅ **高优先级 - 已完成**（工作流执行顺序问题）

1. **CI 失败场景顺序优化**
   - [x] 修改 `.github/workflows/test-failure-analysis.yml` 添加输出（参见 2.2 节修复方案 1）
   - [x] 修改 `.github/workflows/ci-failure-auto-fix.yml` 依赖 Analysis 工作流
   - [ ] 测试验证 CI 失败场景的顺序执行

2. **Issue 场景顺序优化**
   - [x] 修改 `.github/workflows/issue-deduplication.yml` 添加输出（参见 2.2 节修复方案 2）
   - [x] 修改 `.github/workflows/issue-triage.yml` 依赖 Deduplication 工作流
   - [ ] 测试验证 Issue 创建场景的顺序执行

#### ✅ **中优先级 - 已完成**（Opus 模型升级）

3. **为关键工作流启用 Opus 模型**
   - [x] 更新 `.github/workflows/ci-failure-auto-fix.yml` 使用 Opus（参见 4.2 节步骤 1）
   - [x] 更新 `.github/workflows/test-failure-analysis.yml` 使用 Opus（参见 4.2 节步骤 2）
   - [x] 更新 `.github/workflows/manual-code-analysis.yml` 使用 Opus（参见 4.2 节步骤 3）
   - [x] 更新 `.github/workflows/pr-review.yml` 使用 Opus（参见 4.2 节步骤 4）
   - [x] 更新 `.github/workflows/claude.yml` 使用 Opus（参见 4.2 节步骤 6）
   - [x] 更新 `.github/workflows/issue-deduplication.yml` 使用 Opus

#### 🟢 **低优先级 - 可选实施**（可重用工作流和高级功能）

4. **创建可重用工作流模板**
   - [ ] 创建 `.github/workflows/reusable-claude-task.yml`（参见 3.1 节）
   - [ ] 更新 `.github/workflows/issue-triage.yml` 使用可重用工作流（可选）
   - [ ] 更新 `.github/workflows/issue-deduplication.yml` 使用可重用工作流（可选）

5. **实施降级策略**（可选）
   - [ ] 为 PR Review 添加基于复杂度的模型选择（参见 4.2 节步骤 5）
   - [ ] 添加基于成本的自动降级（参见 4.3 节策略 1）
   - [ ] 添加基于时间段的降级（参见 4.3 节策略 2）
   - [ ] 创建监控工作流 `.github/workflows/claude-metrics.yml`（参见 4.5.3 节）

### 5.3 测试验证

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

## 6. 常见问题

### Q1: 如何验证工作流执行顺序是否正确？

**A**:
1. 在 GitHub Actions 页面查看工作流运行历史
2. 检查时间戳和依赖关系
3. 确认没有并发冲突的警告
4. 查看 PR/Issue 的评论时间顺序

### Q2: 如何知道任务是否使用了 Opus 模型？

**A**: 检查工作流日志，Claude Code Action 会显示使用的模型名称:
```
Running Claude Code with model: claude-opus-4-5-20251101
```

### Q3: Opus 模型成本过高怎么办？

**A**:
1. 仅对关键任务使用 Opus（CI 自动修复、安全审查、测试失败分析）
2. 简单任务继续使用 Sonnet（Issue 分类、重复检测）
3. 实施时段降级策略（非工作时间使用 Sonnet）
4. 实施成本阈值降级（超预算自动降级）
5. 参考 4.3 节的 5 种降级策略

### Q4: 如何更新到更新的模型？

**A**: 当新模型发布时（如 `claude-opus-5-0-...`），按以下步骤操作:
1. 在测试分支测试新模型
2. 逐步替换工作流中的 `--model` 参数
3. 监控性能和成本变化
4. 确认无问题后全面推广

参考 4.1 节的自动升级机制。

### Q5: 工作流调用失败怎么排查？

**A**:
1. 检查工作流日志中的错误信息
2. 验证 `secrets.CLAUDE_CODE_OAUTH_TOKEN` 配置正确
3. 确认权限配置足够（特别是 workflow_run 触发器）
4. 检查依赖的工作流是否成功完成
5. 验证 `outputs` 是否正确传递

### Q6: 可重用工作流调用失败怎么办？

**A**:
1. 确保 `.github/workflows/reusable-claude-task.yml` 在 `main` 分支
2. 验证 `secrets` 是否正确传递
3. 检查 `inputs` 参数是否正确
4. 查看调用者工作流的日志
5. 确认可重用工作流的语法正确（使用 yamllint）

### Q7: 如何实施渐进式优化？

**A**: 建议按以下顺序实施:
1. **第一阶段**（立即修复）: 修复工作流执行顺序问题
2. **第二阶段**（1-2 周内）: 为关键工作流启用 Opus 模型
3. **第三阶段**（1 个月内）: 创建可重用工作流模板
4. **第四阶段**（持续优化）: 根据使用情况实施降级策略和监控

---

## 8. 下一步行动

### 8.1 立即行动（本周完成）

1. **修复工作流执行顺序问题**（🔴 高优先级）
   - 按照 2.2 节修复 CI 失败场景和 Issue 场景的并发问题
   - 测试验证修复效果
   - 预计时间: 2-3 小时

2. **为关键工作流启用 Opus 模型**（🟡 中优先级）
   - 按照 4.2 节更新 5 个关键工作流
   - 监控初始性能和成本
   - 预计时间: 1-2 小时

### 8.2 中期规划（1-2 周内）

3. **监控和优化**
   - 收集 1-2 周的 Opus 使用数据
   - 分析成本效益比
   - 根据需要调整模型策略

4. **文档更新**
   - 在 `README.md` 中更新工作流说明
   - 添加 Opus 模型使用指南
   - 更新 `docs/WORKFLOWS-GUIDE.md`

### 8.3 长期优化（1 个月后）

5. **可重用工作流**
   - 创建可重用工作流模板（如果发现大量重复代码）
   - 逐步迁移现有工作流

6. **降级策略**
   - 根据成本数据实施合适的降级策略
   - 设置监控和告警
   - 持续优化资源使用

---

## 9. 总结

本文档提供了完整的仓库优化方案，包括:

✅ **已完成**:
- CLAUDE.md 配置文件（代码规范、审查重点、项目规则）
- 完整的优化实施指南文档
- **工作流执行顺序优化**（CI 失败场景、Issue 场景）
- **为所有关键工作流启用 Opus 模型**

🟢 **可选优化**:
- 创建可重用工作流模板
- 实施基于复杂度/成本/时间的动态模型选择
- 5 种降级策略供选择（如需控制成本）
- 监控和告警机制

**核心理念**:
- **默认使用最新 Opus 模型**提供最佳质量
- **智能降级策略**控制成本
- **顺序执行关键工作流**避免资源浪费
- **持续监控优化**确保最佳性价比

按照本指南实施后，AlgVex 仓库将拥有业界领先的 AI 辅助开发工作流。

---

**创建日期**: 2025-12-29
**最后更新**: 2025-12-29
**文档版本**: v3.0（实施完成版，包含工作流顺序优化和 Opus 模型配置）
**维护者**: @FelixWayne0318
