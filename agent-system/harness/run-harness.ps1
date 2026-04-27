param(
    [Parameter(Position = 0)]
    [ValidateSet("init", "dispatch", "submit", "status", "loop")]
    [string]$Command,

    [string]$TaskFile,
    [string]$RunId,
    [string]$Agent,
    [string]$OutputFile,
    [int]$PollSeconds = 5,
    [int]$MaxTicks = 20
)

$ErrorActionPreference = "Stop"

function Get-Root {
    Split-Path -Parent $PSScriptRoot
}

function Get-RunsRoot {
    Join-Path (Get-Root) "runs"
}

function Get-RunPath([string]$Id) {
    Join-Path (Get-RunsRoot) $Id
}

function Get-StatePath([string]$Id) {
    Join-Path (Get-RunPath $Id) "state.json"
}

function Ensure-RunId {
    if ([string]::IsNullOrWhiteSpace($RunId)) {
        throw "RunId is required."
    }
}

function Read-JsonFile([string]$Path) {
    Get-Content $Path -Raw | ConvertFrom-Json
}

function Write-JsonFile([string]$Path, $Object) {
    $Object | ConvertTo-Json -Depth 20 | Set-Content -Path $Path -Encoding utf8
}

function Get-Stage($State, [int]$Index) {
    $State.stages[$Index]
}

function New-RunStructure([string]$Id) {
    $runPath = Get-RunPath $Id
    $null = New-Item -ItemType Directory -Force -Path $runPath
    $null = New-Item -ItemType Directory -Force -Path (Join-Path $runPath "mailboxes")
    $null = New-Item -ItemType Directory -Force -Path (Join-Path $runPath "outputs")
    $null = New-Item -ItemType Directory -Force -Path (Join-Path $runPath "packets")
}

function Initialize-Run {
    if ([string]::IsNullOrWhiteSpace($TaskFile)) {
        throw "TaskFile is required for init."
    }

    if ([string]::IsNullOrWhiteSpace($RunId)) {
        $script:RunId = "run-" + (Get-Date -Format "yyyyMMdd-HHmmss")
    }

    $task = Read-JsonFile $TaskFile
    New-RunStructure $RunId

    foreach ($stage in $task.stages) {
        $null = New-Item -ItemType Directory -Force -Path (Join-Path (Join-Path (Get-RunPath $RunId) "mailboxes") $stage.agent)
    }

    $stages = @()
    for ($i = 0; $i -lt $task.stages.Count; $i++) {
        $stages += [pscustomobject]@{
            name = $task.stages[$i].name
            agent = $task.stages[$i].agent
            status = if ($i -eq 0) { "pending" } else { "blocked" }
            packetFile = ""
            outputFile = ""
        }
    }

    $state = [pscustomobject]@{
        runId = $RunId
        taskFile = (Resolve-Path $TaskFile).Path
        taskName = $task.name
        goal = $task.goal
        constraints = $task.constraints
        inputs = $task.inputs
        expectedOutputs = $task.expectedOutputs
        status = "ready"
        currentStageIndex = 0
        stages = $stages
        createdAt = (Get-Date).ToString("o")
        updatedAt = (Get-Date).ToString("o")
        history = @()
    }

    Write-JsonFile (Get-StatePath $RunId) $state
    Write-Host "Initialized run: $RunId"
}

function New-PacketContent($State, $Stage) {
@"
# Agent Packet

Run ID: $($State.runId)
Task: $($State.taskName)
Stage: $($Stage.name)
Agent: $($Stage.agent)

## Goal
$($State.goal)

## Constraints
$([string]::Join("`n", ($State.constraints | ForEach-Object { "- $_" })))

## Inputs
$([string]::Join("`n", ($State.inputs | ForEach-Object { "- $_" })))

## Expected Outputs
$([string]::Join("`n", ($State.expectedOutputs | ForEach-Object { "- $_" })))

## Required Result
에이전트는 자신의 역할 문서에 따라 이 단계 결과를 작성해야 한다.
"@
}

function Dispatch-Stage {
    Ensure-RunId
    $statePath = Get-StatePath $RunId
    $state = Read-JsonFile $statePath

    if ($state.status -eq "completed") {
        Write-Host "Run already completed."
        return
    }

    $stage = Get-Stage $state $state.currentStageIndex
    if ($stage.status -eq "assigned") {
        Write-Host "Current stage already assigned to $($stage.agent)."
        return
    }

    $packetName = ("{0:D2}-{1}-{2}.md" -f ($state.currentStageIndex + 1), $stage.name, $stage.agent)
    $packetPath = Join-Path (Join-Path (Get-RunPath $RunId) "packets") $packetName
    $mailboxPath = Join-Path (Join-Path (Join-Path (Get-RunPath $RunId) "mailboxes") $stage.agent) $packetName

    New-PacketContent $state $stage | Set-Content -Path $packetPath -Encoding utf8
    Copy-Item $packetPath $mailboxPath -Force

    $stage.status = "assigned"
    $stage.packetFile = $packetPath
    $state.status = "waiting_for_agent"
    $state.updatedAt = (Get-Date).ToString("o")
    $state.history += [pscustomobject]@{
        at = (Get-Date).ToString("o")
        action = "dispatch"
        stage = $stage.name
        agent = $stage.agent
        packetFile = $packetPath
    }

    Write-JsonFile $statePath $state
    Write-Host "Dispatched $($stage.name) to $($stage.agent)."
}

function Submit-Stage {
    Ensure-RunId
    if ([string]::IsNullOrWhiteSpace($Agent)) {
        throw "Agent is required for submit."
    }
    if ([string]::IsNullOrWhiteSpace($OutputFile)) {
        throw "OutputFile is required for submit."
    }

    $statePath = Get-StatePath $RunId
    $state = Read-JsonFile $statePath
    $stage = Get-Stage $state $state.currentStageIndex

    if ($stage.agent -ne $Agent) {
        throw "Current stage agent is $($stage.agent), not $Agent."
    }

    $destName = ("{0:D2}-{1}-{2}-output.md" -f ($state.currentStageIndex + 1), $stage.name, $stage.agent)
    $destPath = Join-Path (Join-Path (Get-RunPath $RunId) "outputs") $destName
    Copy-Item $OutputFile $destPath -Force

    $stage.status = "completed"
    $stage.outputFile = $destPath

    $state.history += [pscustomobject]@{
        at = (Get-Date).ToString("o")
        action = "submit"
        stage = $stage.name
        agent = $stage.agent
        outputFile = $destPath
    }

    if ($state.currentStageIndex -lt ($state.stages.Count - 1)) {
        $state.currentStageIndex += 1
        $nextStage = Get-Stage $state $state.currentStageIndex
        if ($nextStage.status -eq "blocked") {
            $nextStage.status = "pending"
        }
        $state.status = "ready"
    }
    else {
        $state.status = "completed"
    }

    $state.updatedAt = (Get-Date).ToString("o")
    Write-JsonFile $statePath $state
    Write-Host "Accepted output from $Agent."
}

function Show-Status {
    Ensure-RunId
    $state = Read-JsonFile (Get-StatePath $RunId)
    $state
}

function Start-Loop {
    Ensure-RunId
    for ($i = 0; $i -lt $MaxTicks; $i++) {
        $state = Read-JsonFile (Get-StatePath $RunId)
        if ($state.status -eq "completed") {
            Write-Host "Run completed."
            break
        }

        if ($state.status -eq "ready") {
            Dispatch-Stage
        }
        else {
            Write-Host "Tick $($i + 1): waiting for agent output."
        }

        Start-Sleep -Seconds $PollSeconds
    }
}

switch ($Command) {
    "init" { Initialize-Run }
    "dispatch" { Dispatch-Stage }
    "submit" { Submit-Stage }
    "status" { Show-Status }
    "loop" { Start-Loop }
    default { throw "Unknown command." }
}
