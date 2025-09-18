#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Start Pure ETL-Only Monitoring Stack
    
.DESCRIPTION
    Starts a completely focused ETL monitoring environment with only:
    - ETL simulator (file processing simulation)
    - ETL metrics exporter (Prometheus metrics)
    - Prometheus (metrics storage)
    - Grafana (visualization and alerting)
    
    This configuration EXCLUDES all other components (Go app, database, log aggregation)
    for the cleanest possible ETL monitoring demonstration.
    
.PARAMETER StartStack
    Start the complete ETL-only monitoring stack
    
.PARAMETER StopStack
    Stop the ETL-only monitoring stack
    
.PARAMETER RestartETL
    Restart only the ETL components (simulator and metrics)
    
.PARAMETER ShowStatus
    Show current status of all services
    
.EXAMPLE
    .\start-etl-only-monitoring.ps1 -StartStack
    Starts the complete ETL-only monitoring stack
    
.EXAMPLE
    .\start-etl-only-monitoring.ps1 -RestartETL
    Restarts only the ETL simulator and metrics exporter
    
.EXAMPLE
    .\start-etl-only-monitoring.ps1 -StopStack
    Stops all services in the ETL monitoring stack
#>

param(
    [switch]$StartStack,
    [switch]$StopStack,
    [switch]$RestartETL,
    [switch]$ShowStatus
)

# Default to start stack if no parameters specified
if (-not $StartStack -and -not $StopStack -and -not $RestartETL -and -not $ShowStatus) {
    $StartStack = $true
}

$composeFile = "docker-compose-etl-only.yml"
$prometheusConfig = "prometheus-etl-only.yml"

Write-Host "🎯 Pure ETL-Only Monitoring Stack Manager" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Cyan

# Change to project root directory
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

Write-Host "📍 Project directory: $projectRoot" -ForegroundColor Yellow
Write-Host "📋 Configuration: $composeFile" -ForegroundColor Cyan
Write-Host "🔧 Services: Grafana + Prometheus + ETL Simulator + ETL Metrics (4 services total)" -ForegroundColor Gray

# Check if Docker is running
try {
    docker version | Out-Null
    Write-Host "✅ Docker is running" -ForegroundColor Green
} catch {
    Write-Host "❌ Docker is not running. Please start Docker Desktop." -ForegroundColor Red
    exit 1
}

# Check if compose file exists
if (-not (Test-Path $composeFile)) {
    Write-Host "❌ $composeFile not found in $projectRoot" -ForegroundColor Red
    exit 1
}

# Ensure ETL-only Prometheus config is active
Write-Host "🔧 Setting up ETL-only Prometheus configuration..." -ForegroundColor Blue
if (Test-Path "prometheus/$prometheusConfig") {
    Copy-Item "prometheus/$prometheusConfig" "prometheus/prometheus.yml" -Force
    Write-Host "✅ ETL-only Prometheus config activated" -ForegroundColor Green
} else {
    Write-Host "⚠️  ETL-only Prometheus config not found, using existing configuration" -ForegroundColor Yellow
}

# Ensure ETL-only datasources are active
Write-Host "🔧 Setting up ETL-only Grafana datasources..." -ForegroundColor Blue
if (Test-Path "grafana/provisioning/datasources/datasources-metrics.yaml") {
    Copy-Item "grafana/provisioning/datasources/datasources-metrics.yaml" "grafana/provisioning/datasources/datasources.yaml" -Force
    Write-Host "✅ ETL-only Grafana datasources activated" -ForegroundColor Green
}

if ($StartStack) {
    Write-Host "" -ForegroundColor White
    Write-Host "🚀 Starting ETL-only monitoring stack..." -ForegroundColor Blue
    
    # Start all services
    docker compose -f $composeFile up -d
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ ETL-only stack started successfully" -ForegroundColor Green
    } else {
        Write-Host "❌ Failed to start ETL-only stack" -ForegroundColor Red
        exit 1
    }
    
    # Wait for services to initialize
    Write-Host "⏱️  Waiting for services to initialize..." -ForegroundColor Yellow
    Start-Sleep -Seconds 15
    
} elseif ($StopStack) {
    Write-Host "" -ForegroundColor White
    Write-Host "🛑 Stopping ETL-only monitoring stack..." -ForegroundColor Red
    
    docker compose -f $composeFile down
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ ETL-only stack stopped successfully" -ForegroundColor Green
        return
    } else {
        Write-Host "❌ Failed to stop ETL-only stack" -ForegroundColor Red
        exit 1
    }
    
} elseif ($RestartETL) {
    Write-Host "" -ForegroundColor White
    Write-Host "🔄 Restarting ETL components..." -ForegroundColor Yellow
    
    docker compose -f $composeFile restart etl-simulator etl-metrics
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ ETL components restarted successfully" -ForegroundColor Green
    } else {
        Write-Host "❌ Failed to restart ETL components" -ForegroundColor Red
        exit 1
    }
    
    Start-Sleep -Seconds 5
}

# Show service status
Write-Host "" -ForegroundColor White
Write-Host "🩺 Service Health Status:" -ForegroundColor Blue

$services = docker compose -f $composeFile ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"
Write-Host $services -ForegroundColor White

# Test endpoints
Write-Host "" -ForegroundColor White
Write-Host "🔍 Testing service endpoints..." -ForegroundColor Blue

# Test Prometheus
try {
    $prometheusResponse = Invoke-RestMethod -Uri "http://localhost:9090/-/healthy" -TimeoutSec 5
    Write-Host "✅ Prometheus is healthy" -ForegroundColor Green
} catch {
    Write-Host "⚠️  Prometheus not responding (may still be starting)" -ForegroundColor Yellow
}

# Test Grafana
try {
    $grafanaResponse = Invoke-RestMethod -Uri "http://localhost:3000/api/health" -TimeoutSec 5
    Write-Host "✅ Grafana is healthy" -ForegroundColor Green
} catch {
    Write-Host "⚠️  Grafana not responding (may still be starting)" -ForegroundColor Yellow
}

# Test ETL Health
try {
    $healthResponse = Invoke-RestMethod -Uri "http://localhost:8083/health" -TimeoutSec 5
    Write-Host "✅ ETL Health endpoint responding" -ForegroundColor Green
    Write-Host "   Status: $($healthResponse.status)" -ForegroundColor Gray
    Write-Host "   Uptime: $([math]::Round($healthResponse.uptime, 2)) seconds" -ForegroundColor Gray
    Write-Host "   Total Records: $($healthResponse.total_records)" -ForegroundColor Gray
    Write-Host "   Total Files: $($healthResponse.total_files)" -ForegroundColor Gray
    Write-Host "   Total Failures: $($healthResponse.total_failures)" -ForegroundColor Gray
} catch {
    Write-Host "⚠️  ETL Health endpoint not responding (may still be starting)" -ForegroundColor Yellow
}

# Test ETL Metrics
try {
    $metricsResponse = Invoke-RestMethod -Uri "http://localhost:8083/metrics" -TimeoutSec 5
    $etlMetrics = $metricsResponse -split "`n" | Where-Object { $_ -match "^etl_" -and $_ -notmatch "^#" }
    Write-Host "✅ ETL Metrics endpoint responding with $($etlMetrics.Count) metrics" -ForegroundColor Green
    
    if ($etlMetrics.Count -gt 0) {
        Write-Host "   Sample metrics:" -ForegroundColor Gray
        $etlMetrics | Select-Object -First 4 | ForEach-Object { 
            $metricName = ($_ -split " ")[0]
            $metricValue = ($_ -split " ")[1]
            Write-Host "     $metricName = $metricValue" -ForegroundColor DarkGray 
        }
    }
} catch {
    Write-Host "⚠️  ETL Metrics endpoint not responding (may still be starting)" -ForegroundColor Yellow
}

# Test Prometheus targets
try {
    $targetsResponse = Invoke-RestMethod -Uri "http://localhost:9090/api/v1/targets" -TimeoutSec 5
    $activeTargets = $targetsResponse.data.activeTargets | Where-Object { $_.health -eq "up" }
    Write-Host "✅ Prometheus has $($activeTargets.Count) healthy targets" -ForegroundColor Green
    
    foreach ($target in $activeTargets) {
        Write-Host "   ✓ $($target.job): $($target.scrapeUrl)" -ForegroundColor DarkGray
    }
} catch {
    Write-Host "⚠️  Could not verify Prometheus targets" -ForegroundColor Yellow
}

Write-Host "" -ForegroundColor White
Write-Host "🎯 Access Points:" -ForegroundColor Green
Write-Host "   Grafana Dashboard: http://localhost:3000" -ForegroundColor Cyan
Write-Host "   ETL Dashboard: http://localhost:3000/d/etl-monitoring" -ForegroundColor Cyan
Write-Host "   ETL Metrics: http://localhost:8083/metrics" -ForegroundColor Cyan
Write-Host "   ETL Health: http://localhost:8083/health" -ForegroundColor Cyan
Write-Host "   Prometheus: http://localhost:9090" -ForegroundColor Cyan
Write-Host "   Prometheus Targets: http://localhost:9090/targets" -ForegroundColor Cyan
Write-Host "" -ForegroundColor White

Write-Host "📊 Stack Architecture:" -ForegroundColor Yellow
Write-Host "   🔄 ETL Simulator → Log Files → ETL Metrics Exporter" -ForegroundColor Green
Write-Host "   📈 ETL Metrics → Prometheus → Grafana Dashboard" -ForegroundColor Green
Write-Host "   🚨 Prometheus → Grafana Alerts" -ForegroundColor Green
Write-Host "   ❌ No Go App, Database, or Log Aggregation" -ForegroundColor Red

Write-Host "" -ForegroundColor White
Write-Host "📊 Management Commands:" -ForegroundColor Yellow
Write-Host "   Start stack: .\\etl\\start-etl-only-monitoring.ps1 -StartStack" -ForegroundColor Gray
Write-Host "   Stop stack: .\\etl\\start-etl-only-monitoring.ps1 -StopStack" -ForegroundColor Gray
Write-Host "   Restart ETL: .\\etl\\start-etl-only-monitoring.ps1 -RestartETL" -ForegroundColor Gray
Write-Host "   Check status: .\\etl\\start-etl-only-monitoring.ps1 -ShowStatus" -ForegroundColor Gray
Write-Host "   View ETL logs: docker compose -f $composeFile logs -f etl-simulator" -ForegroundColor Gray
Write-Host "   View metrics logs: docker compose -f $composeFile logs -f etl-metrics" -ForegroundColor Gray

Write-Host "" -ForegroundColor White
if ($StartStack) {
    Write-Host "✨ Pure ETL-Only Monitoring Stack is ready!" -ForegroundColor Green
    Write-Host "🎯 Focus: ETL process monitoring without any extra components" -ForegroundColor Cyan
} elseif ($ShowStatus -or $RestartETL) {
    Write-Host "📊 ETL-Only Stack Status Updated!" -ForegroundColor Green
}