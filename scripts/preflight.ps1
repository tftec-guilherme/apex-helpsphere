#!/usr/bin/env pwsh
<#
.SYNOPSIS
    HelpSphere — Pre-flight check antes de 'azd up'.

.DESCRIPTION
    Valida 8 pré-condições no ambiente Windows / PowerShell:
      1. PowerShell 7+
      2. Long Path Win habilitado (HKLM:\...\FileSystem\LongPathsEnabled = 1)
      3. Docker Desktop rodando
      4. Azure CLI logado (`az login`)
      5. azd CLI logado (`azd auth login`)
      6. ODBC Driver 18 for SQL Server instalado
      7. Python 3.13.x disponível
      8. Subscription Azure ativa (informativo)

    Exit code:
      0 — todos os checks PASS
      1 — pelo menos um check FAIL (com instrução de correção)

.EXAMPLE
    pwsh -File scripts/preflight.ps1
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Continue'
$failed = $false

Write-Host ""
Write-Host "HelpSphere Pre-flight Check" -ForegroundColor Cyan
Write-Host "===========================" -ForegroundColor Cyan
Write-Host ""

# --- 1. PowerShell 7+ ---
Write-Host "[1/8] PowerShell version..." -NoNewline
if ($PSVersionTable.PSVersion.Major -ge 7) {
    Write-Host " OK ($($PSVersionTable.PSVersion))" -ForegroundColor Green
} else {
    Write-Host " FALHA ($($PSVersionTable.PSVersion))" -ForegroundColor Red
    Write-Host "  Instale PowerShell 7+: winget install --id Microsoft.PowerShell -e" -ForegroundColor Yellow
    $failed = $true
}

# --- 2. Long Path habilitado ---
Write-Host "[2/8] Long Path habilitado (Windows)..." -NoNewline
try {
    $longPath = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' `
        -Name 'LongPathsEnabled' -ErrorAction Stop
    if ($longPath.LongPathsEnabled -eq 1) {
        Write-Host " OK" -ForegroundColor Green
    } else {
        Write-Host " FALHA (LongPathsEnabled=$($longPath.LongPathsEnabled))" -ForegroundColor Red
        Write-Host "  Habilite Long Path (Admin):" -ForegroundColor Yellow
        Write-Host "    Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' -Name LongPathsEnabled -Value 1" -ForegroundColor Yellow
        Write-Host "  Ou via gpedit.msc -> Computer Config -> Admin Templates -> System -> Filesystem -> 'Enable Win32 long paths'" -ForegroundColor Yellow
        $failed = $true
    }
} catch {
    Write-Host " FALHA (chave nao encontrada)" -ForegroundColor Red
    Write-Host "  Habilite Long Path (Admin):" -ForegroundColor Yellow
    Write-Host "    New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' -Name LongPathsEnabled -Value 1 -PropertyType DWord -Force" -ForegroundColor Yellow
    $failed = $true
}

# --- 3. Docker rodando ---
Write-Host "[3/8] Docker Desktop rodando..." -NoNewline
$dockerCmd = Get-Command docker -ErrorAction SilentlyContinue
if (-not $dockerCmd) {
    Write-Host " FALHA (docker nao encontrado no PATH)" -ForegroundColor Red
    Write-Host "  Instale Docker Desktop: winget install --id Docker.DockerDesktop -e" -ForegroundColor Yellow
    $failed = $true
} else {
    $null = & docker info 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host " OK" -ForegroundColor Green
    } else {
        Write-Host " FALHA (daemon nao esta rodando)" -ForegroundColor Red
        Write-Host "  Inicie o Docker Desktop e aguarde o icone na tray ficar 'running'." -ForegroundColor Yellow
        $failed = $true
    }
}

# --- 4. Azure CLI logado ---
Write-Host "[4/8] Azure CLI logado (az)..." -NoNewline
$azCmd = Get-Command az -ErrorAction SilentlyContinue
if (-not $azCmd) {
    Write-Host " FALHA (az nao encontrado no PATH)" -ForegroundColor Red
    Write-Host "  Instale: winget install --id Microsoft.AzureCLI -e" -ForegroundColor Yellow
    $failed = $true
} else {
    $azAccount = & az account show --output json 2>$null
    if ($LASTEXITCODE -eq 0 -and $azAccount) {
        try {
            $accountObj = $azAccount | ConvertFrom-Json
            Write-Host " OK ($($accountObj.user.name))" -ForegroundColor Green
        } catch {
            Write-Host " OK" -ForegroundColor Green
        }
    } else {
        Write-Host " FALHA (nao logado)" -ForegroundColor Red
        Write-Host "  Rode: az login" -ForegroundColor Yellow
        $failed = $true
    }
}

# --- 5. azd CLI logado ---
Write-Host "[5/8] azd CLI logado..." -NoNewline
$azdCmd = Get-Command azd -ErrorAction SilentlyContinue
if (-not $azdCmd) {
    Write-Host " FALHA (azd nao encontrado no PATH)" -ForegroundColor Red
    Write-Host "  Instale: winget install --id Microsoft.Azd -e" -ForegroundColor Yellow
    $failed = $true
} else {
    $null = & azd auth login --check-status 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host " OK" -ForegroundColor Green
    } else {
        Write-Host " FALHA (nao logado)" -ForegroundColor Red
        Write-Host "  Rode: azd auth login" -ForegroundColor Yellow
        $failed = $true
    }
}

# --- 6. ODBC Driver 18 ---
Write-Host "[6/8] ODBC Driver 18 for SQL Server..." -NoNewline
try {
    $odbcDriver = Get-OdbcDriver -Name 'ODBC Driver 18 for SQL Server' -ErrorAction Stop
    if ($odbcDriver) {
        Write-Host " OK" -ForegroundColor Green
    } else {
        Write-Host " FALHA" -ForegroundColor Red
        Write-Host "  Rode: winget install --id Microsoft.msodbcsql.18 -e" -ForegroundColor Yellow
        $failed = $true
    }
} catch {
    Write-Host " FALHA" -ForegroundColor Red
    Write-Host "  Rode: winget install --id Microsoft.msodbcsql.18 -e" -ForegroundColor Yellow
    Write-Host "  Ou baixe: https://learn.microsoft.com/sql/connect/odbc/download-odbc-driver-for-sql-server" -ForegroundColor Yellow
    $failed = $true
}

# --- 7. Python 3.13.x (aceita 'python' direto OU via 'py -3.13' launcher) ---
Write-Host "[7/8] Python 3.13.x..." -NoNewline
$pythonOk = $false
$pythonDetected = ''

$pythonCmd = Get-Command python -ErrorAction SilentlyContinue
if ($pythonCmd) {
    $pythonVersion = & python --version 2>&1
    if ($LASTEXITCODE -eq 0 -and $pythonVersion -match '^Python 3\.13\.') {
        $pythonOk = $true
        $pythonDetected = "$pythonVersion (via 'python' no PATH)"
    }
}

if (-not $pythonOk) {
    $pyCmd = Get-Command py -ErrorAction SilentlyContinue
    if ($pyCmd) {
        $pyVersion = & py -3.13 --version 2>&1
        if ($LASTEXITCODE -eq 0 -and $pyVersion -match '^Python 3\.13\.') {
            $pythonOk = $true
            $pythonDetected = "$pyVersion (via 'py -3.13' launcher)"
        }
    }
}

if ($pythonOk) {
    Write-Host " OK ($pythonDetected)" -ForegroundColor Green
} else {
    $current = if ($pythonCmd) { & python --version 2>&1 } else { '(python nao encontrado)' }
    Write-Host " FALHA ($current)" -ForegroundColor Red
    Write-Host "  Instale Python 3.13 via winget, pyenv-win, Microsoft Store ou python.org:" -ForegroundColor Yellow
    Write-Host "    winget install --id Python.Python.3.13 -e" -ForegroundColor Yellow
    Write-Host "  Aceita: 'python --version' = 3.13.x  OU  'py -3.13 --version' funcional" -ForegroundColor Yellow
    Write-Host "  Para multi-versao recomendado: pyenv-win" -ForegroundColor Yellow
    Write-Host "    https://github.com/pyenv-win/pyenv-win" -ForegroundColor Yellow
    $failed = $true
}

# --- 8. Subscription ativa (informativo) ---
Write-Host "[8/8] Subscription Azure ativa (informativo)..." -NoNewline
if (-not $azCmd) {
    Write-Host " (az nao disponivel)" -ForegroundColor DarkYellow
} else {
    $subName = & az account show --query name --output tsv 2>$null
    $subId = & az account show --query id --output tsv 2>$null
    if ($LASTEXITCODE -eq 0 -and $subName) {
        Write-Host " $subName" -ForegroundColor Green
        Write-Host "  ($subId)" -ForegroundColor DarkGray
        Write-Host "  Se NAO eh a correta: az account set --subscription <id|name>" -ForegroundColor DarkGray
    } else {
        Write-Host " (nao detectada)" -ForegroundColor DarkYellow
        Write-Host "  Use 'az account list -o table' e 'az account set --subscription <id>' para selecionar." -ForegroundColor DarkGray
    }
}

# --- Final ---
Write-Host ""
if ($failed) {
    Write-Host "Pre-flight FAILED. Corrija os itens acima antes de rodar 'azd up'." -ForegroundColor Red
    exit 1
}
Write-Host "Pre-flight PASSED — pronto para 'azd up'." -ForegroundColor Green
exit 0
