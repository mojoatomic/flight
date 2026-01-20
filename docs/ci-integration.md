# Flight-Lint CI/CD Integration Guide

Integrate flight-lint into your continuous integration pipeline to catch code quality issues early.

## Quick Start

```bash
# Install flight-lint
npm install flight-lint --save-dev

# Run with auto-discovery
npx flight-lint --auto

# Run with specific rules file
npx flight-lint .flight/domains/javascript.rules.json
```

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | No violations found |
| 1 | Violations found (NEVER or MUST severity) |
| 2 | Configuration error (invalid rules file, etc.) |

## Output Formats

### Pretty (default)
Human-readable colored output for terminal display.

```bash
npx flight-lint --auto --format pretty
```

### JSON
Machine-readable JSON output for custom processing.

```bash
npx flight-lint --auto --format json
```

### SARIF
Static Analysis Results Interchange Format for integration with GitHub Code Scanning and other tools.

```bash
npx flight-lint --auto --format sarif > results.sarif
```

---

## GitHub Actions

### Basic Workflow

```yaml
# .github/workflows/flight-lint.yml
name: Flight Lint

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Run flight-lint
        run: npx flight-lint --auto
```

### With SARIF Upload to GitHub Code Scanning

```yaml
# .github/workflows/flight-lint-sarif.yml
name: Flight Lint (SARIF)

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  lint:
    runs-on: ubuntu-latest
    permissions:
      security-events: write
      contents: read

    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Run flight-lint
        run: npx flight-lint --auto --format sarif > flight-lint-results.sarif
        continue-on-error: true

      - name: Upload SARIF to GitHub
        uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: flight-lint-results.sarif
          category: flight-lint
```

### Combined with Other Linters

```yaml
# .github/workflows/lint.yml
name: Lint

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Run ESLint
        run: npm run lint

      - name: Run TypeScript check
        run: npm run typecheck

      - name: Run flight-lint
        run: npx flight-lint --auto
```

---

## GitLab CI

### Basic Pipeline

```yaml
# .gitlab-ci.yml
stages:
  - lint

flight-lint:
  stage: lint
  image: node:20
  cache:
    paths:
      - node_modules/
  before_script:
    - npm ci
  script:
    - npx flight-lint --auto
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
```

### With Artifacts

```yaml
# .gitlab-ci.yml
flight-lint:
  stage: lint
  image: node:20
  cache:
    paths:
      - node_modules/
  before_script:
    - npm ci
  script:
    - npx flight-lint --auto --format json > flight-lint-results.json
  artifacts:
    when: always
    paths:
      - flight-lint-results.json
    reports:
      codequality: flight-lint-results.json
```

---

## CircleCI

```yaml
# .circleci/config.yml
version: 2.1

jobs:
  lint:
    docker:
      - image: cimg/node:20.0
    steps:
      - checkout
      - restore_cache:
          keys:
            - v1-deps-{{ checksum "package-lock.json" }}
      - run:
          name: Install dependencies
          command: npm ci
      - save_cache:
          key: v1-deps-{{ checksum "package-lock.json" }}
          paths:
            - node_modules
      - run:
          name: Run flight-lint
          command: npx flight-lint --auto

workflows:
  version: 2
  build-and-test:
    jobs:
      - lint
```

---

## Jenkins

```groovy
// Jenkinsfile
pipeline {
    agent {
        docker {
            image 'node:20'
        }
    }

    stages {
        stage('Install') {
            steps {
                sh 'npm ci'
            }
        }

        stage('Lint') {
            steps {
                sh 'npx flight-lint --auto'
            }
        }
    }

    post {
        always {
            cleanWs()
        }
    }
}
```

---

## Generic CI Script

For any CI system, use this pattern:

```bash
#!/bin/bash
set -euo pipefail

# Install dependencies
npm ci

# Run flight-lint
# Exit code 0: no violations
# Exit code 1: violations found
# Exit code 2: configuration error
npx flight-lint --auto

# Optionally, save results
# npx flight-lint --auto --format json > lint-results.json
# npx flight-lint --auto --format sarif > lint-results.sarif
```

---

## npm Scripts

Add these scripts to your `package.json`:

```json
{
  "scripts": {
    "lint:flight": "flight-lint --auto",
    "lint:flight:json": "flight-lint --auto --format json",
    "lint:flight:sarif": "flight-lint --auto --format sarif",
    "preflight": "npm run lint && npm run lint:flight"
  }
}
```

Then in CI:

```bash
npm run lint:flight
```

---

## Severity Filtering

Control which violations fail the build:

```bash
# Only fail on NEVER and MUST violations (default)
npx flight-lint --auto --severity MUST

# Also fail on SHOULD violations
npx flight-lint --auto --severity SHOULD

# Fail on all violations including GUIDANCE
npx flight-lint --auto --severity GUIDANCE
```

---

## Troubleshooting

### No rules files found

```
No .rules.json files found in .flight/domains/
```

Ensure your `.rules.json` files are in `.flight/domains/` directory.

### Query syntax error

```
Error: Invalid query syntax for rule N1: ...
```

Check your tree-sitter query syntax in the rules file.

### Permission denied

```
Error: EACCES: permission denied
```

Ensure the CI runner has read access to all source files.

---

## Best Practices

1. **Run early**: Add flight-lint to the beginning of your CI pipeline
2. **Use SARIF**: Enable GitHub Code Scanning for inline PR comments
3. **Cache dependencies**: Speed up CI by caching node_modules
4. **Combine linters**: Run flight-lint alongside ESLint and TypeScript
5. **Pin versions**: Use exact versions of flight-lint for reproducible builds
