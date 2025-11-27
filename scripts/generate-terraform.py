#!/usr/bin/env python3
"""
Terraform Configuration Generator - PFU 2.7 Compliant
Generates prod-values-generated.auto.tfvars from vlans-master.yaml
Based on ACTUAL PFU 2.7 room structure (VLAN 208-246 = physical rooms, NOT class names!)
"""

import yaml
from pathlib import Path
from typing import Dict, List

def load_yaml(file_path: str) -> Dict:
    """Load YAML configuration"""
    with open(file_path, 'r', encoding='utf-8') as f:
        return yaml.safe_load(f)

def generate_vlans(config: Dict) -> str:
    """Generate Terraform vlans variable"""
    vlans = {}
    
    # VLAN 101-104: Sale dydaktyczne (per piętro)
    for floor_name, floor_data in config['vlans']['dydactic'].items():
        vlan_id = str(floor_data['vlan_id'])
        vlans[vlan_id] = {
            'name': f"dydactic-{floor_name}",
            'subnet': floor_data['subnet']
        }
    
    # VLAN 110: Telewizory
    tv = config['vlans']['tv']
    vlans[str(tv['vlan_id'])] = {
        'name': 'tv-info',
        'subnet': tv['subnet']
    }
    
    # VLAN 208-246: Pracownie (15 sal: 8,9,23-31,41-46)
    for lab in config['vlans']['labs']:
        vlan_id = str(lab['vlan_id'])
        vlans[vlan_id] = {
            'name': f"lab-{lab['sala']}",
            'subnet': lab['subnet']
        }
    
    # VLAN 300-303: WiFi uczniowska (per piętro)
    for wifi in config['vlans']['wifi']:
        vlan_id = str(wifi['vlan_id'])
        vlans[vlan_id] = {
            'name': f"wifi-student-{wifi['floor']}",
            'subnet': wifi['subnet']
        }
    
    # VLAN 400-401: Serwery uczniowskie
    for server in config['vlans']['servers']:
        vlan_id = str(server['vlan_id'])
        vlans[vlan_id] = {
            'name': f"server-student-{vlan_id}",
            'subnet': server['subnet']
        }
    
    # VLAN 500: Administracja
    admin = config['vlans']['admin']
    vlans[str(admin['vlan_id'])] = {
        'name': 'admin',
        'subnet': admin['subnet']
    }
    
    # VLAN 501: CCTV
    cctv = config['vlans']['cctv']
    vlans[str(cctv['vlan_id'])] = {
        'name': 'cctv',
        'subnet': cctv['subnet']
    }
    
    # VLAN 600: Management
    mgmt = config['vlans']['management']
    vlans[str(mgmt['vlan_id'])] = {
        'name': 'management',
        'subnet': mgmt['subnet']
    }
    
    # Generate Terraform HCL
    output = 'vlans = {\n'
    
    # Group by type with comments
    output += '  # === SALE DYDAKTYCZNE (Teaching Classrooms) 101-104 ===\n'
    for vlan_id in ['101', '102', '103', '104']:
        if vlan_id in vlans:
            v = vlans[vlan_id]
            output += f'  "{vlan_id}" = {{ name = "{v["name"]}", subnet = "{v["subnet"]}" }}\n'
    
    output += '\n  # === TELEWIZORY INFORMACYJNE 110 ===\n'
    if '110' in vlans:
        v = vlans['110']
        output += f'  "110" = {{ name = "{v["name"]}", subnet = "{v["subnet"]}" }}\n'
    
    output += '\n  # === PRACOWNIE UCZNIOWSKIE (Labs) 208-246 ===\n'
    output += '  # VLAN = Numer SALI FIZYCZNEJ (8,9,23,24,25,26,27,28,30,31,41,42,43,44,46)\n'
    for vlan_id in ['208', '209', '223', '224', '225', '226', '227', '228', '230', '231', '241', '242', '243', '244', '246']:
        if vlan_id in vlans:
            v = vlans[vlan_id]
            output += f'  "{vlan_id}" = {{ name = "{v["name"]}", subnet = "{v["subnet"]}" }}\n'
    
    output += '\n  # === WIFI UCZNIOWSKA 300-303 ===\n'
    for vlan_id in ['300', '301', '302', '303']:
        if vlan_id in vlans:
            v = vlans[vlan_id]
            output += f'  "{vlan_id}" = {{ name = "{v["name"]}", subnet = "{v["subnet"]}" }}\n'
    
    output += '\n  # === SERWERY UCZNIOWSKIE 400-401 ===\n'
    for vlan_id in ['400', '401']:
        if vlan_id in vlans:
            v = vlans[vlan_id]
            output += f'  "{vlan_id}" = {{ name = "{v["name"]}", subnet = "{v["subnet"]}" }}\n'
    
    output += '\n  # === SIEĆ ADMINISTRACYJNA 500 ===\n'
    if '500' in vlans:
        v = vlans['500']
        output += f'  "500" = {{ name = "{v["name"]}", subnet = "{v["subnet"]}" }}\n'
    
    output += '\n  # === KAMERY CCTV 501 ===\n'
    if '501' in vlans:
        v = vlans['501']
        output += f'  "501" = {{ name = "{v["name"]}", subnet = "{v["subnet"]}" }}\n'
    
    output += '\n  # === ZARZĄDZANIE INFRASTRUKTURĄ 600 ===\n'
    if '600' in vlans:
        v = vlans['600']
        output += f'  "600" = {{ name = "{v["name"]}", subnet = "{v["subnet"]}" }}\n'
    
    output += '}\n'
    return output

def generate_qos(config: Dict) -> str:
    """Generate QoS simple queue rules"""
    output = 'queue_simple = {\n'
    
    # QoS dla pracowni (VLAN 208-246)
    output += '  # === PRACOWNIE (60 Mbps + burst 80 Mbps) ===\n'
    qos_lab = config['qos_policies']['labs']
    for lab in config['vlans']['labs']:
        sala = lab['sala']
        subnet = lab['subnet']
        output += f'  "lab-{sala}" = {{\n'
        output += f'    name            = "QoS-Lab-{sala}"\n'
        output += f'    target          = "{subnet}"\n'
        output += f'    max_limit       = "{qos_lab["max_limit"]}"\n'
        output += f'    burst_limit     = "{qos_lab["burst_limit"]}"\n'
        output += f'    burst_threshold = "{qos_lab["burst_threshold"]}"\n'
        output += f'    burst_time      = "{qos_lab["burst_time"]}"\n'
        output += f'    priority        = {qos_lab["priority"]}\n'
        output += f'    comment         = "PFU 2.7 - Pracownia {sala} ({lab["floor"]}, {lab["type"]}, {lab["ports"]} ports)"\n'
        output += '  }\n'
    
    # QoS dla sal dydaktycznych (VLAN 101-104)
    output += '\n  # === SALE DYDAKTYCZNE (1000 Mbps per piętro) ===\n'
    qos_dyd = config['qos_policies']['dydactic']
    for floor_name, floor_data in config['vlans']['dydactic'].items():
        subnet = floor_data['subnet']
        output += f'  "dydactic-{floor_name}" = {{\n'
        output += f'    name      = "QoS-Dydactic-{floor_name}"\n'
        output += f'    target    = "{subnet}"\n'
        output += f'    max_limit = "{qos_dyd["max_limit"]}"\n'
        output += f'    priority  = {qos_dyd["priority"]}\n'
        output += f'    comment   = "PFU 2.7 - Sale dydaktyczne {floor_name}"\n'
        output += '  }\n'
    
    # QoS dla WiFi (VLAN 300-303)
    output += '\n  # === WIFI UCZNIOWSKA (200 Mbps per piętro) ===\n'
    qos_wifi = config['qos_policies']['wifi']
    for wifi in config['vlans']['wifi']:
        subnet = wifi['subnet']
        floor = wifi['floor']
        output += f'  "wifi-{floor}" = {{\n'
        output += f'    name      = "QoS-WiFi-{floor}"\n'
        output += f'    target    = "{subnet}"\n'
        output += f'    max_limit = "{qos_wifi["max_limit"]}"\n'
        output += f'    priority  = {qos_wifi["priority"]}\n'
        output += f'    comment   = "PFU 2.7 - WiFi uczniowska {floor}"\n'
        output += '  }\n'
    
    output += '}\n'
    return output

def generate_bgp(config: Dict) -> str:
    """Generate BGP configuration"""
    bgp = config['bgp']
    
    output = '# ===== BGP CONFIGURATION (MetalLB Peering) =====\n'
    output += 'bgp_instances = {\n'
    output += '  "default" = {\n'
    output += f'    as       = {bgp["instance"]["as"]}\n'
    output += '    disabled = false\n'
    output += '  }\n'
    output += '}\n\n'
    
    output += 'bgp_peers = {\n'
    for peer in bgp['peers']:
        name = peer['name']
        output += f'  "{name}" = {{\n'
        output += f'    remote_address = "{peer["remote_address"]}"\n'
        output += f'    remote_as      = {peer["remote_as"]}\n'
        output += f'    hold_time      = "{peer["hold_time"]}"\n'
        output += f'    keepalive_time = "{peer["keepalive_time"]}"\n'
        output += '  }\n'
    output += '}\n\n'
    
    output += 'bgp_networks = {\n'
    for net in bgp['advertised_networks']:
        # Extract network prefix for name
        network_parts = net['network'].split('.')
        name = f"network-{network_parts[0]}-{network_parts[1]}-{network_parts[2]}"
        output += f'  "{name}" = {{\n'
        output += f'    network = "{net["network"]}"\n'
        output += f'    comment = "{net["comment"]}"\n'
        output += '  }\n'
    output += '}\n'
    
    return output

def main():
    # Paths
    script_dir = Path(__file__).parent
    workspace_root = script_dir.parent
    yaml_file = workspace_root / 'common' / 'vlans-master.yaml'
    output_file = workspace_root / 'zsel-eip-tf-infra' / 'environments' / 'networking-prod' / 'prod-values-generated.auto.tfvars'
    
    print(f"Loading configuration from {yaml_file.name}...")
    config = load_yaml(yaml_file)
    
    print("Generating VLANs...")
    vlans_tf = generate_vlans(config)
    
    print("Generating QoS policies...")
    qos_tf = generate_qos(config)
    
    print("Generating BGP configuration...")
    bgp_tf = generate_bgp(config)
    
    # Write output
    print(f"Writing to {output_file.name}...")
    output_file.parent.mkdir(parents=True, exist_ok=True)
    
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write('# ' + '='*77 + '\n')
        f.write('# Terraform Configuration - AUTO-GENERATED\n')
        f.write('# ' + '='*77 + '\n')
        f.write('# Generated from: common/vlans-master.yaml\n')
        f.write('# Generator: scripts/generate-terraform.py\n')
        f.write('# PFU 2.7 COMPLIANT - Physical room numbers (8,9,23-31,41-46) = VLAN 208-246\n')
        f.write('# DO NOT EDIT MANUALLY - Run generator instead!\n')
        f.write('# ' + '='*77 + '\n\n')
        
        f.write('# ===== MIKROTIK CONNECTION =====\n')
        f.write('mikrotik_host     = "192.168.255.1"\n')
        f.write('mikrotik_username = "admin"\n\n')
        
        f.write('# ===== VLANS =====\n')
        f.write(vlans_tf)
        f.write('\n')
        
        f.write('# ===== QoS SIMPLE QUEUE (PFU 2.7 Compliant) =====\n')
        f.write(qos_tf)
        f.write('\n')
        
        f.write(bgp_tf)
    
    # Summary
    vlan_count = len(config['vlans']['dydactic']) + 1 + len(config['vlans']['labs']) + len(config['vlans']['wifi']) + len(config['vlans']['servers']) + 3  # +3 = admin, cctv, mgmt
    qos_count = len(config['vlans']['labs']) + len(config['vlans']['dydactic']) + len(config['vlans']['wifi'])
    bgp_peer_count = len(config['bgp']['peers'])
    bgp_net_count = len(config['bgp']['advertised_networks'])
    
    print('\n' + '='*70)
    print('✅ GENERATION COMPLETE')
    print('='*70)
    print(f'VLANs generated:      {vlan_count}')
    print(f'  - Dydactic (101-104): {len(config["vlans"]["dydactic"])}')
    print(f'  - TV (110): 1')
    print(f'  - Labs (208-246): {len(config["vlans"]["labs"])} (Sale: 8,9,23-31,41-46)')
    print(f'  - WiFi (300-303): {len(config["vlans"]["wifi"])}')
    print(f'  - Servers (400-401): {len(config["vlans"]["servers"])}')
    print(f'  - Admin (500): 1')
    print(f'  - CCTV (501): 1')
    print(f'  - Management (600): 1')
    print(f'QoS policies:         {qos_count}')
    print(f'BGP peers:            {bgp_peer_count}')
    print(f'BGP networks:         {bgp_net_count}')
    print(f'Output file:          {output_file.name}')
    print('='*70)
    print('Next steps:')
    print('1. Review: prod-values-generated.auto.tfvars')
    print('2. Backup old: mv prod-values.auto.tfvars prod-values-OLD-WRONG.backup')
    print('3. Activate: mv prod-values-generated.auto.tfvars prod-values.auto.tfvars')
    print('4. Validate: terraform validate')
    print('5. Plan: terraform plan')
    print('='*70)

if __name__ == '__main__':
    main()
