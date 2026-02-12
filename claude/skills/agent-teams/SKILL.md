---
name: agent-teams
description: >
  Agent Teams orchestration patterns and decision guidance.
  Use when: orchestrating multi-agent teams, deciding team vs subagent vs single session,
  spawning teammates for parallel work, multi-file refactoring, competing hypotheses,
  cross-layer coordination (frontend + backend + tests), or code review from multiple angles.
source: https://github.com/FebruaryLi/claude-agent-teams-kit
---

# Agent Teams Orchestration Guide

## Decision Matrix: When to Use What

### Single Session (default)
- Sequential file edits in one module
- Bug fix in a known location
- Simple feature addition (1-3 files)
- Code review of a single PR
- Research / exploration tasks

### Task Tool with Subagent
- One-off delegated subtask (run tests, explore codebase, generate plan)
- Task has clear input/output boundary
- No need for ongoing coordination
- Result feeds back into your main work

### Agent Team (TeamCreate + teammates)
- **Parallel independent workstreams** — e.g., frontend + backend + tests simultaneously
- **Competing hypotheses** — 2-3 agents investigate different root causes
- **Multi-module refactoring** — each agent owns a different module/layer
- **Review from multiple angles** — security reviewer + performance reviewer + correctness reviewer
- **Large feature with clear decomposition** — 4+ files across different concerns

**Rule of thumb**: If you'd naturally say "while X works on A, Y works on B", use a team. If it's "do A, then B, then C", use a single session or sequential subagents.

## Orchestration Patterns

### Pattern 1: Parallel Specialists

Best for: multi-angle review, independent investigations, parallel research.

```
Lead creates team → spawns 3 specialists → each works independently → lead synthesizes results
```

**When to use**: Tasks where multiple perspectives or independent explorations add value. Each specialist works on a different aspect with no dependencies between them.

**Team structure**:
- Lead: coordinator, creates tasks, synthesizes final output
- Specialist A: focuses on aspect 1 (e.g., security review)
- Specialist B: focuses on aspect 2 (e.g., performance review)
- Specialist C: focuses on aspect 3 (e.g., correctness review)

**Key**: Specialists don't need to communicate with each other. Lead collects all results at the end.

### Pattern 2: Pipeline with Dependencies

Best for: staged workflows where output of one phase feeds into the next.

```
Lead creates tasks with blockedBy → agents work in dependency order → downstream auto-unblocks
```

**When to use**: Multi-phase work where phases have clear handoff points. E.g., "design API schema → implement endpoints → write integration tests".

**Task dependency setup**:
1. Create all tasks upfront with `TaskCreate`
2. Use `TaskUpdate` with `addBlockedBy` to set dependencies
3. Assign agents to unblocked tasks first
4. As tasks complete, blocked tasks become available

### Pattern 3: Research-then-Implement

Best for: uncertain tasks that need investigation before coding.

```
Phase 1: spawn researcher(s) to explore → Phase 2: lead plans based on findings → Phase 3: spawn implementers
```

**When to use**: You don't know the right approach yet. Send agents to investigate (read code, search patterns, check docs), then plan implementation based on findings.

**Key**: Phase 1 agents are read-only explorers (`subagent_type=Explore`). Phase 2 is lead's planning. Phase 3 agents are full implementers (`subagent_type=code` or `general-purpose`).

### Pattern 4: Coordinated Multi-File

Best for: large refactoring or feature implementation spanning many files.

```
Lead partitions files → each agent owns a file set → agents work in parallel → lead resolves conflicts
```

**When to use**: A change touches 6+ files that can be grouped into independent sets. Each agent modifies only their assigned files, avoiding merge conflicts.

**Critical rule**: Clearly define file ownership in each task description. Two agents must NEVER edit the same file simultaneously.

## Team Size and Task Granularity

### Sweet spot: 3-4 teammates
- 2 teammates: marginal benefit over subagents
- 3-4 teammates: good parallelism, manageable coordination
- 5+ teammates: coordination overhead dominates, lead becomes bottleneck

### Task granularity: 5-6 tasks per teammate
- Each task should have a **clear deliverable** (file created, test passing, API implemented)
- Too coarse (1 giant task): loses parallelism benefit
- Too fine (20 micro-tasks): coordination overhead, excessive status checking
- Include acceptance criteria in task descriptions

### Task descriptions must include:
1. What to do (specific action)
2. Which files to touch (explicit file paths or patterns)
3. What "done" looks like (testable outcome)
4. What NOT to touch (prevent conflicts)

## Common Failure Modes and Recovery

### Lead does implementation work themselves
**Problem**: Lead writes code instead of delegating, becoming the bottleneck.
**Fix**: Lead should ONLY coordinate: create tasks, assign them, synthesize results. If you catch yourself editing files as lead, stop and delegate.

### Teammates don't mark tasks completed
**Problem**: Lead doesn't know what's done, can't unblock downstream tasks.
**Fix**: Include in task description: "When done, mark this task completed with TaskUpdate." If a teammate goes idle without completing, send them a message asking for status.

### File conflicts between teammates
**Problem**: Two agents edit the same file, causing overwrites.
**Fix**: Partition files explicitly. In task descriptions, list exact files each agent owns. If shared files are unavoidable, serialize those edits (use task dependencies).

### Orphan teammates after task completion
**Problem**: Team finishes but teammates keep running, consuming resources.
**Fix**: After all tasks complete, send `shutdown_request` to each teammate. Then call `TeamDelete` to clean up.

### Teammate stuck or spinning
**Problem**: A teammate makes no progress, repeating failed approaches.
**Fix**: Send a message with specific guidance. If still stuck, shut them down and reassign the task to a new teammate or handle it yourself.

## Prompt Templates

### Creating a team for parallel implementation
```
I need to implement [feature]. Let me create a team to parallelize the work.

The work breaks down into:
1. [Component A] — files: [list]
2. [Component B] — files: [list]
3. [Tests] — files: [list], blocked by 1 and 2

I'll create a team with 3 teammates, one per component.
```

### Spawning a teammate with clear scope
```
Task tool prompt for teammate:
"You are [role] on team [name]. Your job:
- Implement [specific thing]
- Files you own: [explicit list]
- Do NOT modify: [files owned by others]
- When done, mark task [id] as completed.
- If blocked, message the lead with what you need."
```

### Research team for investigation
```
I need to understand [problem] before deciding on an approach.
Let me spawn 2 researchers:
- Researcher 1: investigate [angle A], look at [files/patterns]
- Researcher 2: investigate [angle B], look at [files/patterns]

After both report back, I'll synthesize findings and plan implementation.
```
