#!/usr/bin/env python3
"""
ETL Simulator And Prometheus data provider with HTTP Basic Authentication
To be run on laptop, not in container
Simulates file processing with controlled failure rates
Processes approximately 20 records per second with failures every ~120 seconds
"""

import time
import random
import logging
import json
import os
from datetime import datetime
from pathlib import Path
import signal
import sys
import base64
from http.server import HTTPServer, BaseHTTPRequestHandler
import threading
from dotenv import load_dotenv

from prometheus_client import Counter, Gauge, Histogram, generate_latest, CONTENT_TYPE_LATEST
# import prometheus_client

# Prometheus metrics
FILES_PROCESSED = Counter('etl_files_processed_total', 'Total processed files', ['status'])
RECORDS_PROCESSED = Counter('etl_records_processed_total', 'Total processed records')
FAILURES = Counter('etl_failures_total', 'Total failures')
# Custom buckets for ETL processing times: 50-500 records at 20 rps = 2.5-25 seconds + variance
PROCESSING_TIME = Histogram(
    'etl_processing_duration_seconds', 
    'File processing duration seconds',
    buckets=[1, 2, 3, 5, 7, 10, 12, 15, 18, 20, 25, 30, 35, 40, 50]
)
IN_PROGRESS = Gauge('etl_processing_in_progress', 'Files being processed')

load_dotenv(".env.secure")

# Authentication credentials (in production, use environment variables or config files)
AUTH_USERNAME = os.environ.get('METRICS_USERNAME', '')
AUTH_PASSWORD = os.environ.get('METRICS_PASSWORD', '')

class SecureMetricsHandler(BaseHTTPRequestHandler):
    """HTTP handler with Basic Authentication for metrics endpoint"""
    
    def _authenticate(self):
        """Check HTTP Basic Authentication"""
        auth_header = self.headers.get('Authorization')
        if not auth_header:
            return False
            
        try:
            auth_type, auth_string = auth_header.split(' ', 1)
            if auth_type.lower() != 'basic':
                return False
                
            auth_bytes = base64.b64decode(auth_string)
            auth_str = auth_bytes.decode('utf-8')
            username, password = auth_str.split(':', 1)
            
            return username == AUTH_USERNAME and password == AUTH_PASSWORD
        except Exception:
            return False
    
    def _send_unauthorized(self):
        """Send 401 Unauthorized response"""
        self.send_response(401)
        self.send_header('WWW-Authenticate', 'Basic realm="Prometheus Metrics"')
        self.send_header('Content-type', 'text/plain')
        self.end_headers()
        self.wfile.write(b'401 Unauthorized - Authentication required')
    
    def do_GET(self):
        """Handle GET requests"""
        if self.path == '/metrics':
            if not self._authenticate():
                self._send_unauthorized()
                return
                
            # Generate Prometheus metrics
            metrics_data = generate_latest()
            
            self.send_response(200)
            self.send_header('Content-Type', CONTENT_TYPE_LATEST)
            self.send_header('Content-Length', str(len(metrics_data)))
            self.end_headers()
            self.wfile.write(metrics_data)
            
        elif self.path == '/health':
            # Health check endpoint (no auth required)
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            health_data = json.dumps({"status": "healthy", "timestamp": datetime.utcnow().isoformat()})
            self.wfile.write(health_data.encode())
            
        else:
            self.send_response(404)
            self.send_header('Content-Type', 'text/plain')
            self.end_headers()
            self.wfile.write(b'404 Not Found')
    
    def log_message(self, format, *args):
        """Override to reduce log noise"""
        pass

class ETLSimulator:
    def __init__(self, log_file=None):
        if log_file is None:
            log_file = os.environ.get('LOG_FILE', 'etl_process.log')
        self.log_file = Path(log_file)
        self.records_per_second = 20
        self.failure_interval = 120  # seconds between failures
        self.running = False
        self.last_failure = 0
        self.total_records_processed = 0
        self.total_files_processed = 0
        self.total_failures = 0
        
        # Setup logging
        self.setup_logging()
        
    def setup_logging(self):
        """Configure structured logging for ETL process"""
        # Create formatter for structured logs
        formatter = logging.Formatter(
            '%(asctime)s %(levelname)s %(message)s',
            datefmt='%Y-%m-%dT%H:%M:%S'
        )
        
        # Console handler
        console_handler = logging.StreamHandler()
        console_handler.setFormatter(formatter)
        
        # Setup logger
        self.logger = logging.getLogger('etl_simulator')
        self.logger.setLevel(logging.INFO)
        self.logger.addHandler(console_handler)
        
        # Prevent duplicate logs
        self.logger.propagate = False
        
    def log_structured(self, level, message, **kwargs):
        """Log structured data that can be parsed by monitoring systems"""
        log_data = {
            'timestamp': datetime.utcnow().isoformat() + 'Z',
            'message': message,
            'total_records': self.total_records_processed,
            'total_files': self.total_files_processed,
            'total_failures': self.total_failures,
            **kwargs
        }
        
        # Log as JSON for easy parsing
        getattr(self.logger, level)(json.dumps(log_data))
    
    def simulate_file_processing(self):
        """Simulate processing a single file"""
        current_time = time.time()
        
        # Determine if this should be a failure
        should_fail = (
            current_time - self.last_failure > self.failure_interval and
            random.random() < 0.1  # 10% chance when in failure window
        )

        IN_PROGRESS.inc()
        start = time.time()
        # measure processing time with the histogram context manager
        with PROCESSING_TIME.time():
            try:
                if should_fail:
                    self.simulate_failure()
                    self.last_failure = current_time
                    FILES_PROCESSED.labels(status='failed').inc()
                    FAILURES.inc()
                    return

                # Simulate successful processing
                records_in_file = random.randint(50, 500)  # Vary file sizes
                processing_time = records_in_file / self.records_per_second
        
                self.log_structured('info', 'file_processing_started',
                                  file_id=f"file_{self.total_files_processed + 1:06d}",
                                  expected_records=records_in_file,
                                  estimated_duration=round(processing_time, 2))
        
                # Simulate processing time with some variance
                actual_time = processing_time * random.uniform(0.8, 1.2)
                time.sleep(actual_time)
        
                # Success
                self.total_records_processed += records_in_file
                self.total_files_processed += 1

                RECORDS_PROCESSED.inc(records_in_file)
                FILES_PROCESSED.labels(status='success').inc()

                self.log_structured('info', 'file_processing_completed',
                                  file_id=f"file_{self.total_files_processed:06d}",
                                  records_processed=records_in_file,
                                  processing_time=round(actual_time, 2),
                                  current_rate=round(records_in_file / actual_time, 2))
            finally:
                IN_PROGRESS.dec()

        
    def simulate_failure(self):
        """Simulate a processing failure"""
        failure_reasons = [
            'connection_timeout',
            'corrupt_file_format',
            'disk_space_insufficient',
            'database_lock_timeout',
            'invalid_data_schema'
        ]
        
        failure_reason = random.choice(failure_reasons)
        self.total_failures += 1
        
        self.log_structured('error', 'file_processing_failed',
                          file_id=f"file_{self.total_files_processed + 1:06d}_FAILED",
                          failure_reason=failure_reason,
                          retry_after=random.randint(30, 120))
        
        # Simulate failure recovery time
        time.sleep(random.uniform(5, 15))
        
    def run(self):
        """Main processing loop"""
        self.running = True
        self.log_structured('info', 'etl_simulator_started',
                          target_rate=f"{self.records_per_second} records/sec",
                          failure_interval=f"{self.failure_interval} seconds")
        
        try:
            while self.running:
                self.simulate_file_processing()
                
                # Brief pause between files
                time.sleep(random.uniform(1, 5))
                
        except KeyboardInterrupt:
            self.stop()
        except Exception as e:
            self.log_structured('error', 'etl_simulator_crashed',
                              error=str(e),
                              error_type=type(e).__name__)
            raise
    
    def stop(self):
        """Stop the ETL simulator gracefully"""
        self.running = False
        self.log_structured('info', 'etl_simulator_stopped',
                          final_stats={
                              'total_records': self.total_records_processed,
                              'total_files': self.total_files_processed,
                              'total_failures': self.total_failures,
                              'uptime_seconds': time.time() - start_time if 'start_time' in globals() else 0
                          })

def start_secure_metrics_server(port=8000):
    """Start HTTP server with authentication for metrics"""
    server = HTTPServer(('localhost', port), SecureMetricsHandler)
    thread = threading.Thread(target=server.serve_forever)
    thread.daemon = True
    thread.start()
    return server

def signal_handler(sig, frame):
    """Handle shutdown signals gracefully"""
    print("\nShutting down ETL simulator...")
    if 'simulator' in globals():
        simulator.stop()
    if 'metrics_server' in globals():
        metrics_server.shutdown()
    sys.exit(0)

if __name__ == "__main__":
    # Setup signal handlers
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)

    # Start secure Prometheus metrics server
    metrics_server = start_secure_metrics_server(8000)
    
    start_time = time.time()
    
    print("Starting SECURE ETL Simulator with authentication...")
    print("Target rate: 20 records/second")
    print("Failure simulation: ~1 failure per 2 minutes")
    print("Metrics exposed at http://localhost:8000/metrics (Basic Auth required)")
    print("Health check at http://localhost:8000/health (no auth)")
    print(f"Username: {AUTH_USERNAME}")
    print(f"Password: {AUTH_PASSWORD}")
    print("Press Ctrl+C to stop")
    print("-" * 50)
    
    simulator = ETLSimulator()
    simulator.run()