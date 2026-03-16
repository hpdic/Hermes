#!/bin/bash

# ==============================================================================
# @file count_lines.sh
# @author Dongfang Zhao (dzhao@uw.edu)
#
# @brief Automated line count utility for Hermes source code statistics.
#
# @details
# This script recursively traverses the Hermes project directory to calculate 
# total lines of code across different languages. It excludes transient 
# build artifacts, third-party libraries, and experimental patches to ensure 
# the report reflects the core implementation. The categories are aligned 
# with the system description in the Hermes technical manuscript.
# ==============================================================================

set -e

echo "===== Hermes Source Code Statistics (March 2026) ====="

# Root directory of the project
ROOT="$HOME/hpdic/Hermes"

# Directories to exclude from the count
EXCLUDE_DIRS="build|.vscode|external|patch|tmp|paper"

# Helper function for line counting
count_ext() {
  local pattern=$1
  find "$ROOT" -type f \
    | grep -vE "/($EXCLUDE_DIRS)/" \
    | grep -E "$pattern" \
    | xargs cat 2>/dev/null | wc -l
}

# 1. C++ Core Logic (Implementation and Headers)
cpp_pattern='\.cpp$|\.cc$|\.cxx$|\.hpp$|\.h$|\.hh$|\.hxx$'
cpp_lines=$(count_ext "$cpp_pattern")

# 2. Python Visualization and Analysis Scripts
py_lines=$(count_ext '\.py$')

# 3. Build Configuration (CMake)
cmake_pattern='CMakeLists\.txt$|\.cmake$'
cmake_lines=$(count_ext "$cmake_pattern")

# 4. Automation and Deployment Shell Scripts
sh_lines=$(count_ext '\.sh$')

# 5. Documentation (Markdown)
md_lines=$(count_ext '\.md$')

# Calculate aggregated totals
core_logic=$cpp_lines
auxiliary=$((py_lines + cmake_lines + sh_lines))
grand_total=$((core_logic + auxiliary + md_lines))

# Professional Output Formatting
printf "\n%-25s: %6d lines\n" "C++ (Core Logic)" $cpp_lines
printf "%-25s: %6d lines\n" "Python (Analysis)" $py_lines
printf "%-25s: %6d lines\n" "Shell (Orchestration)" $sh_lines
printf "%-25s: %6d lines\n" "CMake (Build System)" $cmake_lines
printf "%-25s: %6d lines\n" "Markdown (Docs)" $md_lines
echo "------------------------------------------------------"
printf "%-25s: %6d lines\n" "Total Codebase Size" $grand_total