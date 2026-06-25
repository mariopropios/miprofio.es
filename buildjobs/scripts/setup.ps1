# Script de configuración inicial para BuildJobs
# Ejecutar en PowerShell después de instalar Flutter

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $projectRoot

Write-Host "=== BuildJobs Setup ===" -ForegroundColor Green

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Host "Flutter no está instalado o no está en el PATH." -ForegroundColor Red
    Write-Host "Instálalo desde: https://docs.flutter.dev/get-started/install/windows"
    exit 1
}

Write-Host "Generando carpetas de plataforma..."
flutter create . --project-name buildjobs --org com.buildjobs

Write-Host "Instalando dependencias..."
flutter pub get

if (-not (Test-Path ".env")) {
    Copy-Item ".env.example" ".env"
    Write-Host "Archivo .env creado. Configura tus credenciales de Supabase."
}

Write-Host ""
Write-Host "Setup completado. Próximos pasos:" -ForegroundColor Green
Write-Host "  1. Edita .env con tus credenciales de Supabase"
Write-Host "  2. Ejecuta el SQL en supabase/migrations/001_initial_schema.sql"
Write-Host "  3. flutter run -d chrome"
