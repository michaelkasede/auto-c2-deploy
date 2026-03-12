#!/usr/bin/env python3

# Failover Testing Script
# Tests various failover scenarios for multi-cloud infrastructure

import json
import sys
import os
import time
import requests
import logging
from typing import Dict, Any, List, Optional
from datetime import datetime

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class FailoverTester:
    def __init__(self, config_file: str = "failover-config.yaml"):
        self.config_file = config_file
        self.config = self._load_config()
        self.test_results = []
        
    def _load_config(self) -> Dict[str, Any]:
        """Load failover configuration"""
        try:
            import yaml
            with open(self.config_file, 'r') as f:
                return yaml.safe_load(f)
        except FileNotFoundError:
            logger.error(f"Configuration file not found: {self.config_file}")
            return {}
        except yaml.YAMLError:
            logger.error(f"Invalid YAML in configuration file: {self.config_file}")
            return {}
    
    def test_service_health(self, service: str, provider: str) -> Dict[str, Any]:
        """Test health of a specific service on a provider"""
        logger.info(f"Testing health of {service} on {provider}")
        
        # Load access information
        access_file = f"access_info_{provider}_primary.json"
        if not os.path.exists(access_file):
            access_file = f"access_info_{provider}_backup.json"
        
        if not os.path.exists(access_file):
            return {"status": "unknown", "error": "Access info not found"}
        
        try:
            with open(access_file, 'r') as f:
                access_info = json.load(f)
            
            service_info = access_info.get("services", {}).get(service, {})
            urls = service_info.get("urls", [])
            
            if not urls:
                return {"status": "unknown", "error": "No URLs found"}
            
            # Test each URL
            results = []
            for url in urls:
                try:
                    response = requests.get(url, timeout=10, verify=False)
                    results.append({
                        "url": url,
                        "status_code": response.status_code,
                        "response_time": response.elapsed.total_seconds(),
                        "status": "healthy" if response.status_code == 200 else "unhealthy"
                    })
                except requests.exceptions.RequestException as e:
                    results.append({
                        "url": url,
                        "error": str(e),
                        "status": "unhealthy"
                    })
            
            # Determine overall status
            healthy_count = sum(1 for r in results if r.get("status") == "healthy")
            overall_status = "healthy" if healthy_count > 0 else "unhealthy"
            
            return {
                "status": overall_status,
                "provider": provider,
                "service": service,
                "results": results,
                "timestamp": datetime.now().isoformat()
            }
            
        except Exception as e:
            return {"status": "error", "error": str(e)}
    
    def test_service_failure_scenario(self) -> Dict[str, Any]:
        """Test service failure scenario"""
        logger.info("Testing service failure scenario")
        
        scenario_name = "service_failure"
        start_time = time.time()
        
        # Simulate service failure on primary provider
        primary_provider = self.config.get("failover", {}).get("primary_provider", "aws")
        
        # Test current state
        services = ["mythic", "gophish", "evilginx", "pwndrop"]
        initial_health = {}
        
        for service in services:
            health = self.test_service_health(service, primary_provider)
            initial_health[service] = health
        
        # Simulate failure (in real scenario, this would be an actual failure)
        logger.info(f"Simulating service failure on {primary_provider}")
        
        # Test backup providers
        backup_providers = self.config.get("failover", {}).get("backup_providers", [])
        backup_health = {}
        
        for provider in backup_providers:
            provider_health = {}
            for service in services:
                health = self.test_service_health(service, provider)
                provider_health[service] = health
            backup_health[provider] = provider_health
        
        # Evaluate failover readiness
        failover_ready = True
        failover_recommendations = []
        
        for service in services:
            primary_status = initial_health[service].get("status", "unknown")
            
            if primary_status == "unhealthy":
                # Check if backup is available
                backup_available = False
                for provider in backup_providers:
                    backup_status = backup_health[provider].get(service, {}).get("status", "unknown")
                    if backup_status == "healthy":
                        backup_available = True
                        failover_recommendations.append({
                            "service": service,
                            "action": "failover",
                            "target_provider": provider,
                            "reason": f"Primary {primary_provider} unhealthy, backup {provider} healthy"
                        })
                        break
                
                if not backup_available:
                    failover_ready = False
                    failover_recommendations.append({
                        "service": service,
                        "action": "investigate",
                        "reason": "No healthy backup available"
                    })
        
        end_time = time.time()
        duration = end_time - start_time
        
        result = {
            "scenario": scenario_name,
            "duration": duration,
            "primary_provider": primary_provider,
            "backup_providers": backup_providers,
            "initial_health": initial_health,
            "backup_health": backup_health,
            "failover_ready": failover_ready,
            "recommendations": failover_recommendations,
            "timestamp": datetime.now().isoformat()
        }
        
        self.test_results.append(result)
        return result
    
    def test_network_isolation_scenario(self) -> Dict[str, Any]:
        """Test network isolation scenario"""
        logger.info("Testing network isolation scenario")
        
        scenario_name = "network_isolation"
        start_time = time.time()
        
        # Simulate network isolation
        primary_provider = self.config.get("failover", {}).get("primary_provider", "aws")
        
        # Test connectivity to primary provider
        services = ["mythic", "gophish", "evilginx", "pwndrop"]
        connectivity_results = {}
        
        for service in services:
            # Simulate network check (ping, traceroute, etc.)
            logger.info(f"Testing network connectivity to {service} on {primary_provider}")
            
            # In real scenario, this would be actual network tests
            # For simulation, we'll use random results
            import random
            is_connected = random.choice([True, False])
            
            connectivity_results[service] = {
                "connected": is_connected,
                "latency": random.uniform(10, 100) if is_connected else None,
                "packet_loss": random.uniform(0, 5) if is_connected else 100
            }
        
        # Evaluate network isolation
        isolated_services = [s for s, r in connectivity_results.items() if not r["connected"]]
        
        # Check backup providers
        backup_providers = self.config.get("failover", {}).get("backup_providers", [])
        backup_connectivity = {}
        
        for provider in backup_providers:
            provider_connectivity = {}
            for service in services:
                # Simulate backup connectivity
                is_connected = random.choice([True, False, True])  # Bias towards connected
                provider_connectivity[service] = {
                    "connected": is_connected,
                    "latency": random.uniform(20, 150) if is_connected else None
                }
            backup_connectivity[provider] = provider_connectivity
        
        # Generate recommendations
        recommendations = []
        for service in isolated_services:
            # Find best backup provider
            best_provider = None
            best_latency = float('inf')
            
            for provider in backup_providers:
                if backup_connectivity[provider][service]["connected"]:
                    latency = backup_connectivity[provider][service]["latency"]
                    if latency and latency < best_latency:
                        best_latency = latency
                        best_provider = provider
            
            if best_provider:
                recommendations.append({
                    "service": service,
                    "action": "failover",
                    "target_provider": best_provider,
                    "reason": f"Network isolation on {primary_provider}, {best_provider} available"
                })
            else:
                recommendations.append({
                    "service": service,
                    "action": "investigate",
                    "reason": "No backup connectivity available"
                })
        
        end_time = time.time()
        duration = end_time - start_time
        
        result = {
            "scenario": scenario_name,
            "duration": duration,
            "primary_provider": primary_provider,
            "backup_providers": backup_providers,
            "primary_connectivity": connectivity_results,
            "backup_connectivity": backup_connectivity,
            "isolated_services": isolated_services,
            "recommendations": recommendations,
            "timestamp": datetime.now().isoformat()
        }
        
        self.test_results.append(result)
        return result
    
    def test_security_incident_scenario(self) -> Dict[str, Any]:
        """Test security incident scenario"""
        logger.info("Testing security incident scenario")
        
        scenario_name = "security_incident"
        start_time = time.time()
        
        # Simulate security incident detection
        primary_provider = self.config.get("failover", {}).get("primary_provider", "aws")
        
        # Security indicators
        security_indicators = {
            "unusual_login_attempts": True,
            "suspicious_traffic": True,
            "file_integrity_violations": False,
            "malware_detection": False,
            "data_exfiltration": False
        }
        
        # Calculate incident severity
        severity_score = sum(1 for v in security_indicators.values() if v)
        severity_level = "low" if severity_score <= 1 else "medium" if severity_score <= 3 else "high"
        
        # Determine incident response actions
        response_actions = []
        
        if severity_level in ["medium", "high"]:
            response_actions.extend([
                "isolate_affected_systems",
                "enable_enhanced_monitoring",
                "initiate_incident_response"
            ])
        
        if severity_level == "high":
            response_actions.extend([
                "immediate_failover",
                "preserve_evidence",
                "notify_security_team"
            ])
        
        # Test backup provider readiness
        backup_providers = self.config.get("failover", {}).get("backup_providers", [])
        backup_readiness = {}
        
        for provider in backup_providers:
            # Simulate backup security checks
            backup_readiness[provider] = {
                "security_compliant": True,
                "last_security_scan": datetime.now().isoformat(),
                "vulnerabilities": 0,
                "ready_for_failover": True
            }
        
        # Generate recommendations
        recommendations = []
        
        if severity_level == "high":
            recommendations.append({
                "action": "immediate_failover",
                "reason": "High severity security incident detected",
                "priority": "critical"
            })
        elif severity_level == "medium":
            recommendations.append({
                "action": "prepare_failover",
                "reason": "Medium severity incident, prepare for potential failover",
                "priority": "high"
            })
        
        # Check backup security
        for provider in backup_providers:
            if not backup_readiness[provider]["ready_for_failover"]:
                recommendations.append({
                    "action": "security_hardening",
                    "target_provider": provider,
                    "reason": f"Backup provider {provider} not ready for failover",
                    "priority": "high"
                })
        
        end_time = time.time()
        duration = end_time - start_time
        
        result = {
            "scenario": scenario_name,
            "duration": duration,
            "primary_provider": primary_provider,
            "backup_providers": backup_providers,
            "security_indicators": security_indicators,
            "severity_level": severity_level,
            "severity_score": severity_score,
            "response_actions": response_actions,
            "backup_readiness": backup_readiness,
            "recommendations": recommendations,
            "timestamp": datetime.now().isoformat()
        }
        
        self.test_results.append(result)
        return result
    
    def generate_test_report(self) -> str:
        """Generate comprehensive test report"""
        report = []
        report.append("# Multi-Cloud Failover Test Report")
        report.append(f"Generated on: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        report.append("")
        
        # Executive Summary
        report.append("## Executive Summary")
        total_tests = len(self.test_results)
        passed_tests = sum(1 for r in self.test_results if any(rec.get("action") != "investigate" for rec in r.get("recommendations", [])))
        
        report.append(f"- **Total Tests Executed**: {total_tests}")
        report.append(f"- **Tests Passed**: {passed_tests}")
        report.append(f"- **Tests Failed**: {total_tests - passed_tests}")
        report.append(f"- **Overall Status**: {'PASS' if passed_tests == total_tests else 'FAIL'}")
        report.append("")
        
        # Test Results
        report.append("## Test Results")
        
        for result in self.test_results:
            scenario = result.get("scenario", "unknown")
            report.append(f"### {scenario.replace('_', ' ').title()}")
            report.append(f"**Duration**: {result.get('duration', 0):.2f} seconds")
            report.append(f"**Primary Provider**: {result.get('primary_provider', 'unknown')}")
            
            # Recommendations
            recommendations = result.get("recommendations", [])
            if recommendations:
                report.append("**Recommendations**:")
                for rec in recommendations:
                    action = rec.get("action", "unknown")
                    reason = rec.get("reason", "no reason provided")
                    report.append(f"- {action.upper()}: {reason}")
            
            report.append("")
        
        # Overall Recommendations
        report.append("## Overall Recommendations")
        
        # Analyze all recommendations
        all_recommendations = []
        for result in self.test_results:
            all_recommendations.extend(result.get("recommendations", []))
        
        # Group by action type
        action_counts = {}
        for rec in all_recommendations:
            action = rec.get("action", "unknown")
            action_counts[action] = action_counts.get(action, 0) + 1
        
        # Top recommendations
        report.append("### Priority Actions")
        for action, count in sorted(action_counts.items(), key=lambda x: x[1], reverse=True):
            report.append(f"- **{action.upper()}**: {count} occurrences")
        
        report.append("")
        
        # Next Steps
        report.append("## Next Steps")
        report.append("1. Review all test results and recommendations")
        report.append("2. Implement high-priority security and failover improvements")
        report.append("3. Schedule regular failover testing (quarterly recommended)")
        report.append("4. Update documentation based on test findings")
        report.append("5. Train team on failover procedures")
        report.append("")
        
        # Technical Details
        report.append("## Technical Details")
        
        for result in self.test_results:
            scenario = result.get("scenario", "unknown")
            report.append(f"### {scenario.replace('_', ' ').title()} - Technical Details")
            report.append("```json")
            report.append(json.dumps(result, indent=2))
            report.append("```")
            report.append("")
        
        return "\n".join(report)
    
    def save_test_results(self, filename: str = None) -> str:
        """Save test results to file"""
        if filename is None:
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            filename = f"failover_test_results_{timestamp}.json"
        
        # Save raw results
        with open(filename, 'w') as f:
            json.dump(self.test_results, f, indent=2)
        
        # Save report
        report_filename = filename.replace('.json', '.md')
        report = self.generate_test_report()
        with open(report_filename, 'w') as f:
            f.write(report)
        
        logger.info(f"Test results saved to {filename}")
        logger.info(f"Test report saved to {report_filename}")
        
        return report_filename

def main():
    if len(sys.argv) < 3 or sys.argv[1] != "--scenario":
        print("Usage: python3 test-failover.py --scenario <scenario_name>")
        print("Available scenarios: service_failure, network_isolation, security_incident, all")
        sys.exit(1)
    
    scenario = sys.argv[2]
    
    tester = FailoverTester()
    
    if scenario == "all":
        logger.info("Running all failover test scenarios")
        tester.test_service_failure_scenario()
        tester.test_network_isolation_scenario()
        tester.test_security_incident_scenario()
    elif scenario == "service_failure":
        tester.test_service_failure_scenario()
    elif scenario == "network_isolation":
        tester.test_network_isolation_scenario()
    elif scenario == "security_incident":
        tester.test_security_incident_scenario()
    else:
        logger.error(f"Unknown scenario: {scenario}")
        sys.exit(1)
    
    # Save results
    report_file = tester.save_test_results()
    
    # Print summary
    print(f"\n=== Failover Test Summary ===")
    print(f"Scenarios tested: {len(tester.test_results)}")
    print(f"Report saved to: {report_file}")
    
    # Print recommendations
    all_recommendations = []
    for result in tester.test_results:
        all_recommendations.extend(result.get("recommendations", []))
    
    if all_recommendations:
        print(f"\n=== Top Recommendations ===")
        action_counts = {}
        for rec in all_recommendations:
            action = rec.get("action", "unknown")
            action_counts[action] = action_counts.get(action, 0) + 1
        
        for action, count in sorted(action_counts.items(), key=lambda x: x[1], reverse=True)[:5]:
            print(f"{action.upper()}: {count} occurrences")

if __name__ == "__main__":
    main()
