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
