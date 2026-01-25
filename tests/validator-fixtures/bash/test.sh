#!/usr/bin/env bash
# Bash script with violations

# N1: Unquoted variable
echo $USER_INPUT

# N2: Unquoted command substitution
FILE=$(ls *.txt)

# N4: Backticks instead of $()
files=`ls`

# N5: Single brackets
if [ "$x" = "y" ]; then
  echo "match"
fi

# N7: Bare cd without error handling
cd /some/directory
echo "now here"

# N9: eval usage
eval "$user_command"

# N10: Hardcoded /tmp
echo "data" > /tmp/myfile.txt
