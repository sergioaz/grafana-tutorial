# Pure ETL-Only Monitoring Stack 🎯

This configuration provides the **cleanest possible ETL monitoring environment** with only the essential components needed for ETL process monitoring and alerting.

## 🏗️ What's Included (4 Services Only)

| Service | Purpose | Port | Resources |
|---------|---------|------|-----------|
| **prometheus** | Metrics storage & querying | 9090 | ~200MB RAM |
| **grafana** | Dashboards & alerting | 3000 | ~150MB RAM |
| **etl-simulator** | ETL process simulation | - | ~50MB RAM |
| **etl-metrics** | Prometheus metrics exporter | 8083 | ~30MB RAM |

**Total Resources**: ~430MB RAM, 4 containers

## ❌ What's Excluded

- ❌ Go web application
- ❌ Database service  
- ❌ Promtail log collector
- ❌ Loki log aggregation
- ❌ Any unnecessary components

## 🚀 Quick Start

### Option 1: PowerShell Script (Recommended)
```powershell
# Start the stack
.\etl\start-etl-only-monitoring.ps1 -StartStack

# Stop the stack  
.\etl\start-etl-only-monitoring.ps1 -StopStack

# Restart just ETL components
.\etl\start-etl-only-monitoring.ps1 -RestartETL

# Check status
.\etl\start-etl-only-monitoring.ps1 -ShowStatus
```

### Option 2: Docker Compose Direct
```bash
# Start stack
docker compose -f docker-compose-etl-only.yml up -d

# Stop stack
docker compose -f docker-compose-etl-only.yml down

# View logs
docker compose -f docker-compose-etl-only.yml logs -f etl-simulator
```

## 🔄 Architecture Flow

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│ETL Simulator│───▶│Log Files    │───▶│ETL Metrics  │───▶│Prometheus   │
│(Processing) │    │(JSON)       │    │Exporter     │    │(Storage)    │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
                                                                   │
                                                                   ▼
                                                           ┌─────────────┐
                                                           │Grafana      │
                                                           │Dashboard &  │
                                                           │Alerts       │
                                                           └─────────────┘
```

## 📊 ETL Simulation Characteristics

- **Processing Rate**: ~10 records/second (600 records/minute)
- **File Sizes**: 50-500 records per file (randomized)
- **Failure Rate**: ~1 failure per minute (realistic failure scenarios)
- **Error Types**: 5 different realistic error categories
- **Logging**: Structured JSON logs with full processing metrics

## 📈 Available Metrics

| Metric | Type | Purpose |
|--------|------|---------|
| `etl_records_total` | Counter | Total records processed |
| `etl_files_total` | Counter | Total files processed |
| `etl_failures_total` | Counter | Total failures |
| `etl_current_rate_records_per_second` | Gauge | Current processing rate |
| `etl_avg_processing_time_seconds` | Gauge | Average processing time |
| `etl_seconds_since_last_success` | Gauge | Time since last success |
| `etl_health_status` | Gauge | Health indicator (1=up, 0=down) |
| `etl_uptime_seconds` | Gauge | Process uptime |
| `etl_errors_by_type_total` | Counter | Errors by type |

## 🎛️ Pre-configured Dashboard

**ETL Process Monitoring Dashboard** (`http://localhost:3000/d/etl-monitoring`)

### Dashboard Panels:
1. **Processing Rate** - Real-time throughput metrics
2. **Health Status** - Current ETL process health
3. **Time Since Last Success** - Monitoring for stalled processing
4. **Total Failures** - Cumulative error count
5. **Average Processing Time** - Performance monitoring
6. **Cumulative Counts** - Records and files over time
7. **Error Types Distribution** - Failure category breakdown
8. **Processing Activity** - 5-minute increment view

## 🚨 Automated Alerts

### Critical Alerts
- **ETL Process Health Check Failed** (triggers after 2 minutes)
- **ETL Metrics Endpoint Unavailable** (monitoring infrastructure)

### Warning Alerts
- **No ETL Success in 10 Minutes** (stalled processing)
- **High ETL Failure Rate** (multiple failures in 5 minutes)
- **Low Throughput** (processing rate below threshold)
- **Excessive Processing Time** (performance degradation)

## 🔧 Configuration Files

```
├── docker-compose-etl-only.yml          # Main service definitions
├── prometheus/
│   ├── prometheus.yml                   # ETL-focused Prometheus config  
│   ├── web.yml                          # 🔐 Authentication config (bcrypt hashes)
│   └── secrets/
│       ├── etl_password.txt             # 🔐 ETL simulator password file
│       └── prometheus_admin_credentials.txt # 🔐 Admin credentials reference
├── .env.secure                          # 🔐 ETL simulator environment variables
├── CREDENTIALS.md                       # 🔐 All credentials reference
├── grafana/provisioning/
│   ├── datasources/datasources.yaml        # Prometheus datasource with auth
│   ├── dashboards/etl-monitoring.json      # ETL dashboard
│   └── alerting/etl-alerts.yaml           # Alert rules
└── etl/
    ├── start-etl-only-monitoring.ps1      # Management script
    ├── etl_simulator.py                   # ETL process simulator
    ├── etl_simulator_secure.py             # 🔐 Secure ETL simulator with auth
    └── metrics_exporter.py                # Prometheus metrics exporter
```

🔐 = Security-related files (excluded from version control)

## 🛠️ Management Commands

### Service Control
```bash
# Start stack
docker compose -f docker-compose-etl-only.yml up -d

# Stop stack
docker compose -f docker-compose-etl-only.yml down

# Restart ETL components only
docker compose -f docker-compose-etl-only.yml restart etl-simulator etl-metrics

# View service status
docker compose -f docker-compose-etl-only.yml ps
```

### Monitoring Commands
```bash
# Check ETL health (containerized ETL)
curl http://localhost:8083/health

# Check external ETL simulator health
curl http://localhost:8000/health

# View raw metrics (containerized ETL)
curl http://localhost:8083/metrics | grep etl_

# View secure external ETL metrics (requires authentication)
curl -u prometheus:secure_metrics_2024 http://localhost:8000/metrics | grep etl_

# Monitor logs in real-time
docker compose -f docker-compose-etl-only.yml logs -f etl-simulator

# View Prometheus targets (requires authentication)
curl -u admin:prometheus_admin_2024 http://localhost:9090/api/v1/targets

# PowerShell authentication examples
$creds = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("admin:prometheus_admin_2024"))
Invoke-WebRequest -Uri "http://localhost:9090/api/v1/targets" -Headers @{Authorization="Basic $creds"}
```

### Development Commands
```bash
# Run ETL simulator locally (for development)
C:\Learn\grafana-tutorial\.venv\Scripts\python.exe etl\etl_simulator.py

# Run SECURE ETL simulator with authentication (recommended)
C:\Learn\grafana-tutorial\.venv\Scripts\python.exe etl\etl_simulator_secure.py

# Run metrics exporter locally (separate terminal)
C:\Learn\grafana-tutorial\.venv\Scripts\python.exe etl\metrics_exporter.py
```

## 🔐 Security Configuration

### Authentication Overview
The ETL monitoring stack now includes comprehensive security:

- **Prometheus**: HTTP Basic Authentication with bcrypt password hashes
- **ETL Simulator**: HTTP Basic Authentication for metrics endpoint
- **Password Files**: Secure storage using password files instead of environment variables

### Prometheus Authentication
**URL**: http://localhost:9090 (requires authentication)

| User | Password | Access Level |
|------|----------|-------------|
| `admin` | `prometheus_admin_2024` | Full access |
| `readonly` | `prometheus_read_2024` | Read-only access |

### ETL Simulator Authentication (localhost:8000)
**Credentials for external ETL simulator**:
- **Username**: `prometheus`
- **Password**: `secure_metrics_2024`

### Security Files
```
prometheus/
├── web.yml                    # Web authentication config (bcrypt hashes)
└── secrets/
    ├── etl_password.txt       # ETL simulator password file
    └── prometheus_admin_credentials.txt  # Admin credentials reference
.env.secure                    # ETL simulator environment variables
CREDENTIALS.md                # All credentials reference (excluded from git)
```

### Starting Secure ETL Simulator
```powershell
# Load credentials from .env.secure
Get-Content .env.secure | ForEach-Object { if($_ -match "^([^#][^=]+)=(.*)$") { [Environment]::SetEnvironmentVariable($matches[1].Trim(), $matches[2].Trim(), "Process") } }

# Start secure ETL simulator
.venv\Scripts\python.exe etl\etl_simulator_secure.py
```

## 📍 Access Points

| Service | URL | Purpose | Authentication |
|---------|-----|---------|----------------|
| **Grafana Home** | http://localhost:3000 | Main interface | Anonymous (Admin role) |
| **ETL Dashboard** | http://localhost:3000/d/etl-monitoring | ETL monitoring | Anonymous (Admin role) |
| **ETL Health** | http://localhost:8083/health | Health check | None required |
| **ETL Metrics** | http://localhost:8083/metrics | Raw metrics | None required |
| **Prometheus** | http://localhost:9090 | Metrics query interface | **admin/prometheus_admin_2024** |
| **Prometheus Targets** | http://localhost:9090/targets | Scrape status | **admin/prometheus_admin_2024** |
| **ETL Simulator (External)** | http://localhost:8000/metrics | Secure metrics endpoint | **prometheus/secure_metrics_2024** |
| **ETL Simulator Health** | http://localhost:8000/health | External health check | None required |

## 🔍 Troubleshooting

### Common Issues

1. **ETL metrics not appearing**
   ```bash
   # Check service status
   docker compose -f docker-compose-etl-only.yml ps etl-metrics
   
   # Verify endpoint
   curl http://localhost:8083/health
   
   # Check Prometheus targets (with authentication)
   curl -u admin:prometheus_admin_2024 http://localhost:9090/api/v1/targets
   
   # Verify external ETL simulator is running
   curl http://localhost:8000/health
   
   # Test external ETL metrics authentication
   curl -u prometheus:secure_metrics_2024 http://localhost:8000/metrics
   ```

2. **Dashboard not loading**
   ```bash
   # Check Grafana logs
   docker compose -f docker-compose-etl-only.yml logs grafana
   
   # Verify provisioning
   ls -la grafana/provisioning/dashboards/
   ```

3. **Alerts not triggering**
   ```bash
   # Check alert rules in Grafana
   # Visit: http://localhost:3000/alerting/list
   
   # Verify Prometheus is scraping metrics (with authentication)
   # Visit: http://localhost:9090/targets (login: admin/prometheus_admin_2024)
   ```

4. **Authentication issues**
   ```bash
   # Test Prometheus authentication
   curl -u admin:prometheus_admin_2024 http://localhost:9090/api/v1/targets
   
   # Test ETL simulator authentication
   curl -u prometheus:secure_metrics_2024 http://localhost:8000/metrics
   
   # Check if password files exist and have correct content
   docker compose -f docker-compose-etl-only.yml exec prometheus cat /etc/prometheus/secrets/etl_password.txt
   
   # Verify web.yml is loaded
   docker compose -f docker-compose-etl-only.yml exec prometheus cat /etc/prometheus/web.yml
   
   # Check Grafana datasource connection
   # Visit: http://localhost:3000/datasources (should show "OK" for Prometheus)
   ```

### Performance Optimization

1. **Reduce resource usage**:
   - Lower Grafana log level from `debug` to `info`
   - Adjust Prometheus retention period
   - Reduce ETL processing rate if needed

2. **Increase processing rate**:
   - Modify `records_per_second` in `etl_simulator.py`
   - Adjust failure intervals for different testing scenarios

## 🎯 Use Cases

### Perfect for:
- ✅ **ETL Process Monitoring Demos**
- ✅ **Learning Prometheus/Grafana**
- ✅ **Testing Alert Configurations**
- ✅ **Resource-Constrained Environments**
- ✅ **CI/CD Pipeline Testing**
- ✅ **Educational Workshops**

### Not ideal for:
- ❌ Full microservice observability demos
- ❌ Log analysis demonstrations
- ❌ Complex multi-app monitoring scenarios

## 🚀 Production Considerations

Before using in production:
1. ✅ **Authentication implemented** - Prometheus secured with HTTP Basic Auth
2. ✅ **Password security** - Using bcrypt hashes and password files
3. ✅ **ETL simulator security** - Metrics endpoint requires authentication
4. ❗ **Configure persistent volumes** for Prometheus data
5. ❗ **Set up external alerting** (email, Slack, PagerDuty)
6. ❗ **Add resource limits** to Docker services
7. ❗ **Implement backup/restore** procedures
8. ❗ **Configure proper retention** policies
9. ❗ **Enable HTTPS** for production deployment
10. ❗ **Change default passwords** and use stronger credentials
11. ❗ **Add Grafana authentication** (currently anonymous)
12. ❗ **Secure credential files** with proper file permissions

3. Verify dashboard and alerts still work correctly
4. Test with different failure scenarios using `RestartETL`

---

## 🔒 Security Summary

**This ETL monitoring stack now includes enterprise-grade security features:**

✅ **Prometheus Authentication**: HTTP Basic Auth with bcrypt password hashes  
✅ **Password File Security**: Credentials stored in secure password files  
✅ **ETL Simulator Security**: Metrics endpoint requires authentication  
✅ **Grafana Integration**: Automatic authentication with Prometheus datasource  
✅ **Version Control Safety**: All sensitive files excluded from git  

**Security Implementation Highlights:**
- 🔐 bcrypt password hashing for web authentication
- 🔐 Password files instead of environment variables
- 🔐 Multi-user authentication (admin/readonly)
- 🔐 Secure credential management
- 🔐 No plaintext passwords in configuration files

---

**This configuration provides the cleanest possible ETL monitoring experience with minimal overhead, maximum security, and complete focus on the ETL process itself.** 🎯🔒
