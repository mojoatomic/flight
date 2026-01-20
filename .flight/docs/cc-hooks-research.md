# Claude Code Hooks Research

> Research conducted: 2026-01-20
> Source: https://code.claude.com/docs/en/hooks (official documentation)

## Executive Summary

Claude Code hooks provide an event-driven system for intercepting and controlling agent behavior. Hooks can validate outputs, inject context, and block actions or task completion. This makes them ideal for implementing a **self-validating agent pattern** where code changes are automatically validated and the agent self-corrects on failures.

---

## 1. What Hook Events Exist?

Claude Code provides **10 hook events** across different lifecycle stages:

| Event | Timing | Use Case |
|-------|--------|----------|
| `PreToolUse` | Before tool executes | Validate parameters, block dangerous operations |
| `PostToolUse` | After tool completes | Validate output, run linting, trigger follow-up |
| `PermissionRequest` | Before permission prompt shown | Auto-approve trusted patterns |
| `Notification` | When notification shown | Logging, external alerting |
| `UserPromptSubmit` | User sends message | Pre-process input, add context |
| `Stop` | Agent attempts to complete | **Block completion until validation passes** |
| `SubagentStop` | Subagent attempts to complete | Same as Stop, for Task tool agents |
| `PreCompact` | Before context compaction | Preserve critical information |
| `SessionStart` | Session begins | Setup, logging, environment prep |
| `SessionEnd` | Session ends | Cleanup, reporting, metrics |

### Key Events for Self-Validating Pattern

1. **`PostToolUse`** - Run validation after Write/Edit tools
2. **`Stop`** - Prevent task completion if validation fails
3. **`SubagentStop`** - Same for subagents using Task tool

---

## 2. What Input Does Each Hook Receive?

Hooks receive context via **environment variables** and **stdin**.

### Environment Variables (All Hooks)

```bash
CLAUDE_CODE_HOOK_EVENT_NAME    # e.g., "PostToolUse"
CLAUDE_CODE_SESSION_ID         # Unique session identifier
CLAUDE_CODE_WORKING_DIRECTORY  # Current working directory
CLAUDE_CODE_TRANSCRIPT_PATH    # Path to conversation transcript
```

### Stdin Input by Event

#### PreToolUse / PostToolUse
```json
{
  "tool_name": "Write",
  "tool_input": {
    "file_path": "/path/to/file.ts",
    "content": "..."
  },
  "tool_output": "File written successfully"  // PostToolUse only
}
```

#### Stop / SubagentStop
```json
{
  "stop_reason": "end_turn",
  "final_response": "I've completed the implementation..."
}
```

#### PermissionRequest
```json
{
  "tool_name": "Bash",
  "tool_input": {
    "command": "npm install express"
  }
}
```

#### UserPromptSubmit
```json
{
  "user_prompt": "Fix the bug in auth.ts"
}
```

---

## 3. What Output Can Hooks Produce?

Hooks output **JSON to stdout** with the following schema:

```json
{
  "decision": "approve" | "block" | "skip",
  "reason": "Human-readable explanation",
  "additionalContext": "Context injected into agent's conversation",
  "hookSpecificOutput": {
    // Event-specific fields
  }
}
```

### Decision Values

| Decision | Effect |
|----------|--------|
| `approve` | Allow action to proceed (or continue for Stop) |
| `block` | Prevent action, show reason to agent |
| `skip` | Skip this hook (use next matcher or default) |

### Output by Event Type

#### PreToolUse
```json
{
  "decision": "block",
  "reason": "Cannot write to node_modules",
  "additionalContext": "Files in node_modules are managed by npm"
}
```

#### PostToolUse
```json
{
  "decision": "approve",
  "additionalContext": "Validation passed: 0 errors, 2 warnings"
}
```

#### Stop (Critical for Self-Validation)
```json
{
  "decision": "block",
  "reason": "Validation failed: 3 NEVER violations found",
  "additionalContext": "Run `flight-lint --auto` to see violations:\n- N1: eval() usage at line 45\n- N2: any type at line 67\n- N3: console.log at line 89"
}
```

---

## 4. Can Hooks Inject Feedback Into Agent Context?

**Yes.** The `additionalContext` field injects text directly into the agent's conversation context.

### How It Works

1. Hook runs and outputs JSON with `additionalContext`
2. Claude Code captures this field
3. Content appears as a system message in the conversation
4. Agent sees this context and can act on it

### Example: Validation Feedback

```json
{
  "decision": "approve",
  "additionalContext": "Flight Validation Results:\n✅ TypeScript: 0 errors\n⚠️ Lint: 2 warnings (unused imports)\n✅ Tests: All passing"
}
```

The agent will see this feedback and can choose to address the warnings.

### Example: Forcing Self-Correction

```json
{
  "decision": "block",
  "reason": "Code has validation errors",
  "additionalContext": "MUST FIX before completing:\n1. Type error in auth.ts:45 - 'string' is not assignable to 'number'\n2. Lint error in utils.ts:12 - Missing return type"
}
```

When `decision: "block"` is used on a Stop event, the agent **cannot complete the task** until the issues are resolved.

---

## 5. Can Hooks Control Task Completion?

**Yes.** The `Stop` and `SubagentStop` events specifically control whether the agent can finish.

### Stop Event Behavior

When Claude attempts to complete a task (end_turn):

1. Stop hooks run with the final response
2. If any hook returns `decision: "block"`:
   - Task completion is prevented
   - The `reason` is shown to the agent
   - The `additionalContext` is injected
   - Agent must address the issue and try again

### Self-Validating Pattern Implementation

```bash
#!/bin/bash
# .claude/hooks/stop-validator.sh

# Run Flight validation
output=$(flight-lint --auto --format json 2>&1)
exit_code=$?

if [ $exit_code -ne 0 ]; then
  # Extract violation count and details
  violations=$(echo "$output" | jq -r '.summary.total')
  details=$(echo "$output" | jq -r '.results[] | "- \(.ruleId): \(.message) at \(.filePath):\(.line)"')

  cat << EOF
{
  "decision": "block",
  "reason": "Flight validation failed: $violations violations",
  "additionalContext": "You MUST fix these violations before completing:\n$details\n\nRun the fixes and try again."
}
EOF
else
  cat << EOF
{
  "decision": "approve",
  "additionalContext": "✅ Flight validation passed. All constraints satisfied."
}
EOF
fi
```

---

## 6. JSON Schema for Hook Configuration

Hooks are configured in `settings.json` files at three levels:
- **User**: `~/.claude/settings.json`
- **Project**: `.claude/settings.json` (in repo root)
- **Local**: `.claude/settings.local.json` (gitignored)

### Configuration Schema

```json
{
  "hooks": {
    "<EventName>": [
      {
        "matcher": "<glob pattern or regex>",
        "command": ["<executable>", "<args>..."],
        "timeout": 30000,
        "environment": {
          "CUSTOM_VAR": "value"
        }
      }
    ]
  }
}
```

### Field Definitions

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `matcher` | string | No | Filter when hook runs (glob for files, regex for tools) |
| `command` | string[] | Yes | Command to execute (first element is executable) |
| `timeout` | number | No | Milliseconds before timeout (default: 60000) |
| `environment` | object | No | Additional environment variables |

### Matcher Examples

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "command": ["./scripts/validate.sh"]
      }
    ],
    "Stop": [
      {
        "command": ["./scripts/final-validation.sh"]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Bash",
        "command": ["./scripts/bash-guard.sh"]
      }
    ]
  }
}
```

### Full Example: Self-Validating Configuration

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit|MultiEdit",
        "command": ["./flight-lint/bin/flight-lint", "--auto", "--format", "json"],
        "timeout": 30000
      }
    ],
    "Stop": [
      {
        "command": ["./.flight/hooks/stop-validator.sh"],
        "timeout": 60000
      }
    ],
    "SubagentStop": [
      {
        "command": ["./.flight/hooks/stop-validator.sh"],
        "timeout": 60000
      }
    ]
  }
}
```

---

## 7. Implementation Recommendations

### Self-Validating Agent Pattern

```
┌─────────────────────────────────────────────────────────┐
│                    Claude Code Agent                     │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  1. Agent writes/edits code                             │
│           ↓                                             │
│  2. PostToolUse hook runs flight-lint                   │
│           ↓                                             │
│  3. Validation results injected via additionalContext   │
│           ↓                                             │
│  4. Agent sees results, may self-correct                │
│           ↓                                             │
│  5. Agent attempts to complete task                     │
│           ↓                                             │
│  6. Stop hook runs final validation                     │
│           ↓                                             │
│  ┌─────────────────┐    ┌─────────────────────┐        │
│  │ Validation PASS │    │ Validation FAIL     │        │
│  │ decision:approve│    │ decision:block      │        │
│  │ Task completes  │    │ Agent must fix      │        │
│  └─────────────────┘    └─────────────────────┘        │
│                                ↓                        │
│                         Loop back to step 1             │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Recommended Hook Scripts

#### 1. PostToolUse Validator (Immediate Feedback)
```bash
#!/bin/bash
# .flight/hooks/post-tool-validate.sh

# Only validate on Write/Edit operations
input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name')

if [[ "$tool_name" != "Write" && "$tool_name" != "Edit" && "$tool_name" != "MultiEdit" ]]; then
  echo '{"decision": "approve"}'
  exit 0
fi

# Run quick validation
output=$(./flight-lint/bin/flight-lint --auto --format json 2>&1)
violations=$(echo "$output" | jq -r '.summary.total // 0')

if [ "$violations" -gt 0 ]; then
  details=$(echo "$output" | jq -r '.results[:5][] | "• \(.ruleId): \(.message)"' | head -5)
  cat << EOF
{
  "decision": "approve",
  "additionalContext": "⚠️ Flight detected $violations violation(s):\n$details\n\nConsider fixing these before completing."
}
EOF
else
  echo '{"decision": "approve", "additionalContext": "✅ Flight validation passed"}'
fi
```

#### 2. Stop Validator (Enforcement Gate)
```bash
#!/bin/bash
# .flight/hooks/stop-validate.sh

# Run comprehensive validation
output=$(./flight-lint/bin/flight-lint --auto --format json 2>&1)
exit_code=$?
violations=$(echo "$output" | jq -r '.summary.total // 0')

# Count by severity
never_count=$(echo "$output" | jq -r '[.results[] | select(.severity == "NEVER")] | length')
must_count=$(echo "$output" | jq -r '[.results[] | select(.severity == "MUST")] | length')

# Block on NEVER or MUST violations (critical)
if [ "$never_count" -gt 0 ] || [ "$must_count" -gt 0 ]; then
  details=$(echo "$output" | jq -r '.results[] | select(.severity == "NEVER" or .severity == "MUST") | "• [\(.severity)] \(.ruleId): \(.message) at \(.filePath):\(.line)"')
  cat << EOF
{
  "decision": "block",
  "reason": "Critical validation failures: $never_count NEVER, $must_count MUST violations",
  "additionalContext": "You MUST fix these violations before completing:\n\n$details\n\nThese are non-negotiable constraints from the domain files."
}
EOF
  exit 0
fi

# Allow completion with warnings
if [ "$violations" -gt 0 ]; then
  cat << EOF
{
  "decision": "approve",
  "additionalContext": "⚠️ Completed with $violations warning(s). Consider addressing in follow-up."
}
EOF
else
  cat << EOF
{
  "decision": "approve",
  "additionalContext": "✅ All Flight validations passed. Code meets all domain constraints."
}
EOF
fi
```

---

## 8. Key Findings Summary

| Question | Answer |
|----------|--------|
| Can hooks run validation? | ✅ Yes, via `PostToolUse` after Write/Edit |
| Can hooks inject feedback? | ✅ Yes, via `additionalContext` field |
| Can hooks block completion? | ✅ Yes, via `Stop` event with `decision: "block"` |
| Can hooks force self-correction? | ✅ Yes, block + context creates correction loop |
| Is configuration per-project? | ✅ Yes, `.claude/settings.json` in repo |
| Can different events have different hooks? | ✅ Yes, configure per event type |

---

## 9. Next Steps

1. **Create hook scripts** in `.flight/hooks/`
2. **Configure hooks** in `.claude/settings.json`
3. **Test the pattern** with intentional violations
4. **Document the workflow** in FLIGHT.md
5. **Consider severity thresholds** (block on NEVER/MUST, warn on SHOULD)

---

## References

- Official Documentation: https://code.claude.com/docs/en/hooks
- Hook Events Reference: https://code.claude.com/docs/en/hooks#hook-events
- Configuration Guide: https://code.claude.com/docs/en/hooks#configuration
