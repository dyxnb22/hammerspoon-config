# Constraints

## Product Constraints

- Launcher entry stays `Cmd + Shift + Space`
- The repo must remain usable without Karabiner
- Runtime data must stay outside Git
- Module disabling must be safe and not break unrelated features

## Code Constraints

- Prefer ASCII source unless a file already requires Unicode
- Keep modules focused and small
- Do not move feature state into the repo unless it is intentionally shared configuration
- Do not hardcode new machine-specific paths outside `modules/config.lua`

## UI Constraints

- Preserve macOS/iOS visual direction
- Avoid generic utilitarian list-only UI when improving the launcher
- Keep keyboard navigation first-class
- Keep the launcher performant enough for frequent invocation

## Cursor Constraints

- Cursor rules in `.cursor/rules/` are part of the project contract
- When using Composer 2.5, Fast mode must not be used
- This is especially strict for subagent workflows
- If a task would normally be delegated with Fast mode, switch to a non-Fast mode first

## Git Constraints

- Keep the main branch clean and understandable
- Prefer focused commits with meaningful messages
- Avoid mixing runtime files into version control
