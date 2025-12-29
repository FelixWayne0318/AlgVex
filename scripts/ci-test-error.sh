#!/bin/bash
# CI 失败链测试脚本 - 故意包含 ShellCheck 错误
# 此文件用于测试 CI → Test Failure Analysis → Auto Fix 链

# SC2086: 变量未加引号
echo $UNDEFINED_VAR
