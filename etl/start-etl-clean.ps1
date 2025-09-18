#!/usr/bin/env pwsh
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

Write-Host "Pure ETL-Only Monitoring Stack Manager" -ForegroundColor Green
Write-Host "=====================================" -ForegroundColor Cyan

# Change to project root directory
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

Write-Host "Project directory: $projectRoot" -ForegroundColor Yellow
Write-Host "Configuration: $composeFile" -ForegroundColor Cyan

# Check if Docker is running
try {
    docker version | Out-Null
    Write-Host "Docker is running" -ForegroundColor Green
} catch {
    Write-Host "Docker is not running. Please start Docker Desktop." -ForegroundColor Red
    exit 1
}

# Check if compose file exists
if (-not (Test-Path $composeFile)) {
    Write-Host "$composeFile not found in $projectRoot" -ForegroundColor Red
    exit 1
}

# Setup configurations
Write-Host "Setting up ETL-only configurations..." -ForegroundColor Blue
if (Test-Path "prometheus/$prometheusConfig") {
    Copy-Item "prometheus/$prometheusConfig" "prometheus/prometheus.yml" -Force
    Write-Host "ETL-only Prometheus config activated" -ForegroundColor Green
}

if (Test-Path "grafana/provisioning/datasources/datasources-metrics.yaml") {
    Copy-Item "grafana/provisioning/datasources/datasources-metrics.yaml" "grafana/provisioning/datasources/datasources.yaml" -Force
    Write-Host "ETL-only Grafana datasources activated" -ForegroundColor Green
}

if ($StartStack) {
    Write-Host ""
    Write-Host "Starting ETL-only monitoring stack..." -ForegroundColor Blue
    
    docker compose -f $composeFile up -d
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "ETL-only stack started successfully" -ForegroundColor Green
    } else {
        Write-Host "Failed to start ETL-only stack" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "Waiting for services to initialize..." -ForegroundColor Yellow
    Start-Sleep -Seconds 15
    
} elseif ($StopStack) {
    Write-Host ""
    Write-Host "Stopping ETL-only monitoring stack..." -ForegroundColor Red
    
    docker compose -f $composeFile down
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "ETL-only stack stopped successfully" -ForegroundColor Green
        return
    } else {
        Write-Host "Failed to stop ETL-only stack" -ForegroundColor Red
        exit 1
    }
    
} elseif ($RestartETL) {
    Write-Host ""
    Write-Host "Restarting ETL components..." -ForegroundColor Yellow
    
    docker compose -f $composeFile restart etl-simulator etl-metrics
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "ETL components restarted successfully" -ForegroundColor Green
    } else {
        Write-Host "Failed to restart ETL components" -ForegroundColor Red
        exit 1
    }
    
    Start-Sleep -Seconds 5
}

# Show service status
Write-Host ""
Write-Host "Service Health Status:" -ForegroundColor Blue

$services = docker compose -f $composeFile ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"
Write-Host $services -ForegroundColor White

# Test endpoints
Write-Host ""
Write-Host "Testing service endpoints..." -ForegroundColor Blue

# Test ETL Health
try {
    $healthResponse = Invoke-RestMethod -Uri "http://localhost:8083/health" -TimeoutSec 5
    Write-Host "ETL Health endpoint responding" -ForegroundColor Green
    Write-Host "   Status: $($healthResponse.status)" -ForegroundColor Gray
    Write-Host "   Uptime: $([math]::Round($healthResponse.uptime, 2)) seconds" -ForegroundColor Gray
    Write-Host "   Total Records: $($healthResponse.total_records)" -ForegroundColor Gray
    Write-Host "   Total Files: $($healthResponse.total_files)" -ForegroundColor Gray
    Write-Host "   Total Failures: $($healthResponse.total_failures)" -ForegroundColor Gray
} catch {
    Write-Host "ETL Health endpoint not responding (may still be starting)" -ForegroundColor Yellow
}

# Test ETL Metrics
try {
    $metricsResponse = Invoke-RestMethod -Uri "http://localhost:8083/metrics" -TimeoutSec 5
    $etlMetrics = $metricsResponse -split "`n" | Where-Object { $_ -match "^etl_" -and $_ -notmatch "^#" }
    Write-Host "ETL Metrics endpoint responding with $($etlMetrics.Count) metrics" -ForegroundColor Green
} catch {
    Write-Host "ETL Metrics endpoint not responding (may still be starting)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Access Points:" -ForegroundColor Green
Write-Host "   Grafana Dashboard: http://localhost:3000" -ForegroundColor Cyan
Write-Host "   ETL Dashboard: http://localhost:3000/d/etl-monitoring" -ForegroundColor Cyan
Write-Host "   ETL Metrics: http://localhost:8083/metrics" -ForegroundColor Cyan
Write-Host "   ETL Health: http://localhost:8083/health" -ForegroundColor Cyan
Write-Host "   Prometheus: http://localhost:9090" -ForegroundColor Cyan

Write-Host ""
Write-Host "Management Commands:" -ForegroundColor Yellow
Write-Host "   Start: .\etl\start-etl-clean.ps1 -StartStack" -ForegroundColor Gray
Write-Host "   Stop: .\etl\start-etl-clean.ps1 -StopStack" -ForegroundColor Gray
Write-Host "   Restart ETL: .\etl\start-etl-clean.ps1 -RestartETL" -ForegroundColor Gray
Write-Host "   Status: .\etl\start-etl-clean.ps1 -ShowStatus" -ForegroundColor Gray

Write-Host ""
if ($StartStack) {
    Write-Host "Pure ETL-Only Monitoring Stack is ready!" -ForegroundColor Green
} elseif ($ShowStatus -or $RestartETL) {
    Write-Host "ETL-Only Stack Status Updated!" -ForegroundColor Green
}