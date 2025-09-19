#!/usr/bin/env python3
"""
ETL Simulator And Prometheus data provider
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

from prometheus_client import Counter, Gauge, Histogram, start_http_server
import prometheus_client

# Prometheus metrics
FILES_PROCESSED = Counter('etl_files_processed_total', 'Total processed files', ['status'])
RECORDS_PROCESSED = Counter('etl_records_processed_total', 'Total processed records')
FAILURES = Counter('etl_failures_total', 'Total failures')
PROCESSING_TIME = Histogram('etl_processing_duration_seconds', 'File processing duration seconds')
IN_PROGRESS = Gauge('etl_processing_in_progress', 'Files being processed')

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
        
        # File handler - no need for file logging in this version
        #file_handler = logging.FileHandler(self.log_file)
        #file_handler.setFormatter(formatter)
        
        # Console handler
        console_handler = logging.StreamHandler()
        console_handler.setFormatter(formatter)
        
        # Setup logger
        self.logger = logging.getLogger('etl_simulator')
        self.logger.setLevel(logging.INFO)
        # self.logger.addHandler(file_handler)
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

def signal_handler(sig, frame):
    """Handle shutdown signals gracefully"""
    print("\nShutting down ETL simulator...")
    if 'simulator' in globals():
        simulator.stop()
    sys.exit(0)

if __name__ == "__main__":
    # Setup signal handlers
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)

    # Start Prometheus metrics server (scrape at http://localhost:8000/metrics)
    start_http_server(8000)
    
    start_time = time.time()
    
    print("Starting ETL Simulator with direct Prometheus access...")
    print("Target rate: 20 records/second")
    print("Failure simulation: ~1 failure per 2 minutes")
    print("Metrics exposed at http://localhost:8000/metrics")
    print("Press Ctrl+C to stop")
    print("-" * 50)
    
    simulator = ETLSimulator()
    simulator.run()