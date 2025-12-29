#!/bin/bash
# CI 全流程测试文件 - 包含故意的 ShellCheck 错误
# 此文件用于测试自动修复流程，测试完成后应删除
#
# 预期触发的 ShellCheck 错误:
# - SC2086: Double quote to prevent globbing and word splitting
# - SC2034: Variable appears unused
#
# 测试流程:
# 1. CI shellcheck job 检测到错误并失败
# 2. Test Failure Analysis 判断非 flaky test
# 3. Auto Fix CI Failures 自动修复这些错误
# 4. 修复 PR 被创建并触发 PR Review
# 5. 人工审查合并后系统恢复正常

set -e

# SC2086: Double quote to prevent globbing and word splitting
# 故意不加引号以触发此警告
files=$1
ls $files

# SC2034: unused_var appears unused
# 故意定义未使用的变量
unused_var="this variable is intentionally unused for testing"

# 正常代码
echo "Test script executed successfully"
