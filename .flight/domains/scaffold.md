# Domain: Scaffold Design

Safe project scaffolding operations that preserve existing infrastructure. Governs use of scaffolding tools (create-vite, create-next-app, etc.) to prevent destructive overwrites of project infrastructure.


**Validation:** `scaffold.validate.sh` enforces NEVER/MUST rules. SHOULD rules trigger warnings. GUIDANCE is not mechanically checked.

### Suppressing Warnings



```javascript
// Legacy endpoint, scheduled for deprecation in v3
router.get('/getUser/:id', handler)  // flight:ok
```

---

## Invariants

### NEVER (validator will reject)

1. **Destructive Scaffold Flags** - Never use --overwrite, --force, or similar flags that delete existing directories. These can destroy project infrastructure (.flight/, tasks/, .git/, etc.).

   ```
   // BAD
   npx create-vite . --overwrite
   // BAD
   npx create-vite my-app --force
   // BAD
   npm init vite@latest . -- --overwrite

   // GOOD
   npx create-vite my-app
   // GOOD
   npm init vite@latest my-app
   // GOOD
   npx create-vite temp-scaffold  # then merge
   ```

### SHOULD (validator warns)

1. **Protected Directories Exist** - Protected directories (.flight/, tasks/, .git/, docs/, scripts/) should exist after any scaffold operation.


2. **Git Clean Before Scaffold** - Git working directory should be clean (committed or stashed) before running scaffold commands.

   ```
   # Ensure clean state
   git status --porcelain | grep -q . && echo "STOP: Uncommitted changes" && exit 1
   # Or stash
   git stash push -m "pre-scaffold backup"
   ```

### GUIDANCE (not mechanically checked)

1. **Protected Directories List** - The following directories MUST be preserved during any scaffold operation.


2. **Scaffold in Temp Directory Pattern** - When adding a scaffold to an existing project, use a temp directory and merge files manually.


3. **Backup Before Scaffold Pattern** - If scaffold MUST run in project root, backup protected directories first.


4. **Package.json Merge Strategy** - Never let scaffold overwrite package.json. Merge dependencies manually or with jq.


5. **Document Scaffold Source** - Document the scaffold source in project README or CHANGELOG for reproducibility and debugging.


6. **React Scaffold Commands** - React scaffolding commands. Cross-reference with react.md for component patterns after scaffolding.


7. **Next.js Scaffold Commands** - Next.js scaffolding commands. Cross-reference with nextjs.md for App Router patterns.


8. **Python Scaffold Commands** - Python scaffolding commands. Cross-reference with python.md for project structure.


9. **TypeScript/JavaScript Scaffold Commands** - TypeScript/JavaScript scaffolding commands. Cross-reference with typescript.md and javascript.md.


10. **API Service Scaffold Commands** - API service scaffolding commands. Cross-reference with api.md and webhooks.md.


11. **Testing Scaffold Commands** - Testing framework scaffolding commands. Cross-reference with testing.md.


12. **Embedded Scaffold Commands** - Embedded systems scaffolding commands. Cross-reference with rp2040-pico.md and embedded-c-p10.md.


13. **Recovery Procedures** - Recovery procedures if protected directories were deleted by a scaffold operation.


14. **Bash Script Standards** - All scaffold backup/restore scripts must follow bash.md standards.


---

## Anti-Patterns

| Anti-Pattern | Description | Fix |
|--------------|-------------|-----|
| --overwrite flag |  | Scaffold to temp, merge manually |
| --force flag |  | Scaffold to temp, merge manually |
| Scaffold in project root |  | Use temp directory pattern |
| No git commit before scaffold |  | Commit or stash first |
| Overwrite package.json |  | Merge dependencies with jq |
