#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Start Streamlined Metrics Monitoring Stack
    
.DESCRIPTION
    Starts the streamlined monitoring environment focused on direct metrics collection:
    - ETL simulator (file processing simulation)
    - ETL metrics exporter (Prometheus metrics)
    - Prometheus (metrics storage)
    - Grafana (visualization and alerting)
    - Go App and Database (for demo purposes)
    
    This configuration EXCLUDES log aggregation (Promtail/Loki) in favor of direct metrics.
    
.PARAMETER FullStack
    Start the complete streamlined monitoring stack
    
.PARAMETER ETLOnly
    Start only ETL components (assumes Prometheus/Grafana are already running)
    
.PARAMETER UseStreamlinedConfig
    Use the streamlined docker-compose-metrics.yml configuration
    
.EXAMPLE
    .\start-metrics-monitoring.ps1 -FullStack -UseStreamlinedConfig
    Starts the complete streamlined stack (no log aggregation)
    
.EXAMPLE
    .\start-metrics-monitoring.ps1 -ETLOnly
    Starts only ETL simulator and metrics exporter
#>

param(
    [switch]$FullStack,
    [switch]$ETLOnly,
    [switch]$UseStreamlinedConfig
)

# Default to full stack with streamlined config if no parameters specified
if (-not $FullStack -and -not $ETLOnly) {
    $FullStack = $true
    $UseStreamlinedConfig = $true
}

Write-Host "🚀 Starting Streamlined Metrics Monitoring Stack..." -ForegroundColor Green
Write-Host "===================================================" -ForegroundColor Cyan

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

# Determine which compose file to use
$composeFile = if ($UseStreamlinedConfig) { "docker-compose-metrics.yml" } else { "docker-compose.yml" }

# Check if compose file exists
if (-not (Test-Path $composeFile)) {
    Write-Host "❌ $composeFile not found in $projectRoot" -ForegroundColor Red
    exit 1
}

Write-Host "📋 Using configuration: $composeFile" -ForegroundColor Cyan
if ($UseStreamlinedConfig) {
    Write-Host "   🎯 Streamlined stack (Prometheus metrics only, no log aggregation)" -ForegroundColor Gray
} else {
    Write-Host "   📊 Full stack (includes Promtail/Loki log aggregation)" -ForegroundColor Gray
}

# Update datasources if using streamlined config
if ($UseStreamlinedConfig) {
    Write-Host "🔧 Updating Grafana datasources for streamlined config..." -ForegroundColor Blue
    Copy-Item "grafana/provisioning/datasources/datasources-metrics.yaml" "grafana/provisioning/datasources/datasources.yaml" -Force
}

if ($FullStack) {
    Write-Host "🔧 Starting complete monitoring stack..." -ForegroundColor Blue
    
    # Start all services
    docker compose -f $composeFile up -d
    
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
    $prometheusRunning = docker compose -f $composeFile ps prometheus --status running --quiet
    $grafanaRunning = docker compose -f $composeFile ps grafana --status running --quiet
    
    if (-not $prometheusRunning -or -not $grafanaRunning) {
        Write-Host "⚠️  Warning: Monitoring stack (Prometheus/Grafana) doesn't appear to be running." -ForegroundColor Yellow
        Write-Host "   Consider running with -FullStack flag or start monitoring stack separately." -ForegroundColor Yellow
    }
    
    # Start only ETL services
    docker compose -f $composeFile up -d etl-simulator etl-metrics
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ ETL services started successfully" -ForegroundColor Green
    } else {
        Write-Host "❌ Failed to start ETL services" -ForegroundColor Red
        exit 1
    }
}

# Check service health
Write-Host "🩺 Checking service health..." -ForegroundColor Blue

$services = docker compose -f $composeFile ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"
Write-Host $services -ForegroundColor White

# Test ETL metrics endpoint
Write-Host "🔍 Testing ETL endpoints..." -ForegroundColor Blue

try {
    $healthResponse = Invoke-RestMethod -Uri "http://localhost:8083/health" -TimeoutSec 5
    Write-Host "✅ ETL Health endpoint responding" -ForegroundColor Green
    Write-Host "   Status: $($healthResponse.status)" -ForegroundColor Gray
    Write-Host "   Uptime: $([math]::Round($healthResponse.uptime, 2)) seconds" -ForegroundColor Gray
    Write-Host "   Total Records: $($healthResponse.total_records)" -ForegroundColor Gray
    Write-Host "   Total Files: $($healthResponse.total_files)" -ForegroundColor Gray
} catch {
    Write-Host "⚠️  ETL Health endpoint not responding (may still be starting up)" -ForegroundColor Yellow
}

try {
    $metricsResponse = Invoke-RestMethod -Uri "http://localhost:8083/metrics" -TimeoutSec 5
    $etlMetrics = $metricsResponse -split "`n" | Where-Object { $_ -match "^etl_" -and $_ -notmatch "^#" }
    Write-Host "✅ ETL Metrics endpoint responding with $($etlMetrics.Count) metrics" -ForegroundColor Green
    
    # Show sample metrics
    if ($etlMetrics.Count -gt 0) {
        Write-Host "   Sample metrics:" -ForegroundColor Gray
        $etlMetrics | Select-Object -First 3 | ForEach-Object { Write-Host "     $_" -ForegroundColor DarkGray }
    }
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
Write-Host "   Go App: http://localhost:8081" -ForegroundColor Cyan
Write-Host "   Database API: http://localhost:8082" -ForegroundColor Cyan
Write-Host "" -ForegroundColor White

Write-Host "📊 Architecture Summary:" -ForegroundColor Yellow
if ($UseStreamlinedConfig) {
    Write-Host "   ✅ Direct Metrics Collection (ETL → Prometheus → Grafana)" -ForegroundColor Green
    Write-Host "   ❌ Log Aggregation Excluded (No Promtail/Loki)" -ForegroundColor Red
} else {
    Write-Host "   ✅ Direct Metrics Collection (ETL → Prometheus → Grafana)" -ForegroundColor Green
    Write-Host "   ✅ Log Aggregation Included (App → Promtail → Loki → Grafana)" -ForegroundColor Green
}

Write-Host "" -ForegroundColor White
Write-Host "📊 Monitoring Commands:" -ForegroundColor Yellow
Write-Host "   View ETL logs: docker compose -f $composeFile logs -f etl-simulator" -ForegroundColor Gray
Write-Host "   View metrics logs: docker compose -f $composeFile logs -f etl-metrics" -ForegroundColor Gray
Write-Host "   Stop ETL: docker compose -f $composeFile stop etl-simulator etl-metrics" -ForegroundColor Gray
Write-Host "   Restart ETL: docker compose -f $composeFile restart etl-simulator" -ForegroundColor Gray
Write-Host "   Stop all: docker compose -f $composeFile down" -ForegroundColor Gray

Write-Host "" -ForegroundColor White
Write-Host "✨ Streamlined Metrics Monitoring Stack is ready!" -ForegroundColor Green