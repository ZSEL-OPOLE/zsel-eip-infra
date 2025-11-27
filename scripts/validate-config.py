#!/usr/bin/env python3
"""
Validation Script - Check vlans-master.yaml for common errors
"""

import yaml
import sys
from pathlib import Path
from typing import Dict, List, Set

def validate_yaml_syntax(file_path: Path) -> bool:
    """Validate YAML syntax"""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            yaml.safe_load(f)
        print("✅ YAML syntax valid")
        return True
    except yaml.YAMLError as e:
        print(f"❌ YAML syntax error: {e}")
        return False

def validate_vlan_ids(config: Dict) -> List[str]:
    """Check for VLAN ID conflicts and invalid ranges"""
    errors = []
    vlan_ids: Set[int] = set()
    
    # Collect all VLAN IDs
    for floor, data in config['vlans']['dydactic'].items():
        vlan_id = data['vlan_id']
        if vlan_id in vlan_ids:
            errors.append(f"Duplicate VLAN ID: {vlan_id} in dydactic.{floor}")
        vlan_ids.add(vlan_id)
    
    vlan_ids.add(config['vlans']['tv']['vlan_id'])
    
    for lab in config['vlans']['labs']:
        vlan_id = lab['vlan_id']
        if vlan_id in vlan_ids:
            errors.append(f"Duplicate VLAN ID: {vlan_id} for sala {lab['sala']}")
        vlan_ids.add(vlan_id)
        
        # Check if VLAN matches room number pattern
        expected_vlan = 200 + lab['sala']
        if vlan_id != expected_vlan:
            errors.append(f"⚠️  WARNING: VLAN {vlan_id} for sala {lab['sala']} (expected {expected_vlan})")
    
    for wifi in config['vlans']['wifi']:
        vlan_id = wifi['vlan_id']
        if vlan_id in vlan_ids:
            errors.append(f"Duplicate VLAN ID: {vlan_id} in wifi.{wifi['floor']}")
        vlan_ids.add(vlan_id)
    
    for server in config['vlans']['servers']:
        vlan_id = server['vlan_id']
        if vlan_id in vlan_ids:
            errors.append(f"Duplicate VLAN ID: {vlan_id}")
        vlan_ids.add(vlan_id)
    
    vlan_ids.add(config['vlans']['admin']['vlan_id'])
    vlan_ids.add(config['vlans']['cctv']['vlan_id'])
    vlan_ids.add(config['vlans']['management']['vlan_id'])
    
    if not errors:
        print(f"✅ VLAN IDs valid: {len(vlan_ids)} unique VLANs")
    
    return errors

def validate_subnets(config: Dict) -> List[str]:
    """Check for subnet overlaps"""
    errors = []
    subnets: Dict[str, str] = {}
    
    # Collect all subnets
    for floor, data in config['vlans']['dydactic'].items():
        subnet = data['subnet']
        if subnet in subnets:
            errors.append(f"Duplicate subnet {subnet}: dydactic.{floor} and {subnets[subnet]}")
        subnets[subnet] = f"dydactic.{floor}"
    
    subnets[config['vlans']['tv']['subnet']] = "tv"
    
    for lab in config['vlans']['labs']:
        subnet = lab['subnet']
        sala = lab['sala']
        if subnet in subnets:
            errors.append(f"Duplicate subnet {subnet}: sala {sala} and {subnets[subnet]}")
        subnets[subnet] = f"lab-{sala}"
        
        # Check if subnet matches room number
        expected_subnet = f"10.{sala}.0.0/16"
        if subnet != expected_subnet:
            errors.append(f"⚠️  WARNING: Sala {sala} has subnet {subnet} (expected {expected_subnet})")
    
    for wifi in config['vlans']['wifi']:
        subnet = wifi['subnet']
        if subnet in subnets:
            errors.append(f"Duplicate subnet {subnet}: wifi.{wifi['floor']} and {subnets[subnet]}")
        subnets[subnet] = f"wifi.{wifi['floor']}"
    
    if not errors:
        print(f"✅ Subnets valid: {len(subnets)} unique subnets")
    
    return errors

def validate_qos(config: Dict) -> List[str]:
    """Validate QoS configuration"""
    errors = []
    
    required_policies = ['labs', 'dydactic', 'wifi', 'admin', 'management', 'cctv']
    for policy in required_policies:
        if policy not in config['qos_policies']:
            errors.append(f"Missing QoS policy: {policy}")
    
    # Check labs QoS has burst settings
    labs_qos = config['qos_policies'].get('labs', {})
    if 'burst_limit' not in labs_qos:
        errors.append("Labs QoS missing burst_limit (required by PFU 2.7)")
    if 'burst_time' not in labs_qos:
        errors.append("Labs QoS missing burst_time (required by PFU 2.7)")
    
    if not errors:
        print(f"✅ QoS policies valid: {len(config['qos_policies'])} policies")
    
    return errors

def validate_bgp(config: Dict) -> List[str]:
    """Validate BGP configuration"""
    errors = []
    
    if 'bgp' not in config:
        errors.append("Missing BGP configuration")
        return errors
    
    bgp = config['bgp']
    
    if 'instance' not in bgp:
        errors.append("Missing BGP instance")
    elif 'as' not in bgp['instance']:
        errors.append("Missing BGP AS number")
    
    if 'peers' not in bgp or len(bgp['peers']) == 0:
        errors.append("No BGP peers configured")
    else:
        for peer in bgp['peers']:
            if 'remote_address' not in peer:
                errors.append(f"BGP peer {peer.get('name', 'unknown')} missing remote_address")
            if 'remote_as' not in peer:
                errors.append(f"BGP peer {peer.get('name', 'unknown')} missing remote_as")
    
    if not errors:
        print(f"✅ BGP configuration valid: {len(bgp.get('peers', []))} peers")
    
    return errors

def validate_pfu_compliance(config: Dict) -> List[str]:
    """Check PFU 2.7 compliance"""
    warnings = []
    
    # Check number of labs (should be 15: 8,9,23-31,41-46)
    labs = config['vlans']['labs']
    if len(labs) != 15:
        warnings.append(f"⚠️  Expected 15 labs (PFU 2.7), found {len(labs)}")
    
    # Check labs QoS (should be 60M/60M)
    labs_qos = config['qos_policies']['labs']
    if labs_qos.get('max_limit') != '60M/60M':
        warnings.append(f"⚠️  Labs QoS is {labs_qos.get('max_limit')}, PFU 2.7 requires 60M/60M")
    
    # Check dydactic QoS (should be 1000M/1000M)
    dyd_qos = config['qos_policies']['dydactic']
    if dyd_qos.get('max_limit') != '1000M/1000M':
        warnings.append(f"⚠️  Dydactic QoS is {dyd_qos.get('max_limit')}, PFU 2.7 requires 1000M/1000M")
    
    # Check WiFi QoS (should be 200M/200M)
    wifi_qos = config['qos_policies']['wifi']
    if wifi_qos.get('max_limit') != '200M/200M':
        warnings.append(f"⚠️  WiFi QoS is {wifi_qos.get('max_limit')}, PFU 2.7 requires 200M/200M")
    
    if not warnings:
        print("✅ PFU 2.7 compliance: OK")
    
    return warnings

def main():
    script_dir = Path(__file__).parent
    workspace_root = script_dir.parent
    yaml_file = workspace_root / 'common' / 'vlans-master.yaml'
    
    print("="*70)
    print("VALIDATING: vlans-master.yaml")
    print("="*70)
    
    if not yaml_file.exists():
        print(f"❌ File not found: {yaml_file}")
        sys.exit(1)
    
    # Validate YAML syntax
    if not validate_yaml_syntax(yaml_file):
        sys.exit(1)
    
    # Load config
    with open(yaml_file, 'r', encoding='utf-8') as f:
        config = yaml.safe_load(f)
    
    print()
    
    # Run validations
    all_errors = []
    all_warnings = []
    
    all_errors.extend(validate_vlan_ids(config))
    all_errors.extend(validate_subnets(config))
    all_errors.extend(validate_qos(config))
    all_errors.extend(validate_bgp(config))
    all_warnings.extend(validate_pfu_compliance(config))
    
    # Print results
    print()
    print("="*70)
    
    if all_errors:
        print(f"❌ VALIDATION FAILED: {len(all_errors)} errors")
        print("="*70)
        for error in all_errors:
            print(f"  {error}")
        sys.exit(1)
    
    if all_warnings:
        print(f"⚠️  WARNINGS: {len(all_warnings)}")
        print("="*70)
        for warning in all_warnings:
            print(f"  {warning}")
    
    if not all_errors and not all_warnings:
        print("✅ ALL VALIDATIONS PASSED")
        print("="*70)
        print(f"VLANs: {len(config['vlans']['dydactic']) + 1 + len(config['vlans']['labs']) + len(config['vlans']['wifi']) + len(config['vlans']['servers']) + 3}")
        print(f"Labs: {len(config['vlans']['labs'])}")
        print(f"QoS Policies: {len(config['qos_policies'])}")
        print(f"BGP Peers: {len(config['bgp']['peers'])}")
        print("="*70)
        print("Ready to generate Terraform configuration!")
    
    sys.exit(0 if not all_errors else 1)

if __name__ == '__main__':
    main()
