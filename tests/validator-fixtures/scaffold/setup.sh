#!/bin/bash
# Scaffold setup script with violations for testing

# N1: Destructive scaffold flags (NEVER)
# These would destroy existing project files

# Using --force with create-vite
npx create-vite my-app --template react --force

# Using --overwrite with create-next-app
npx create-next-app@latest my-nextjs-app --overwrite

# Multiple violations in one command
npm create vite@latest new-project --force --template vue
