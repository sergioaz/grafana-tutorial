#!/usr/bin/env python3
"""
ETL Metrics Exporter - Reads ETL logs and exposes Prometheus metrics
Provides HTTP endpoint with metrics for Grafana monitoring
"""

import json
import time
# import threading
import os
from datetime import datetime, timedelta
from pathlib import Path
from http.server import HTTPServer, BaseHTTPRequestHandler
from collections import defaultdict, deque
# import re
import signal
import sys

class ETLMetricsCollector:
    def __init__(self, log_file=None):
        if log_file is None:
            log_file = os.environ.get('LOG_FILE', 'etl_process.log')
        self.log_file = Path(log_file)
        self.metrics = {
            'total_records': 0,
            'total_files': 0,
            'total_failures': 0,
            'last_update': 0,
            'records_per_minute': deque(maxlen=60),  # Track per-minute rates
            'files_per_minute': deque(maxlen=60),
            'failures_per_minute': deque(maxlen=60),
            'processing_times': deque(maxlen=100),  # Track last 100 processing times
            'error_types': defaultdict(int),
            'current_rate': 0,
            'avg_processing_time': 0,
            'uptime_seconds': 0,
            'last_successful_file': 0,
            'last_failure': 0
        }
        self.running = False
        self.last_position = 0
        
    def parse_log_line(self, line):
        """Parse a JSON log line and extract metrics"""
        try:
            # Extract timestamp and log level
            parts = line.strip().split(' ', 2)
            if len(parts) < 3:
                return None
                
            timestamp_str = parts[0]
            level = parts[1]
            json_data = parts[2]
            
            data = json.loads(json_data)
            
            # Convert timestamp to unix timestamp
            try:
                dt = datetime.fromisoformat(timestamp_str.replace('Z', '+00:00'))
                timestamp = dt.timestamp()
            except:
                timestamp = time.time()
            
            return {
                'timestamp': timestamp,
                'level': level,
                'data': data
            }
        except json.JSONDecodeError:
            return None
        except Exception as e:
            print(f"Error parsing log line: {e}")
            return None
    
    def update_metrics_from_log(self, log_entry):
        """Update metrics based on log entry"""
        if not log_entry:
            return
            
        data = log_entry['data']
        level = log_entry['level']
        timestamp = log_entry['timestamp']
        
        # Update basic counters
        if 'total_records' in data:
            self.metrics['total_records'] = data['total_records']
        if 'total_files' in data:
            self.metrics['total_files'] = data['total_files']
        if 'total_failures' in data:
            self.metrics['total_failures'] = data['total_failures']
            
        self.metrics['last_update'] = timestamp
        
        # Track specific events
        message = data.get('message', '')
        
        if message == 'file_processing_completed':
            self.metrics['last_successful_file'] = timestamp
            
            # Track processing time
            if 'processing_time' in data:
                self.metrics['processing_times'].append(data['processing_time'])
                
            # Track current rate
            if 'current_rate' in data:
                self.metrics['current_rate'] = data['current_rate']
                
        elif message == 'file_processing_failed':
            self.metrics['last_failure'] = timestamp
            
            # Track error types
            if 'failure_reason' in data:
                self.metrics['error_types'][data['failure_reason']] += 1
                
        elif message == 'etl_simulator_started':
            # Reset start time for uptime calculation
            self.metrics['simulator_start_time'] = timestamp
    
    def calculate_derived_metrics(self):
        """Calculate derived metrics from collected data"""
        current_time = time.time()
        
        # Calculate uptime
        start_time = self.metrics.get('simulator_start_time', current_time)
        self.metrics['uptime_seconds'] = current_time - start_time
        
        # Calculate average processing time
        if self.metrics['processing_times']:
            self.metrics['avg_processing_time'] = sum(self.metrics['processing_times']) / len(self.metrics['processing_times'])
        
        # Time since last successful file
        if self.metrics['last_successful_file']:
            self.metrics['seconds_since_last_success'] = current_time - self.metrics['last_successful_file']
        else:
            self.metrics['seconds_since_last_success'] = 0
            
        # Time since last failure
        if self.metrics['last_failure']:
            self.metrics['seconds_since_last_failure'] = current_time - self.metrics['last_failure']
        else:
            self.metrics['seconds_since_last_failure'] = float('inf')
    
    def read_new_logs(self):
        """Read new log entries from file"""
        if not self.log_file.exists():
            return []
            
        try:
            with open(self.log_file, 'r', encoding='utf-8') as f:
                f.seek(self.last_position)
                new_lines = f.readlines()
                self.last_position = f.tell()
                
            return [self.parse_log_line(line) for line in new_lines]
        except Exception as e:
            print(f"Error reading log file: {e}")
            return []
    
    def update_metrics(self):
        """Update all metrics from new log entries"""
        new_entries = self.read_new_logs()
        
        for entry in new_entries:
            if entry:
                self.update_metrics_from_log(entry)
        
        self.calculate_derived_metrics()
    
    def generate_prometheus_metrics(self):
        """Generate Prometheus-format metrics"""
        self.update_metrics()
        
        metrics_output = []
        
        # Basic counters
        metrics_output.append(f"# HELP etl_records_total Total number of records processed")
        metrics_output.append(f"# TYPE etl_records_total counter")
        metrics_output.append(f"etl_records_total {self.metrics['total_records']}")
        metrics_output.append("")
        
        metrics_output.append(f"# HELP etl_files_total Total number of files processed")
        metrics_output.append(f"# TYPE etl_files_total counter")
        metrics_output.append(f"etl_files_total {self.metrics['total_files']}")
        metrics_output.append("")
        
        metrics_output.append(f"# HELP etl_failures_total Total number of processing failures")
        metrics_output.append(f"# TYPE etl_failures_total counter")
        metrics_output.append(f"etl_failures_total {self.metrics['total_failures']}")
        metrics_output.append("")
        
        # Current rate
        metrics_output.append(f"# HELP etl_current_rate_records_per_second Current processing rate")
        metrics_output.append(f"# TYPE etl_current_rate_records_per_second gauge")
        metrics_output.append(f"etl_current_rate_records_per_second {self.metrics['current_rate']}")
        metrics_output.append("")
        
        # Average processing time
        metrics_output.append(f"# HELP etl_avg_processing_time_seconds Average file processing time")
        metrics_output.append(f"# TYPE etl_avg_processing_time_seconds gauge")
        metrics_output.append(f"etl_avg_processing_time_seconds {self.metrics['avg_processing_time']}")
        metrics_output.append("")
        
        # Uptime
        metrics_output.append(f"# HELP etl_uptime_seconds ETL process uptime in seconds")
        metrics_output.append(f"# TYPE etl_uptime_seconds gauge")
        metrics_output.append(f"etl_uptime_seconds {self.metrics['uptime_seconds']}")
        metrics_output.append("")
        
        # Time since last success
        metrics_output.append(f"# HELP etl_seconds_since_last_success Seconds since last successful file processing")
        metrics_output.append(f"# TYPE etl_seconds_since_last_success gauge")
        metrics_output.append(f"etl_seconds_since_last_success {self.metrics['seconds_since_last_success']}")
        metrics_output.append("")
        
        # Time since last failure
        metrics_output.append(f"# HELP etl_seconds_since_last_failure Seconds since last failure")
        metrics_output.append(f"# TYPE etl_seconds_since_last_failure gauge")
        if self.metrics['seconds_since_last_failure'] != float('inf'):
            metrics_output.append(f"etl_seconds_since_last_failure {self.metrics['seconds_since_last_failure']}")
        else:
            metrics_output.append(f"etl_seconds_since_last_failure 999999")  # Large number for "never"
        metrics_output.append("")
        
        # Error types
        if self.metrics['error_types']:
            metrics_output.append(f"# HELP etl_errors_by_type_total Number of errors by type")
            metrics_output.append(f"# TYPE etl_errors_by_type_total counter")
            for error_type, count in self.metrics['error_types'].items():
                metrics_output.append(f'etl_errors_by_type_total{{error_type="{error_type}"}} {count}')
            metrics_output.append("")
        
        # Health indicator (1 if recently active, 0 if stale)
        current_time = time.time()
        last_update = self.metrics['last_update']
        is_healthy = 1 if (current_time - last_update) < 300 else 0  # 5 minutes
        
        metrics_output.append(f"# HELP etl_health_status ETL process health (1=healthy, 0=stale)")
        metrics_output.append(f"# TYPE etl_health_status gauge")
        metrics_output.append(f"etl_health_status {is_healthy}")
        metrics_output.append("")
        
        return "\n".join(metrics_output)

class MetricsHTTPHandler(BaseHTTPRequestHandler):
    def __init__(self, metrics_collector, *args, **kwargs):
        self.metrics_collector = metrics_collector
        super().__init__(*args, **kwargs)
    
    def do_GET(self):
        if self.path == '/metrics':
            self.send_response(200)
            self.send_header('Content-type', 'text/plain; version=0.0.4; charset=utf-8')
            self.end_headers()
            
            metrics = self.metrics_collector.generate_prometheus_metrics()
            self.wfile.write(metrics.encode('utf-8'))
            
        elif self.path == '/health':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            
            health_data = {
                'status': 'healthy',
                'uptime': self.metrics_collector.metrics['uptime_seconds'],
                'last_update': self.metrics_collector.metrics['last_update'],
                'total_records': self.metrics_collector.metrics['total_records'],
                'total_files': self.metrics_collector.metrics['total_files'],
                'total_failures': self.metrics_collector.metrics['total_failures']
            }
            
            self.wfile.write(json.dumps(health_data, indent=2).encode('utf-8'))
        else:
            self.send_response(404)
            self.end_headers()
    
    def log_message(self, format, *args):
        # Suppress default HTTP server logging
        pass

def create_handler(metrics_collector):
    def handler(*args, **kwargs):
        return MetricsHTTPHandler(metrics_collector, *args, **kwargs)
    return handler

def signal_handler(sig, frame):
    """Handle shutdown signals gracefully"""
    print("\nShutting down metrics exporter...")
    sys.exit(0)

if __name__ == "__main__":
    # Setup signal handlers
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    print("Starting ETL Metrics Exporter...")
    print("Metrics endpoint: http://localhost:8083/metrics")
    print("Health endpoint: http://localhost:8083/health")
    print("Press Ctrl+C to stop")
    print("-" * 50)
    
    # Create metrics collector
    collector = ETLMetricsCollector()
    
    # Create HTTP server
    handler = create_handler(collector)
    server = HTTPServer(('0.0.0.0', 8083), handler)
    
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down server...")
        server.shutdown()