#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Start ETL Monitoring Stack
    
.DESCRIPTION
    Starts the complete ETL monitoring environment including:
    - ETL simulator (file processing simulation)
    - ETL metrics exporter (Prometheus metrics)
    - All monitoring infrastructure (if not already running)
    
.PARAMETER FullStack
    Start the complete monitoring stack (Grafana, Prometheus, etc.)
    
.PARAMETER ETLOnly
    Start only ETL components (assumes monitoring stack is already running)
    
.EXAMPLE
    .\start-etl-monitoring.ps1 -FullStack
    Starts everything including Grafana, Prometheus, and ETL components
    
.EXAMPLE
    .\start-etl-monitoring.ps1 -ETLOnly
    Starts only ETL simulator and metrics exporter
#>

param(
    [switch]$FullStack,
    [switch]$ETLOnly
)

# Default to ETL only if no parameters specified
if (-not $FullStack -and -not $ETLOnly) {
    $ETLOnly = $true
}

Write-Host "🚀 Starting ETL Monitoring Stack..." -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Cyan

# Change to project root directory
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

Write-Host "📍 Project directory: $projectRoot" -ForegroundColor Yellow

# Check if Docker is running
try {
    docker version | Out-Null
    Write-Host "✅ Docker is running" -ForegroundColor Green
} catch {
    Write-Host "❌ Docker is not running. Please start Docker Desktop." -ForegroundColor Red
    exit 1
}

# Check if docker-compose.yml exists
if (-not (Test-Path "docker-compose.yml")) {
    Write-Host "❌ docker-compose.yml not found in $projectRoot" -ForegroundColor Red
    exit 1
}

if ($FullStack) {
    Write-Host "🔧 Starting complete monitoring stack..." -ForegroundColor Blue
    
    # Start all services
    docker compose up -d
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Full stack started successfully" -ForegroundColor Green
    } else {
        Write-Host "❌ Failed to start full stack" -ForegroundColor Red
        exit 1
    }
    
    # Wait a moment for services to initialize
    Write-Host "⏱️  Waiting for services to initialize..." -ForegroundColor Yellow
    Start-Sleep -Seconds 10
    
} elseif ($ETLOnly) {
    Write-Host "🔧 Starting ETL services only..." -ForegroundColor Blue
    
    # Check if monitoring stack is running
    $prometheusRunning = docker compose ps prometheus --status running --quiet
    $grafanaRunning = docker compose ps grafana --status running --quiet
    
    if (-not $prometheusRunning -or -not $grafanaRunning) {
        Write-Host "⚠️  Warning: Monitoring stack (Prometheus/Grafana) doesn't appear to be running." -ForegroundColor Yellow
        Write-Host "   Consider running with -FullStack flag or start monitoring stack separately." -ForegroundColor Yellow
    }
    
    # Start only ETL services
    docker compose up -d etl-simulator etl-metrics
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ ETL services started successfully" -ForegroundColor Green
    } else {
        Write-Host "❌ Failed to start ETL services" -ForegroundColor Red
        exit 1
    }
}

# Check service health
Write-Host "🩺 Checking service health..." -ForegroundColor Blue

$services = docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"
Write-Host $services -ForegroundColor White

# Test ETL metrics endpoint
Write-Host "🔍 Testing ETL endpoints..." -ForegroundColor Blue

try {
    $healthResponse = Invoke-RestMethod -Uri "http://localhost:8083/health" -TimeoutSec 5
    Write-Host "✅ ETL Health endpoint responding" -ForegroundColor Green
    Write-Host "   Status: $($healthResponse.status)" -ForegroundColor Gray
    Write-Host "   Uptime: $([math]::Round($healthResponse.uptime, 2)) seconds" -ForegroundColor Gray
} catch {
    Write-Host "⚠️  ETL Health endpoint not responding (may still be starting up)" -ForegroundColor Yellow
}

try {
    $metricsResponse = Invoke-RestMethod -Uri "http://localhost:8083/metrics" -TimeoutSec 5
    $etlMetrics = $metricsResponse -split "`n" | Where-Object { $_ -match "^etl_" -and $_ -notmatch "^#" }
    Write-Host "✅ ETL Metrics endpoint responding with $($etlMetrics.Count) metrics" -ForegroundColor Green
} catch {
    Write-Host "⚠️  ETL Metrics endpoint not responding (may still be starting up)" -ForegroundColor Yellow
}

Write-Host "" -ForegroundColor White
Write-Host "🎯 Access Points:" -ForegroundColor Green
Write-Host "   Grafana Dashboard: http://localhost:3000" -ForegroundColor Cyan
Write-Host "   ETL Dashboard: http://localhost:3000/d/etl-monitoring" -ForegroundColor Cyan
Write-Host "   ETL Metrics: http://localhost:8083/metrics" -ForegroundColor Cyan
Write-Host "   ETL Health: http://localhost:8083/health" -ForegroundColor Cyan
Write-Host "   Prometheus: http://localhost:9090" -ForegroundColor Cyan
Write-Host "" -ForegroundColor White

Write-Host "📊 Monitoring Commands:" -ForegroundColor Yellow
Write-Host "   View ETL logs: docker compose logs -f etl-simulator" -ForegroundColor Gray
Write-Host "   View metrics logs: docker compose logs -f etl-metrics" -ForegroundColor Gray
Write-Host "   Stop ETL: docker compose stop etl-simulator etl-metrics" -ForegroundColor Gray
Write-Host "   Restart ETL: docker compose restart etl-simulator" -ForegroundColor Gray

Write-Host "" -ForegroundColor White
Write-Host "✨ ETL Monitoring Stack is ready!" -ForegroundColor Green