<#
.SYNOPSIS
  参加者配布用のロック解除パッケージ（Unlocked Package）のバージョンを作成・昇格し、インストールURLを表示する
.NOTES
  - パッケージ本体は作成済み（sfdx-project.json の packageAliases）。別の Dev Hub で作り直す場合は -CreatePackage を付ける
  - Dev Hub で「ロック解除パッケージと第2世代管理パッケージ」を有効にしておく必要がある
  - ロック解除パッケージはインストール後スクリプトに対応していないため、インストール後に
    権限セット HO_Workshop_Admin の付与と「ハンズオン準備」画面でのデータ生成を行う
  - Windows PowerShell 5.1 で日本語を正しく読めるよう、このファイルは UTF-8 (BOM付き) で保存しています
.EXAMPLE
  ./scripts/create-package.ps1 -DevHub prod
  ./scripts/create-package.ps1 -DevHub prod -NoPromote   # スクラッチ組織での検証用（ベータ版）
#>
param(
    [Parameter(Mandatory = $true)][string]$DevHub,
    [string]$PackageName = 'AWTT MCP Handson',
    [switch]$CreatePackage,
    [switch]$NoPromote
)
Set-Location (Split-Path -Parent $PSScriptRoot)

if ($CreatePackage) {
    Write-Host "== パッケージ '$PackageName' を作成" -ForegroundColor Cyan
    & sf package create --name $PackageName --package-type Unlocked --no-namespace --path force-app --target-dev-hub $DevHub
    if ($LASTEXITCODE -ne 0) { Write-Host 'package create に失敗しました' -ForegroundColor Red; exit 1 }
}

Write-Host '== パッケージバージョンを作成（コードカバー率を計算するため数分〜十数分かかります）' -ForegroundColor Cyan
$raw = & sf package version create --package $PackageName --installation-key-bypass --code-coverage --wait 60 --target-dev-hub $DevHub --json
$json = ($raw -join "`n") | ConvertFrom-Json
if ($json.status -ne 0) { $raw; Write-Host 'package version create に失敗しました' -ForegroundColor Red; exit 1 }
$versionId = $json.result.SubscriberPackageVersionId

if (-not $NoPromote) {
    Write-Host '== バージョンを昇格（Developer Edition など本番タイプの組織へのインストールに必要）' -ForegroundColor Cyan
    & sf package version promote --package $versionId --target-dev-hub $DevHub --no-prompt
    if ($LASTEXITCODE -ne 0) { Write-Host 'promote に失敗しました' -ForegroundColor Red; exit 1 }
}

Write-Host ''
Write-Host "SubscriberPackageVersionId: $versionId" -ForegroundColor Green
Write-Host "インストールURL: https://login.salesforce.com/packaging/installPackage.apexp?p0=$versionId" -ForegroundColor Green
Write-Host "CLI:            sf package install --package $versionId --target-org <alias> --wait 30 --security-type AdminsOnly"
Write-Host "インストール後:  sf org assign permset --name HO_Workshop_Admin --target-org <alias>"
