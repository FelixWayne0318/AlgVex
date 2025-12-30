#!/bin/bash
# 这个脚本故意包含 ShellCheck 会检测到的问题

# SC2086: 变量未加引号
files=$(ls *.txt)
echo $files

# SC2034: 未使用的变量
unused_var="this is never used"

# SC2046: 命令替换未加引号
echo $(cat file.txt)

echo "测试脚本完成"
