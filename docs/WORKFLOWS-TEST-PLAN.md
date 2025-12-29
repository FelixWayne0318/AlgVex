# 工作流全面测试方案

本文档提供 AlgVex 仓库中所有 GitHub Actions 工作流的完整测试方案，包括测试用例、执行步骤和 PR 引导说明。

## 目录

- [一、文档与代码一致性检查](#一文档与代码一致性检查)
- [二、测试方案总览](#二测试方案总览)
- [三、工作流独立测试](#三工作流独立测试)
  - [测试 1: Claude 交互式响应 (claude.yml)](#测试-1-claude-交互式响应-claudeyml)
  - [测试 2: PR 自动审查 (pr-review.yml)](#测试-2-pr-自动审查-pr-reviewyml)
  - [测试 3: Issue 重复检测 (issue-deduplication.yml)](#测试-3-issue-重复检测-issue-deduplicationyml)
  - [测试 4: Issue 自动分类 (issue-triage.yml)](#测试-4-issue-自动分类-issue-triageyml)
  - [测试 5: CI 持续集成 (ci.yml)](#测试-5-ci-持续集成-ciyml)
  - [测试 6: 测试失败分析 (test-failure-analysis.yml)](#测试-6-测试失败分析-test-failure-analysisyml)
  - [测试 7: CI 失败自动修复 (ci-failure-auto-fix.yml)](#测试-7-ci-失败自动修复-ci-failure-auto-fixyml)
  - [测试 8: 手动代码分析 (manual-code-analysis.yml)](#测试-8-手动代码分析-manual-code-analysisyml)
- [四、链式工作流测试](#四链式工作流测试)
- [五、边界条件测试](#五边界条件测试)
- [六、PR 执行引导](#六pr-执行引导)
- [七、测试检查清单](#七测试检查清单)
- [八、故障排除](#八故障排除)

---

## 一、文档与代码一致性检查

已完成所有 8 个工作流文件的逐行分析，与 `docs/WORKFLOWS-GUIDE.md` 文档对比结果：

| 工作流 | 文档描述 | 实际代码 | 一致性 |
|--------|----------|----------|--------|
| `claude.yml` | ✅ 触发条件、权限、工具配置 | ✅ 匹配 | ✅ |
| `pr-review.yml` | ✅ 触发条件、审查重点 | ✅ 匹配 | ✅ |
| `issue-deduplication.yml` | ✅ 触发条件、输出变量 | ✅ 匹配 | ✅ |
| `issue-triage.yml` | ✅ 依赖关系、执行流程 | ✅ 匹配 | ✅ |
| `ci.yml` | ✅ 基础检查功能 | ✅ 匹配（含 shellcheck 和 yamllint） | ✅ |
| `test-failure-analysis.yml` | ✅ 检测标准、JSON schema | ✅ 匹配 | ✅ |
| `ci-failure-auto-fix.yml` | ✅ 触发条件、修复流程 | ✅ 匹配 | ✅ |
| `manual-code-analysis.yml` | ✅ 触发方式、分析类型 | ✅ 匹配 | ✅ |

---

## 二、测试方案总览

### 测试策略

```
阶段 1: 基础功能测试
    ↓
阶段 2: Issue 链测试
    ↓
阶段 3: CI 链测试
    ↓
阶段 4: 边界条件测试
```

### 工作流测试矩阵

| 工作流 | 测试场景数 | 预计耗时 | 优先级 |
|--------|------------|----------|--------|
| claude.yml | 3 | 10 min | 高 |
| pr-review.yml | 6 | 15 min | 高 |
| issue-deduplication.yml | 4 | 10 min | 中 |
| issue-triage.yml | 6 | 10 min | 中 |
| ci.yml | 6 | 10 min | 高 |
| test-failure-analysis.yml | 5 | 15 min | 中 |
| ci-failure-auto-fix.yml | 5 | 20 min | 中 |
| manual-code-analysis.yml | 2 | 10 min | 低 |

---

## 三、工作流独立测试

### 测试 1: Claude 交互式响应 (claude.yml)

#### 场景 A: Issue 中 @claude

| 步骤 | 操作 | 预期结果 | 验证方法 |
|------|------|----------|----------|
| 1 | 创建新 Issue，body 包含 `@claude 请介绍一下这个项目` | 工作流触发 | Actions 页面显示运行 |
| 2 | 等待 Claude 响应 | Claude 在 Issue 中回复 | Issue 评论区有回复 |
| 3 | 验证 sticky comment | 使用固定评论 | 只有一条 Claude 评论 |
| 4 | 验证 timeout | 运行时间 < 30 分钟 | 查看 Actions 耗时 |

**测试命令**：
```bash
# 使用 GitHub CLI 创建测试 Issue
gh issue create --title "测试 Claude 响应" --body "@claude 请简单介绍这个项目的工作流配置"
```

#### 场景 B: PR 评论中 @claude

| 步骤 | 操作 | 预期结果 | 验证方法 |
|------|------|----------|----------|
| 1 | 在 Open PR 评论中写 `@claude 这个 PR 做了什么？` | 工作流触发 | Actions 页面显示运行 |
| 2 | 验证推送行为 | 推送到现有 PR 分支 | 无新分支创建 |

**测试命令**：
```bash
# 在现有 PR 中添加评论
gh pr comment <PR_NUMBER> --body "@claude 请解释这个 PR 的主要变更"
```

#### 场景 C: PR Review 中 @claude

| 步骤 | 操作 | 预期结果 | 验证方法 |
|------|------|----------|----------|
| 1 | 提交 PR Review，body 包含 `@claude 请解释这段代码` | 工作流触发 | Actions 页面显示运行 |

---

### 测试 2: PR 自动审查 (pr-review.yml)

| 步骤 | 操作 | 预期结果 | 验证方法 |
|------|------|----------|----------|
| 1 | 创建新 PR（正常标题） | 自动触发代码审查 | Actions 页面显示运行 |
| 2 | 验证审查内容 | Claude 提供代码质量、安全性、性能等反馈 | PR 评论区有审查评论 |
| 3 | 创建 PR 标题含 `[skip review]` | 工作流不触发 | Actions 页面无新运行 |
| 4 | 创建 PR 标题含 `[wip]` | 工作流不触发 | Actions 页面无新运行 |
| 5 | 更新现有 PR（push 新 commit） | 重新触发审查 | Actions 页面显示新运行 |
| 6 | 验证 timeout | 运行时间 < 15 分钟 | 查看 Actions 耗时 |

**测试命令**：
```bash
# 创建测试分支和 PR
git checkout -b test/pr-review-test
echo "# Test" >> test-file.md
git add test-file.md
git commit -m "test: 测试 PR 审查"
git push origin test/pr-review-test
gh pr create --title "测试 PR 审查" --body "这是一个测试 PR"

# 测试跳过审查
gh pr create --title "[skip review] 测试跳过" --body "不应触发审查"
gh pr create --title "[wip] 工作进行中" --body "不应触发审查"
```

---

### 测试 3: Issue 重复检测 (issue-deduplication.yml)

| 步骤 | 操作 | 预期结果 | 验证方法 |
|------|------|----------|----------|
| 1 | 创建与现有 Issue 明显重复的 Issue | 添加 `duplicate` 标签 | Issue 标签列表 |
| 2 | 验证评论 | 添加评论链接原 Issue | Issue 评论区 |
| 3 | 创建全新不重复的 Issue | 不添加标签、不添加评论 | Issue 无额外操作 |
| 4 | 验证输出变量 | 日志包含 `issue_number=X` 和 `is_duplicate=true/false` | Actions 日志 |

**测试命令**：
```bash
# 先创建一个原始 Issue
gh issue create --title "如何配置 CI 工作流" --body "请问如何设置持续集成？"

# 等待几分钟后，创建重复 Issue
gh issue create --title "CI 配置问题" --body "我想知道怎么配置 CI"

# 创建不重复的 Issue
gh issue create --title "新功能请求：添加 Docker 支持" --body "希望项目支持 Docker 部署"
```

---

### 测试 4: Issue 自动分类 (issue-triage.yml)

| 步骤 | 操作 | 预期结果 | 验证方法 |
|------|------|----------|----------|
| 1 | 等待 Issue Deduplication 完成 | Triage 工作流自动触发 | Actions 页面显示运行 |
| 2 | 验证链式触发 | 仅当 `is_duplicate=false` 时继续 | Actions 日志 |
| 3 | 创建明显是 bug 的 Issue | 添加 `bug` 标签 | Issue 标签列表 |
| 4 | 创建功能请求 Issue | 添加 `feature` 标签 | Issue 标签列表 |
| 5 | 创建问题咨询 Issue | 添加 `question` 标签 | Issue 标签列表 |
| 6 | 验证 timeout | 运行时间 < 10 分钟 | 查看 Actions 耗时 |

**测试命令**：
```bash
# 测试 bug 分类
gh issue create --title "构建失败：缺少依赖" --body "运行 npm install 时报错：Error: Cannot find module 'xxx'"

# 测试 feature 分类
gh issue create --title "功能请求：支持多语言" --body "希望能添加英文文档支持"

# 测试 question 分类
gh issue create --title "如何使用 Qlib？" --body "请问 Qlib 模块怎么使用？"
```

---

### 测试 5: CI 持续集成 (ci.yml)

| 步骤 | 操作 | 预期结果 | 验证方法 |
|------|------|----------|----------|
| 1 | Push 到 `main` 分支 | 触发 CI | Actions 页面显示运行 |
| 2 | 创建 PR 目标为 `main` | 触发 CI | Actions 页面显示运行 |
| 3 | 验证 README 检查 | `README.md` 存在时通过 | CI 状态为绿色 |
| 4 | 验证 ShellCheck | 检查 `scripts/*.sh` 文件 | 日志显示 shellcheck 输出 |
| 5 | 验证 yamllint | 检查工作流 YAML 文件格式 | 日志显示 yamllint 输出 |
| 6 | 故意引入 YAML 错误 | CI 失败 | CI 状态为红色 |

**测试命令**：
```bash
# 创建测试分支引入错误
git checkout -b test/ci-failure
# 编辑一个 YAML 文件引入语法错误
git add .
git commit -m "test: 测试 CI 失败检测"
git push origin test/ci-failure
gh pr create --title "测试 CI 失败" --body "故意引入错误测试 CI"
```

---

### 测试 6: 测试失败分析 (test-failure-analysis.yml)

| 步骤 | 操作 | 预期结果 | 验证方法 |
|------|------|----------|----------|
| 1 | 让 CI 失败 | 触发 Test Failure Analysis | Actions 页面显示运行 |
| 2 | 验证 Flaky 检测 | Claude 分析是否为 flaky test | 日志包含分析结果 |
| 3 | 验证 JSON 输出 | 包含 `is_flaky`, `confidence`, `summary` | 日志包含 JSON |
| 4 | 验证自动重试 | 若 flaky 且 confidence >= 0.7，自动重试 | 新的 CI 运行 |
| 5 | 验证输出变量 | `should_auto_fix=true/false` 供下游使用 | Actions 日志 |

---

### 测试 7: CI 失败自动修复 (ci-failure-auto-fix.yml)

| 步骤 | 操作 | 预期结果 | 验证方法 |
|------|------|----------|----------|
| 1 | 等待 Test Failure Analysis 完成 | 自动触发（若 should_auto_fix=true） | Actions 页面显示运行 |
| 2 | 验证分支创建 | 创建 `claude-fix-{branch}-{run_id}` 分支 | 分支列表 |
| 3 | 验证循环防护 | `claude-fix-*` 分支不触发此工作流 | 无新运行 |
| 4 | 验证修复内容 | Claude 分析错误并尝试修复 | 新分支有提交 |
| 5 | 验证 timeout | 运行时间 < 20 分钟 | 查看 Actions 耗时 |

---

### 测试 8: 手动代码分析 (manual-code-analysis.yml)

#### 场景 A: 总结提交

| 步骤 | 操作 | 预期结果 | 验证方法 |
|------|------|----------|----------|
| 1 | 进入 Actions → Manual Code Analysis → Run workflow | 工作流运行界面 | Actions 页面 |
| 2 | 选择 `summarize-commit` | Claude 总结最新提交内容 | 输出包含提交摘要 |

#### 场景 B: 安全审查

| 步骤 | 操作 | 预期结果 | 验证方法 |
|------|------|----------|----------|
| 1 | 选择 `security-review` | Claude 进行安全漏洞审查 | 输出包含安全分析 |
| 2 | 验证 timeout | 运行时间 < 15 分钟 | 查看 Actions 耗时 |

**测试步骤**：
1. 访问 https://github.com/FelixWayne0318/AlgVex/actions
2. 选择 "Manual Code Analysis" 工作流
3. 点击 "Run workflow" 按钮
4. 选择分析类型并运行

---

## 四、链式工作流测试

### 测试 A: Issue 处理链

```
新 Issue 创建
    ↓
issue-deduplication.yml (检测重复)
    ↓ is_duplicate=false
issue-triage.yml (自动分类)
```

| 步骤 | 操作 | 验证点 | 预期结果 |
|------|------|--------|----------|
| 1 | 创建新 Issue: "项目如何安装？" | Deduplication 触发 | Actions 显示运行 |
| 2 | 等待 Deduplication 完成 | 日志含 `is_duplicate=false` | 无 duplicate 标签 |
| 3 | 验证 Triage 触发 | Triage 工作流运行 | 自动添加 `question` 标签 |

**测试命令**：
```bash
gh issue create --title "项目如何安装？" --body "请问项目的安装步骤是什么？"
# 等待约 2-3 分钟观察 Actions 运行情况
```

---

### 测试 B: CI 失败处理链

```
CI 失败
    ↓
test-failure-analysis.yml (分析原因)
    ↓ should_auto_fix=true
ci-failure-auto-fix.yml (自动修复)
```

| 步骤 | 操作 | 验证点 | 预期结果 |
|------|------|--------|----------|
| 1 | 创建故意导致 CI 失败的 PR | CI 工作流失败 | CI 状态红色 |
| 2 | 等待 Test Failure Analysis | 分析完成，输出 JSON | 日志包含分析结果 |
| 3 | 若非 flaky | ci-failure-auto-fix 触发 | Actions 显示新运行 |
| 4 | 验证修复分支 | 创建 `claude-fix-*` 分支 | 分支列表有新分支 |

**测试命令**：
```bash
# 创建带有 YAML 语法错误的分支
git checkout -b test/ci-chain-test
cat > test-error.yml << 'EOF'
# 故意的语法错误
name: Test
on: [push]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Test
      run: echo "missing dash"  # 错误：缺少 -
EOF
git add test-error.yml
git commit -m "test: 测试 CI 链式处理"
git push origin test/ci-chain-test
gh pr create --title "测试 CI 链式处理" --body "测试 CI 失败 → 分析 → 自动修复链"
```

---

## 五、边界条件测试

| 测试项 | 操作 | 预期结果 | 验证方法 |
|--------|------|----------|----------|
| 并发控制 | 同一 PR 快速连续触发多次 | 不会互相冲突，按序执行 | 查看 Actions 运行状态 |
| 超时处理 | 复杂任务超过 timeout | 工作流正常终止 | Actions 显示超时 |
| 权限验证 | 无 CLAUDE_CODE_OAUTH_TOKEN | 工作流失败并报错 | 错误日志 |
| Bot 过滤 | dependabot 创建的 PR | claude.yml 允许响应 | Claude 正常响应 |
| 空输入处理 | Issue body 为空 | Claude 正常处理或提示需要更多信息 | 查看 Claude 回复 |

---

## 六、PR 执行引导

### 阶段 1: 基础功能测试（推荐先执行）

#### 步骤 1.1: 验证 Claude 连接
```bash
# 手动触发 Manual Code Analysis 验证 Claude 连接
# 访问: Actions → Manual Code Analysis → Run workflow → summarize-commit
```

#### 步骤 1.2: 测试 Claude 响应
```bash
# 在当前 PR 评论中测试
# 评论内容: @claude 请确认工作流测试方案已正确写入
```

#### 步骤 1.3: 创建测试 PR 验证 PR 审查
```bash
git checkout -b test/pr-review-basic
echo "# 测试文件" > test-pr-review.md
git add test-pr-review.md
git commit -m "test: 测试 PR 审查功能"
git push origin test/pr-review-basic
gh pr create --title "测试 PR 审查" --body "验证 pr-review.yml 功能"
```

### 阶段 2: Issue 链测试

#### 步骤 2.1: 测试重复检测
```bash
# 创建原始 Issue
gh issue create --title "如何配置工作流" --body "请问工作流如何配置？"

# 等待 2 分钟后创建重复 Issue
gh issue create --title "工作流配置问题" --body "我想了解工作流的配置方法"
```

#### 步骤 2.2: 测试自动分类
```bash
# 创建 bug 类型 Issue
gh issue create --title "Bug: CI 运行失败" --body "运行 CI 时出现错误..."

# 创建 feature 类型 Issue
gh issue create --title "Feature: 支持 Python 3.12" --body "希望添加 Python 3.12 支持"
```

### 阶段 3: CI 链测试

#### 步骤 3.1: 触发 CI 失败
```bash
git checkout -b test/ci-failure-chain
# 创建一个会导致 CI 失败的文件（如 YAML 语法错误）
cat > .github/workflows/test-error.yml << 'EOF'
name: Test Error
on: push
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Test
      run: echo "error"  # 缺少 -
EOF
git add .github/workflows/test-error.yml
git commit -m "test: 触发 CI 失败"
git push origin test/ci-failure-chain
gh pr create --title "测试 CI 失败链" --body "测试 CI → 分析 → 修复"
```

#### 步骤 3.2: 观察链式处理
```bash
# 在 Actions 页面观察以下顺序：
# 1. CI 工作流失败
# 2. Test Failure Analysis 触发
# 3. CI Failure Auto Fix 触发（如果 should_auto_fix=true）
# 4. 检查是否创建了 claude-fix-* 分支
```

### 阶段 4: 边界测试

#### 步骤 4.1: 测试跳过审查
```bash
gh pr create --title "[skip review] 测试跳过审查" --body "验证跳过逻辑"
gh pr create --title "[wip] 工作进行中" --body "验证 WIP 跳过"
```

#### 步骤 4.2: 测试空输入
```bash
gh issue create --title "空内容测试" --body ""
```

---

## 七、测试检查清单

在 PR 中按以下清单逐项验证：

```markdown
## 工作流测试检查清单

### Phase 1: 基础功能 ✓
- [ ] Manual Code Analysis 正常运行
- [ ] Issue 评论 @claude 响应
- [ ] PR 评论 @claude 响应
- [ ] PR Review @claude 响应

### Phase 2: PR 审查 ✓
- [ ] PR opened 触发审查
- [ ] PR synchronize 触发审查
- [ ] [skip review] 跳过
- [ ] [wip] 跳过
- [ ] 审查结果包含 5 个关注点

### Phase 3: Issue 处理链 ✓
- [ ] 重复 Issue 检测成功
- [ ] 非重复 Issue 正常处理
- [ ] is_duplicate 变量输出正确
- [ ] issue_number 变量输出正确
- [ ] Triage 链式触发成功
- [ ] bug/feature/question 正确分类

### Phase 4: CI 处理链 ✓
- [ ] push 到 main 触发 CI
- [ ] PR 目标 main 触发 CI
- [ ] README 检查通过
- [ ] ShellCheck 通过
- [ ] yamllint 通过
- [ ] CI 失败时 Test Failure Analysis 触发
- [ ] 正确识别 flaky test
- [ ] 输出有效 JSON
- [ ] 高置信度时自动重试
- [ ] CI Failure Auto Fix 链式触发
- [ ] 创建 claude-fix-* 分支
- [ ] 循环防护生效

### Phase 5: 边界测试 ✓
- [ ] 并发控制正常
- [ ] 超时正常终止
- [ ] 空输入正常处理
```

---

## 八、故障排除

### 问题 1: 工作流未触发

**检查项**：
- [ ] 工作流文件是否在 `main` 分支的 `.github/workflows/` 目录
- [ ] YAML 语法是否正确（使用 `yamllint` 检查）
- [ ] 触发条件是否满足
- [ ] 是否有足够的权限

**解决方案**：
```bash
# 检查工作流文件语法
yamllint .github/workflows/

# 查看最近的 Actions 运行
gh run list --limit 10
```

### 问题 2: Claude 无响应

**检查项**：
- [ ] `CLAUDE_CODE_OAUTH_TOKEN` Secret 是否配置
- [ ] Token 是否有效
- [ ] 工作流是否超时

**解决方案**：
1. 在仓库 Settings → Secrets 中检查 Token
2. 查看 Actions 日志中的具体错误

### 问题 3: 链式工作流未触发

**检查项**：
- [ ] 上游工作流是否成功完成
- [ ] 输出变量是否正确设置
- [ ] `workflow_run` 事件配置是否正确

**解决方案**：
```bash
# 查看工作流运行详情
gh run view <RUN_ID> --log
```

### 问题 4: CI 自动修复循环

**检查项**：
- [ ] 分支名是否以 `claude-fix-` 开头
- [ ] 条件 `!startsWith(github.event.workflow_run.head_branch, 'claude-fix-')` 是否生效

---

## 相关链接

- [工作流详细文档](./WORKFLOWS-GUIDE.md)
- [Claude Code Action 官方文档](https://github.com/anthropics/claude-code-action)
- [GitHub Actions 文档](https://docs.github.com/actions)
- [项目主页](../README.md)

---

**最后更新**: 2025-12-29
**维护者**: @FelixWayne0318
