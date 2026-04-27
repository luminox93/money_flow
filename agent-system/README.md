# Agent System

This directory contains a file-based multi-agent harness.

Goals:

- Define agent roles in Markdown.
- Define tasks in JSON.
- Dispatch stage packets to agent mailboxes.
- Accept agent outputs and move the run forward.
- Loop `review -> developer` until the reviewer approves.

## Layout

- `agents/`: role docs
- `tasks/`: task definitions
- `harness/`: runner script
- `runs/`: runtime state and artifacts

## Default Pipeline

1. `product-planner`
2. `designer`
3. `developer`
4. `reviewer`

The reviewer must output either:

- `Verdict: approve`
- `Verdict: revise`

If the verdict is `revise`, the harness routes the run back to `developer`.

## Commands

```powershell
./agent-system/harness/run-harness.ps1 init `
  -TaskFile ./agent-system/tasks/mvp-idea-pipeline.json `
  -RunId demo-001

./agent-system/harness/run-harness.ps1 dispatch -RunId demo-001
./agent-system/harness/run-harness.ps1 status -RunId demo-001

./agent-system/harness/run-harness.ps1 submit `
  -RunId demo-001 `
  -Agent product-planner `
  -OutputFile ./some-output.md
```

## Run Model

1. `init` creates the run folders and state file.
2. `dispatch` creates a packet for the current stage.
3. An agent reads the packet from its mailbox and writes an output file.
4. `submit` stores the output and advances the state.
5. The next stage becomes `pending`.
6. `reviewer` can either finish the run or send it back to `developer`.

## Packet Contents

Each packet includes:

- current stage
- goal
- constraints
- input files
- expected outputs
- prior artifact paths
- stage-specific result rules

## Safety Notes

- Do not call `dispatch`, `submit`, and `status` in parallel for the same `RunId`.
- The current harness uses a single state file and expects serialized control commands.

## Expansion Path

This harness is the control plane, not the model runtime.

You can later attach:

- a Codex/CUA worker that watches mailboxes and auto-submits outputs
- an OpenAI Agents SDK worker
- a LangGraph or CrewAI worker behind the same file contract
- GitHub Actions or a remote runner that executes the same loop
