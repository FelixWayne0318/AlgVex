# CI 全流程测试方案

## 概述

本文档描述了 AlgVex 项目 CI 自动化全流程的测试方案，用于验证"自动审查 → 自动检测 → 自动修复"的完整链路。

## 测试目标

通过故意引入一个错误，验证以下工作流能否按预期顺序执行：

1. **CI 工作流** (`ci.yml`) - 检测到错误并失败
2. **Test Failure Analysis** (`test-failure-analysis.yml`) - 分析失败原因，判断非 flaky test
3. **Auto Fix CI Failures** (`ci-failure-auto-fix.yml`) - 自动修复错误
4. **PR Review** (`pr-review.yml`) - 审查修复 PR

## 工作流触发链

```
┌─────────────────────────────────────────────────────────────────┐
│  CI 全流程链路                                                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. CI (ci.yml)                                                  │
│     ├─ 触发条件: push/PR to main                                 │
│     ├─ 检查项目:                                                  │
│     │   • build: README.md 存在性检查                            │
│     │   • shellcheck: Shell 脚本语法检查                          │
│     │   • yaml-lint: YAML 文件格式检查                            │
│     └─ 失败时 → 触发 Test Failure Analysis                        │
│                                                                  │
│  2. Test Failure Analysis (test-failure-analysis.yml)           │
│     ├─ 触发条件: CI 工作流完成且 conclusion == 'failure'          │
│     ├─ 分析内容:                                                  │
│     │   • 是否为 flaky test（超时、网络错误等）                     │
│     │   • 置信度评估                                              │
│     └─ 若非 flaky (should_auto_fix=true) → 触发 Auto Fix         │
│                                                                  │
│  3. Auto Fix CI Failures (ci-failure-auto-fix.yml)              │
│     ├─ 触发条件: Test Failure Analysis 成功完成                   │
│     │           + 日志中包含 should_auto_fix=true                 │
│     │           + 分支名不以 claude-fix- 开头                     │
│     ├─ 动作:                                                     │
│     │   • 创建修复分支 claude-fix-<原分支>-<run_id>               │
│     │   • Claude 分析错误日志并修复                               │
│     │   • 推送修复并创建 PR                                       │
│     └─ 输出: 修复 PR                                             │
│                                                                  │
│  4. PR Review (pr-review.yml)                                   │
│     ├─ 触发条件: PR opened/synchronize/ready_for_review          │
│     │           + 标题不包含 [skip review] 或 [wip]               │
│     └─ 动作: Claude 自动代码审查                                  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## 测试方案

### 方案 A: Shell 脚本语法错误（推荐）

**原理**: CI 工作流中的 `shellcheck` job 会检查 `scripts/*.sh` 文件的语法。

**步骤**:

1. 在 `scripts/` 目录下创建一个包含 ShellCheck 错误的脚本
2. 提交并创建 PR 到 main 分支
3. 观察工作流执行

**故意错误示例** (`scripts/test-error.sh`):

```bash
#!/bin/bash
# 故意包含 ShellCheck 会检测到的错误

# SC2086: 变量未加引号
files=$1
ls $files

# SC2034: 未使用的变量
unused_var="test"

# SC2046: 命令替换未加引号
files=$(find . -name "*.txt")
rm $files
```

**预期结果**:
- ShellCheck 检测到 SC2086、SC2034、SC2046 错误
- CI 失败 → Analysis 判断非 flaky → Auto Fix 创建修复 PR

### 方案 B: YAML 格式错误

**原理**: CI 工作流中的 `yaml-lint` job 会检查 YAML 文件格式。

**注意**: 由于 GitHub App 权限限制，无法直接修改 `.github/workflows/` 目录中的文件。但可以创建其他 YAML 文件来触发 yamllint 错误。

### 方案 C: README 缺失（不推荐）

**原理**: 删除 README.md 会导致 CI build job 失败。

**风险**: 会影响项目的基本文档，不推荐用于测试。

## 本次测试执行

### 选择方案 A

创建文件: `scripts/test-error.sh`

```bash
#!/bin/bash
# CI 全流程测试文件 - 包含故意的 ShellCheck 错误
# 此文件用于测试自动修复流程，测试完成后应删除

set -e

# SC2086: Double quote to prevent globbing and word splitting
# 故意不加引号以触发此警告
files=$1
ls $files

# SC2034: unused_var appears unused
# 故意定义未使用的变量
unused_var="this variable is intentionally unused"

# 正常代码
echo "Test script executed"
```

### 预期流程

```
阶段 1: 错误检测与分析
├─ T+0min:  提交 PR，CI 开始运行
├─ T+2min:  CI shellcheck job 失败
├─ T+3min:  Test Failure Analysis 自动触发
└─ T+8min:  Analysis 完成，输出 should_auto_fix=true

阶段 2: 自动修复
├─ T+9min:  Auto Fix CI Failures 自动触发
├─ T+15min: Claude 分析并修复错误
├─ T+16min: 创建修复 PR (claude-fix-* 分支)
└─ T+17min: 修复 PR 触发 PR Review

阶段 3: 验证与合并
├─ T+20min: 修复 PR 的 CI 运行并通过
├─ T+22min: PR Review 完成
├─ T+??min: 【人工操作】审查并合并修复 PR
└─ T+??min: 原始分支 CI 重新运行

阶段 4: 系统恢复
└─ 原始 PR 的 CI 全部通过 → 系统恢复正常 ✅
```

### 验证检查点

| 阶段 | 检查点 | 预期结果 | 验证方法 |
|------|--------|----------|----------|
| 1 | CI 失败 | shellcheck job 失败 | 查看 Actions 页面 |
| 1 | Analysis 触发 | workflow_run 事件触发 | 查看 Actions 页面 |
| 1 | Analysis 判断 | `should_auto_fix=true` | 查看 Analysis 日志 |
| 2 | Auto Fix 触发 | 检测到需要修复 | 查看 Auto Fix 日志 |
| 2 | 修复分支创建 | `claude-fix-*` 分支存在 | 查看仓库分支列表 |
| 2 | 修复 PR 创建 | PR 标题包含 "Auto-fix" | 查看 PR 列表 |
| 3 | 修复 PR CI | 所有 job 成功 | 查看修复 PR 的 CI 状态 |
| 3 | PR Review | 自动审查评论 | 查看 PR 评论 |
| 4 | **系统恢复** | 原始 PR CI 全部通过 | 合并后查看原始 PR |

### 完整闭环验证步骤

测试完成的标志是**系统完全恢复正常**，需要执行以下验证：

1. **验证修复 PR 的 CI 通过**
   ```
   修复 PR → CI 运行 → 所有 job 通过 ✅
   ```

2. **人工审查修复内容**
   - 检查 Claude 的修复是否正确
   - 确认没有引入新问题
   - 批准并合并 PR

3. **验证原始分支恢复**
   ```
   合并修复 PR
       ↓
   原始分支获得修复代码
       ↓
   原始 PR 的 CI 重新运行
       ↓
   所有 job 通过 → 系统恢复正常 ✅
   ```

4. **最终确认**
   - 原始 PR 可以正常合并
   - 没有遗留的 claude-fix-* 分支
   - 测试错误文件已删除

## 测试后清理

测试完成后需要：

1. 删除测试脚本 `scripts/test-error.sh`
2. 关闭/合并相关 PR
3. 删除 claude-fix-* 分支

## 故障排除

### Auto Fix 未触发

检查:
- Test Failure Analysis 日志是否包含 `should_auto_fix=true`
- 分支名是否以 `claude-fix-` 开头（会被跳过）
- `CLAUDE_CODE_OAUTH_TOKEN` secret 是否配置

### 修复不正确

检查:
- Claude 的 prompt 是否包含足够的错误信息
- 允许的工具列表是否包含必要的编辑工具

### PR Review 未运行

检查:
- PR 标题是否包含 `[skip review]` 或 `[wip]`
- PR 是否为 draft 状态

---

**创建日期**: 2025-12-29
**关联 Issue**: #58
**状态**: 待执行
