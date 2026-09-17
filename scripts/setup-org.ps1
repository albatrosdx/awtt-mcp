<#
.SYNOPSIS
  ハンズオン組織のセットアップ（メタデータのデプロイ → 権限セット付与 → テストデータ生成）
.EXAMPLE
  ./scripts/setup-org.ps1 -TargetOrg handson01
  ./scripts/setup-org.ps1 -TargetOrg handson01 -SkipDeploy   # データだけ作り直す
.NOTES
  Windows PowerShell 5.1 で日本語を正しく読めるよう、このファイルは UTF-8 (BOM付き) で保存しています。
  sf CLI は警告を標準エラーに出すため、成否は $LASTEXITCODE で判定します。
#>
param(
    [Parameter(Mandatory = $true)][string]$TargetOrg,
    [switch]$SkipDeploy,
    [string[]]$ExtraUsers = @()   # MCP 接続に使う参加者ユーザー名（HO_MCP_ReadOnly を付与）
)
Set-Location (Split-Path -Parent $PSScriptRoot)

function Invoke-Sf {
    param([string]$Step, [string[]]$Arguments)
    & sf @Arguments
    if ($LASTEXITCODE -ne 0) {
        Write-Host "失敗: $Step (sf $($Arguments -join ' '))" -ForegroundColor Red
        exit 1
    }
}

if (-not $SkipDeploy) {
    Write-Host '== 1/3 メタデータをデプロイ' -ForegroundColor Cyan
    Invoke-Sf 'デプロイ' @('project', 'deploy', 'start', '--source-dir', 'force-app', '--target-org', $TargetOrg, '--test-level', 'RunLocalTests', '--wait', '30')
}

Write-Host '== 2/3 権限セットを付与' -ForegroundColor Cyan
# 既に割り当て済みの場合もエラー終了するため、ここは失敗しても続行する
& sf org assign permset --name HO_Workshop_Admin --target-org $TargetOrg
foreach ($u in $ExtraUsers) {
    & sf org assign permset --name HO_MCP_ReadOnly --target-org $TargetOrg --on-behalf-of $u
}

Write-Host '== 3/3 テストデータを生成' -ForegroundColor Cyan
Invoke-Sf 'データ生成' @('apex', 'run', '--file', 'scripts/apex/generate.apex', '--target-org', $TargetOrg)

Write-Host '完了: アプリ「HO MCPハンズオン」>「ハンズオン準備」で件数を確認してください' -ForegroundColor Green
