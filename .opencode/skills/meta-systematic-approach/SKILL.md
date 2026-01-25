---
name: meta-systematic-approach
description: Use when analyzing problems, evaluating options, or making architectural decisions. Provides structured methodology for thorough analysis.
---

# Systematic Approach

## Core Principle

**Understand before acting.** Gather information, analyze options, then decide.

## When This Applies

- Evaluating implementation options
- Debugging errors
- Making architectural decisions
- Planning multi-step tasks

## The Process

### 1. Understand the Goal

- What is the user actually trying to achieve?
- What constraints exist (repo patterns, security, etc.)?
- Is the request clear enough to act on?

If unclear: **Ask ONE clarifying question at a time.**

### 2. Gather Information

- What does nixpkgs provide? (options, defaults)
- What patterns does this repo use? (load `fact-nix`)
- Are there similar implementations to reference?

### 3. Identify Options

Present 2-3 approaches with trade-offs:

```markdown
## Options

**Option A: [Name]**
- Pros: ...
- Cons: ...
- Best when: ...

**Option B: [Name]**
- Pros: ...
- Cons: ...
- Best when: ...

**Recommendation:** Option A because [reason matching repo patterns]
```

### 4. Decide and Decompose

- Choose option based on repo conventions
- Break into concrete tasks
- Identify dependencies between tasks

### 5. Execute Incrementally

- One step at a time
- Verify each step before proceeding
- Adjust plan if issues arise

## Debugging Methodology

When stuck:

1. **Read the error** — What does it actually say?
2. **Form hypothesis** — What's the most likely cause?
3. **Test ONE change** — Verify hypothesis
4. **Repeat** — If wrong, try next hypothesis

**NEVER:** Make multiple changes at once. You won't know what fixed it.

## Anti-Patterns

| Bad | Better |
|-----|--------|
| Jump straight to coding | Research options first |
| Make assumptions | Ask clarifying questions |
| Change multiple things | One change, verify, repeat |
| Guess at solutions | Read error messages carefully |

## Integration with Planner

When invoked as subagent, return structured analysis:

```markdown
## Analysis: [Topic]

### Understanding
[What the request means]

### Options Identified
[2-3 options with trade-offs]

### Recommendation
[Which option and why, considering repo patterns]

### Open Questions
[Any clarifications needed from user]
```
