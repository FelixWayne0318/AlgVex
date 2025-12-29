#!/bin/bash
# 测试脚本 - 用于触发 CI 失败链测试
# 此脚本故意包含 ShellCheck 错误

# SC2086: Double quote to prevent globbing and word splitting
echo $undefined_variable

# SC2046: Quote this to prevent word splitting
files=$(ls *.txt)
echo $files

# SC2034: unused variable
unused_var="test"
