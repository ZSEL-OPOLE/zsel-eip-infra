# Network Services Architecture - K3s Integration
> Serwisy sieciowe wspierające infrastrukturę MikroTik (57 urządzeń)

**Data utworzenia:** 2025-11-22  
**Status:** Design Phase  
**Środowisko:** K3s cluster (9× Mac Pro M2 Ultra)

---

## 📋 Spis Treści

1. [Przegląd Architektury](#przegląd-architektury)
2. [VLAN Placement Strategy](#vlan-placement-strategy)
3. [Services Inventory](#services-inventory)
4. [Service Dependencies](#service-dependencies)
5. [High Availability Design](#high-availability-design)
6. [Integration Points](#integration-points)

---

## Przegląd Architektury

### Infrastructure Context

**MikroTik Devices (57 total):**
- 5× CCR2216 (Core Gateways) → CS-GW-CPD-01 to 05
- 6× CRS518 (Aggregation) → CS-SW-AGG-CPD-01 to 06
- 16× CRS354 (Distribution) → CS-SW-DIST-P0-01 to P3-04
- 13× CRS326 (Access) → CS-SW-ACC-SXX-01
- 1× CRS328 (PoE) → CS-SW-POE-CPD-01
- 16× cAP ax (WiFi) → CS-AP-01 to 16

**K3s Cluster (Network Services Host):**
- 3× Control Plane nodes (192.168.10.11-13)
- 6× Worker nodes (192.168.10.14-19)
- Total capacity: 216 cores, 1.7 TB RAM, 72 TB NVMe

**Critical Requirements:**
1. All network services MUST survive single K3s node failure
2. Services MUST be accessible from VLAN 600 (Management)
3. Authentication via Samba AD (central identity)
4. Monitoring for all 57 MikroTik devices
5. Automated backup for all configs

---

## VLAN Placement Strategy

### VLAN 600 - Management Network (192.168.255.0/28)
**Reason:** MikroTik devices management interfaces live here  
**Access:** All services MUST have endpoints in this VLAN

```
┌─────────────────────────────────────────────────┐
│         VLAN 600 (192.168.255.0/28)             │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐     │
│  │MikroTik  │  │MikroTik  │  │ MikroTik │     │
│  │  .2-.35  │  │  .36-.50 │  │  .51-... │     │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘     │
│       │             │              │            │
│       └─────────────┼──────────────┘            │
│                     │                            │
│       ┌─────────────▼──────────────┐            │
│       │  K3s Network Services      │            │
│       │  - Samba AD (LDAP/Kerberos)│            │
│       │  - FreeRADIUS              │            │
│       │  - DNS (zsel.local)        │            │
│       │  - NTP (stratum 2)         │            │
│       │  - Syslog Collector        │            │
│       │  - SNMP Poller             │            │
│       │  - Backup Storage          │            │
│       │  - Prometheus SNMP Exporter│            │
│       └────────────────────────────┘            │
└─────────────────────────────────────────────────┘
```

**IP Allocation (VLAN 600):**
- 192.168.255.2-35: MikroTik devices (already assigned per PFU)
- 192.168.255.50: FreeRADIUS service
- 192.168.255.51: Samba AD Primary DC
- 192.168.255.52: Samba AD Secondary DC
- 192.168.255.53: DNS service (Bind9)
- 192.168.255.54: NTP service (Chrony)
- 192.168.255.55: Syslog collector (Graylog/Rsyslog)
- 192.168.255.56: Backup storage gateway (MinIO S3)
- 192.168.255.57: Prometheus SNMP exporter
- 192.168.255.58: DHCP server (Kea)

### VLAN 10 - K3s Server Network (192.168.10.0/24)
**Reason:** Internal K3s cluster communication  
**Access:** Backend services, databases, inter-pod traffic

```
┌─────────────────────────────────────────────────┐
│         VLAN 10 (192.168.10.0/24)               │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐     │
│  │ Master 1 │  │ Master 2 │  │ Master 3 │     │
│  │ .10.11   │  │ .10.12   │  │ .10.13   │     │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘     │
│       │             │              │            │
│  ┌────▼─────────────▼──────────────▼─────┐     │
│  │  Backend Services (ClusterIP)         │     │
│  │  - Samba AD backend (LDAP sync)       │     │
│  │  - PostgreSQL (RADIUS DB)             │     │
│  │  - Prometheus (metrics storage)       │     │
│  │  - Grafana (internal)                 │     │
│  │  - MinIO storage backend              │     │
│  └───────────────────────────────────────┘     │
└─────────────────────────────────────────────────┘
```

### VLAN 30 - MetalLB Pool (192.168.30.0/24)
**Reason:** LoadBalancer external IPs for K8s Services  
**Access:** Reserved for services that need routable IPs

---

## Services Inventory

### 1. Samba AD Domain Controller ⭐

**Purpose:** Central authentication for MikroTik RADIUS + user management  
**Technology:** Samba 4.x (Active Directory compatible)  
**Deployment:** StatefulSet (Primary + Secondary DC)  
**VLAN:** 600 (frontend), 10 (backend replication)

**Exposed Services:**
- LDAP: 389 TCP (queries from FreeRADIUS)
- LDAPS: 636 TCP (secure LDAP)
- Kerberos: 88 TCP/UDP (authentication)
- DNS: 53 TCP/UDP (AD-integrated DNS for zsel.local)
- SMB: 445 TCP (file shares - optional)

**HA Strategy:**
- Primary DC: 192.168.255.51 (StatefulSet pod-0)
- Secondary DC: 192.168.255.52 (StatefulSet pod-1)
- Multi-master replication (automatic failover)
- PersistentVolume: 50 GB (Longhorn 3× replica)

**Domain Structure:**
```
DC=ad,DC=zsel,DC=opole,DC=pl
├── OU=Users
│   ├── CN=IT Admins
│   ├── CN=Network Operators
│   └── CN=Monitoring Users
├── OU=Groups
│   ├── CN=IT-Admins (full MikroTik access)
│   ├── CN=Network-Team (write access, no reboot)
│   └── CN=Monitoring (read-only)
├── OU=Computers
│   └── CN=MikroTik Devices
└── OU=Service Accounts
    ├── CN=radius-bind
    ├── CN=prometheus-snmp
    ├── CN=zabbix-monitor
    └── CN=backup-service
```

**Integration Points:**
- FreeRADIUS → LDAP queries (CN=radius-bind)
- MikroTik → RADIUS login (users from AD groups)
- DNS → Forward zone zsel.local (to this AD)
- Monitoring → Service account for SNMP auth

---

### 2. FreeRADIUS Authentication Server ⭐

**Purpose:** RADIUS authentication for MikroTik devices with AD integration  
**Technology:** FreeRADIUS 3.x with rlm_ldap module  
**Deployment:** Deployment (3 replicas for HA)  
**VLAN:** 600 (frontend), 10 (backend LDAP)

**Exposed Services:**
- RADIUS Auth: 1812 UDP (MikroTik login requests)
- RADIUS Accounting: 1813 UDP (session logs)
- HTTP API: 8080 TCP (health check, metrics)

**HA Strategy:**
- 3× replicas (load balanced by MetalLB)
- Service IP: 192.168.255.50 (VIP via MetalLB)
- Stateless (all state in Samba AD)
- Health checks: UDP probe on port 1812

**LDAP Integration:**
```conf
# /etc/freeradius/3.0/mods-available/ldap
ldap {
    server = 'ldap://192.168.255.51:389'
    identity = 'CN=radius-bind,OU=Service Accounts,DC=ad,DC=zsel,DC=opole,DC=pl'
    password = 'SECURE_BIND_PASSWORD'
    base_dn = 'DC=ad,DC=zsel,DC=opole,DC=pl'
    
    user {
        base_dn = 'OU=Users,DC=ad,DC=zsel,DC=opole,DC=pl'
        filter = "(sAMAccountName=%{%{Stripped-User-Name}:-%{User-Name}})"
    }
    
    group {
        base_dn = 'OU=Groups,DC=ad,DC=zsel,DC=opole,DC=pl'
        membership_filter = "(member=%{control:Ldap-UserDn})"
    }
}
```

**Group → MikroTik Role Mapping:**
```conf
# /etc/freeradius/3.0/sites-available/default
authorize {
    ldap
    
    # Map AD groups to MikroTik groups
    if (Ldap-Group == "IT-Admins") {
        update reply {
            Mikrotik-Group := "network-admin"
        }
    }
    elsif (Ldap-Group == "Network-Team") {
        update reply {
            Mikrotik-Group := "network-operator"
        }
    }
    elsif (Ldap-Group == "Monitoring") {
        update reply {
            Mikrotik-Group := "monitoring-only"
        }
    }
}
```

**MikroTik Client Configuration:**
```conf
# /etc/freeradius/3.0/clients.conf
client mikrotik-core {
    ipaddr = 192.168.255.2/28  # All MikroTik management IPs
    secret = "SHARED_RADIUS_SECRET_MIN32CHARS"
    shortname = mikrotik
    nastype = other
}
```

**Metrics Export:**
- Prometheus exporter: port 9812 TCP
- Metrics: auth_requests, auth_success, auth_failure, latency

---

### 3. DNS Server (Bind9) ⭐

**Purpose:** Authoritative DNS for ad.zsel.opole.pl domain + caching resolver  
**Technology:** Bind9 with AD integration  
**Deployment:** Deployment (2 replicas)  
**VLAN:** 600 (frontend), 10 (backend)

**Exposed Services:**
- DNS: 53 UDP/TCP (queries from MikroTik, clients)

**HA Strategy:**
- 2× replicas (anycast via MetalLB)
- Service IP: 192.168.255.53 (VIP)
- Primary: queries Samba AD for ad.zsel.opole.pl
- Secondary: local cache + Internet forwarders

**Zone Configuration:**
```conf
# /etc/bind/named.conf.local

# Forward zone for AD domain
zone "ad.zsel.opole.pl" {
    type forward;
    forwarders { 192.168.255.51; 192.168.255.52; };  # Samba AD DCs
    forward only;
};

# Reverse zone for VLAN 600 (Management)
zone "255.168.192.in-addr.arpa" {
    type master;
    file "/etc/bind/db.255.168.192";
    allow-update { none; };
};

# Reverse zones for all PFU VLANs (101-104, 110, 208-246, etc.)
zone "101.168.192.in-addr.arpa" { ... };
zone "102.168.192.in-addr.arpa" { ... };
# ... (total 54 reverse zones)

# Internet forwarders
forwarders {
    1.1.1.1;       # Cloudflare
    8.8.8.8;       # Google
    9.9.9.9;       # Quad9
};
```

**Integration Points:**
- MikroTik → DNS queries (already configured in CCR)
- Samba AD → ad.zsel.opole.pl resolution
- Clients → Internal + Internet DNS

---

### 4. NTP Server (Chrony) ⭐

**Purpose:** Stratum 2 time source for all MikroTik devices  
**Technology:** Chrony (high-accuracy NTP)  
**Deployment:** DaemonSet (runs on all K3s nodes)  
**VLAN:** 600 (frontend)

**Exposed Services:**
- NTP: 123 UDP (time sync)

**HA Strategy:**
- DaemonSet on all 9 nodes (automatic redundancy)
- Service IP: 192.168.255.54 (VIP, load balanced)
- Each node can serve NTP independently
- Synchronized to external stratum 1 servers

**Upstream Configuration:**
```conf
# /etc/chrony/chrony.conf

# Stratum 1 sources (Internet)
pool pl.pool.ntp.org iburst maxsources 4
pool europe.pool.ntp.org iburst maxsources 2

# Allow queries from management VLAN
allow 192.168.255.0/28

# Local stratum (fallback if Internet down)
local stratum 10
```

**MikroTik Integration:**
- Already configured in CCR2216-BCU-01.rsc:
  ```routeros
  /system ntp client set enabled=yes
  /system ntp client servers add address=192.168.255.2
  ```
- **UPDATE NEEDED:** Change to `address=192.168.255.54` (K3s NTP service)

**Monitoring:**
- Prometheus exporter: port 9100 (chrony_exporter)
- Metrics: stratum, offset, jitter, peers

---

### 5. Syslog Collector (Graylog) ⭐

**Purpose:** Centralized log aggregation for all 57 MikroTik devices  
**Technology:** Graylog 5.x (Elasticsearch + MongoDB + Graylog)  
**Deployment:** StatefulSet (3 components)  
**VLAN:** 600 (frontend syslog), 10 (backend DB)

**Exposed Services:**
- Syslog UDP: 514 (MikroTik logs)
- Syslog TCP: 514 (reliable transport)
- Graylog Web: 9000 TCP (WebUI - internal only)
- Graylog API: 9000 TCP (Grafana integration)

**HA Strategy:**
- Elasticsearch: 3× replicas (1 per master node)
- MongoDB: 3× replicas (replica set)
- Graylog: 2× replicas (stateless, shared config)
- Service IP: 192.168.255.55 (VIP for syslog input)
- PersistentVolume: 500 GB (Longhorn, 30 days retention)

**Log Inputs:**
```yaml
# Graylog Input Configuration
- name: mikrotik-syslog
  type: syslog-udp
  bind_address: 0.0.0.0
  port: 514
  recv_buffer_size: 262144
  
- name: mikrotik-syslog-tcp
  type: syslog-tcp
  bind_address: 0.0.0.0
  port: 514
  recv_buffer_size: 262144
```

**Stream Rules (Auto-categorization):**
- Stream: "MikroTik-Core" (CS-GW-CPD-XX logs)
- Stream: "MikroTik-Switches" (CS-SW-* logs)
- Stream: "MikroTik-WiFi" (CS-AP-* logs)
- Stream: "MikroTik-Errors" (severity >= error)
- Stream: "MikroTik-Auth" (RADIUS login attempts)

**Retention Policy:**
- Hot tier: 7 days (fast queries)
- Warm tier: 23 days (archived to QNAP NAS)
- Total: 30 days retention
- Critical logs (errors, auth): 90 days

**MikroTik Integration:**
- Already configured in CCR2216-BCU-01.rsc:
  ```routeros
  /system logging action
  add name=remote remote=192.168.255.2 remote-port=514 target=remote
  ```
- **UPDATE NEEDED:** Change to `remote=192.168.255.55` (Graylog)

**Dashboards:**
- Device availability (last seen)
- Error rate per device
- RADIUS auth success/failure
- Bandwidth anomalies (extracted from logs)
- Configuration changes (audit trail)

---

### 6. Monitoring Stack (Prometheus + Grafana) ⭐

**Purpose:** Real-time monitoring + alerting for 57 MikroTik devices  
**Technology:** Prometheus (SNMP exporter) + Grafana + AlertManager  
**Deployment:** StatefulSet (Prometheus), Deployment (Grafana)  
**VLAN:** 10 (backend scraping), 600 (SNMP targets)

**Components:**

#### a) Prometheus SNMP Exporter
**Service IP:** 192.168.255.57 (VLAN 600)  
**Replicas:** 3 (sharded by device groups)  
**Scrape Interval:** 60s (standard), 15s (critical metrics)

**SNMP Targets (57 devices):**
```yaml
# prometheus-snmp-config.yaml
scrape_configs:
  - job_name: 'mikrotik-core'
    static_configs:
      - targets:
        - 192.168.255.2   # CS-GW-CPD-01
        - 192.168.255.3   # CS-GW-CPD-02
        - 192.168.255.4   # CS-GW-CPD-03
        - 192.168.255.5   # CS-GW-CPD-04
        - 192.168.255.6   # CS-GW-CPD-05
    metrics_path: /snmp
    params:
      module: [mikrotik]
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: 192.168.255.57:9116  # SNMP exporter

  - job_name: 'mikrotik-agg'
    static_configs:
      - targets:
        - 192.168.255.7   # CS-SW-AGG-CPD-01
        - 192.168.255.8   # CS-SW-AGG-CPD-02
        # ... (6 total)
    # ... (same relabel config)

  - job_name: 'mikrotik-dist'
    static_configs:
      - targets: [192.168.255.13-28]  # 16 DIST switches
  
  - job_name: 'mikrotik-acc'
    static_configs:
      - targets: [192.168.255.20-32]  # 13 ACC switches
  
  - job_name: 'mikrotik-poe'
    static_configs:
      - targets: [192.168.255.35]  # CS-SW-POE-CPD-01
  
  - job_name: 'mikrotik-wifi'
    scrape_interval: 30s  # Faster for WiFi
    static_configs:
      - targets: [192.168.255.40-55]  # 16 cAP APs
```

**SNMP Community (Already configured in MikroTik):**
```routeros
/snmp community
add name=ZSEL-v3 addresses=192.168.255.50/32 security=private \
    authentication-protocol=SHA256 encryption-protocol=AES256 \
    authentication-password="CHANGE_SNMP_AUTH" \
    encryption-password="CHANGE_SNMP_ENCR"
```

**Collected Metrics (per device):**
- CPU utilization (%)
- Memory usage (MB, %)
- Disk usage (MB, %)
- Temperature (°C) - critical for CCR2216
- Uptime (seconds)
- Interface stats (RX/TX bytes, errors, drops)
- BGP peer status (for Core routers)
- VLAN traffic (per VLAN ID)
- WiFi clients (per AP)
- PoE power consumption (CS-SW-POE-CPD-01)

#### b) Prometheus Storage
**PersistentVolume:** 1 TB (Longhorn 3× replica)  
**Retention:** 90 days (high resolution)  
**Backup:** Daily snapshot to QNAP NAS (192.168.20.10)

#### c) Grafana Dashboards
**Service:** Internal (VLAN 10 only, accessed via VPN)  
**Replicas:** 2 (HA)  
**Datasource:** Prometheus + Graylog (logs)

**Pre-built Dashboards:**
1. **Network Overview**
   - 57 devices status grid (green/yellow/red)
   - Total bandwidth (aggregated)
   - Alerts summary
   - Top 10 talkers

2. **Core Routers (CS-GW-CPD-01 to 05)**
   - CPU/RAM/Temp per device
   - BGP peer status
   - WAN uplinks utilization
   - NAT session count

3. **Aggregation Layer (CS-SW-AGG-CPD-01 to 06)**
   - Uplink/downlink bandwidth
   - Port errors/discards
   - SFP28 optical power (dBm)

4. **Distribution Layer (CS-SW-DIST-P0-01 to P3-04)**
   - Per-floor bandwidth
   - VLAN traffic breakdown
   - Port utilization heatmap

5. **Access Layer (CS-SW-ACC-SXX-01)**
   - End-user port status
   - Top bandwidth consumers
   - PoE power draw

6. **WiFi (CS-AP-01 to 16)**
   - Client count per AP
   - Signal strength distribution
   - Channel utilization
   - Roaming events

#### d) AlertManager
**Replicas:** 3 (HA cluster)  
**Alerting Channels:**
- Email: it@zsel.opole.pl
- Slack: #network-alerts (optional)
- PagerDuty: Critical only (optional)

**Alert Rules:**
```yaml
# prometheus-alerts.yaml
groups:
  - name: mikrotik-critical
    interval: 30s
    rules:
      - alert: DeviceDown
        expr: up{job=~"mikrotik-.*"} == 0
        for: 2m
        annotations:
          summary: "MikroTik {{ $labels.instance }} is DOWN"
        labels:
          severity: critical
      
      - alert: HighCPU
        expr: mikrotik_cpu_usage > 80
        for: 5m
        annotations:
          summary: "High CPU on {{ $labels.instance }}: {{ $value }}%"
        labels:
          severity: warning
      
      - alert: HighTemperature
        expr: mikrotik_temperature > 70
        for: 3m
        annotations:
          summary: "High temp on {{ $labels.instance }}: {{ $value }}°C"
        labels:
          severity: critical
      
      - alert: InterfaceDown
        expr: mikrotik_interface_status{name=~"sfp.*|ether.*"} == 0
        for: 2m
        annotations:
          summary: "Interface {{ $labels.name }} down on {{ $labels.instance }}"
        labels:
          severity: warning
      
      - alert: HighBandwidth
        expr: rate(mikrotik_interface_tx_bytes[5m]) > 20000000000  # 20 Gbps
        for: 10m
        annotations:
          summary: "High bandwidth on {{ $labels.instance }}/{{ $labels.name }}"
        labels:
          severity: info
```

---

### 7. Backup Storage (MinIO S3) ⭐

**Purpose:** Automated config backups for all 57 MikroTik devices  
**Technology:** MinIO (S3-compatible object storage)  
**Deployment:** StatefulSet (4 nodes, erasure coding)  
**VLAN:** 600 (frontend API), 10 (backend storage)

**Exposed Services:**
- S3 API: 9000 TCP (backup uploads)
- MinIO Console: 9001 TCP (WebUI - internal)

**HA Strategy:**
- 4× MinIO nodes (2 data + 2 parity = 50% overhead)
- Erasure coding: survives 2 node failures
- Service IP: 192.168.255.56 (VIP)
- PersistentVolume: 2 TB (Longhorn 2× replica)
- Additional backup: Daily rsync to QNAP NAS

**Bucket Structure:**
```
s3://mikrotik-backups/
├── core/
│   ├── CS-GW-CPD-01/
│   │   ├── 2025-11-22_03-00_CS-GW-CPD-01.backup
│   │   ├── 2025-11-21_03-00_CS-GW-CPD-01.backup
│   │   └── ... (30 days retention)
│   ├── CS-GW-CPD-02/ ...
├── agg/ ...
├── dist/ ...
├── acc/ ...
├── poe/ ...
└── wifi/
    └── capsman-config/  # CAPsMAN provisioning (from CCR)
```

**Lifecycle Policy:**
- Current backups: Standard tier (MinIO hot)
- 7-30 days: Keep in MinIO
- 30-90 days: Transition to QNAP NAS (warm)
- 90+ days: Delete (or archive to tape)

**MikroTik Integration:**
- Already configured in CCR2216-BCU-01.rsc (line 512):
  ```routeros
  :local backupname ("CS-GW-CPD-01_backup_" . \
      [/system clock get date] . "_" . [/system clock get time])
  /system backup save name=$backupname
  ```
- **UPDATE NEEDED:** Add S3 upload via `/tool fetch`:
  ```routeros
  /tool fetch \
      url="http://192.168.255.56:9000/mikrotik-backups/core/CS-GW-CPD-01/$backupname.backup" \
      mode=http upload=yes src-path=$backupname.backup \
      http-method=put \
      http-header-field="Authorization: Bearer MINIO_ACCESS_KEY"
  ```

**S3 Credentials:**
- Access Key: `mikrotik-backup-service`
- Secret Key: (stored in K8s Secret)
- Policy: PutObject only (no delete from devices)

**Monitoring:**
- Prometheus metrics: backup count, age, size
- Alert if backup > 25 hours old (missed daily run)
- Daily email report: all devices backed up successfully

---

### 8. DHCP Server (Kea) 🔧

**Purpose:** Centralized DHCP for management devices + dynamic DNS updates  
**Technology:** ISC Kea (high-performance DHCP)  
**Deployment:** Deployment (2 replicas, HA hot-standby)  
**VLAN:** 600 (management), 10 (HA communication)

**Exposed Services:**
- DHCP: 67 UDP (DHCP requests)
- Kea Control: 8000 TCP (API for automation)

**HA Strategy:**
- 2× replicas (hot-standby mode)
- Primary: 192.168.255.58 (active)
- Secondary: 192.168.255.59 (standby)
- Lease database: PostgreSQL (replicated)
- Failover: automatic (heartbeat every 10s)

**Scope Configuration:**
```json
{
  "Dhcp4": {
    "subnet4": [
      {
        "subnet": "192.168.255.0/28",
        "pools": [
          { "pool": "192.168.255.60 - 192.168.255.62" }
        ],
        "option-data": [
          { "name": "routers", "data": "192.168.255.1" },
          { "name": "domain-name-servers", "data": "192.168.255.53" },
          { "name": "domain-name", "data": "zsel.local" },
          { "name": "ntp-servers", "data": "192.168.255.54" }
        ],
        "reservations": [
          {
            "hw-address": "00:0C:42:XX:XX:XX",
            "ip-address": "192.168.255.2",
            "hostname": "CS-GW-CPD-01"
          }
          // ... (reservations for all 57 MikroTik devices)
        ]
      }
    ],
    "hooks-libraries": [
      {
        "library": "/usr/lib/kea/hooks/libdhcp_ddns.so",
        "parameters": {
          "dns-server-ip": "192.168.255.53",
          "dns-update-on-renew": true
        }
      }
    ]
  }
}
```

**Dynamic DNS Integration:**
- DHCP lease → automatic DNS A record creation
- Reverse PTR records (255.168.192.in-addr.arpa)
- Update via TSIG key (secure DNS updates)

**Use Case:**
- Temporary devices (laptops, test equipment) on management VLAN
- Automatic hostname resolution without manual DNS entries
- Lease logs for security auditing

---

### 9. Zabbix Monitoring Platform ⭐

**Purpose:** Enterprise-grade monitoring for 57 MikroTik + 9 K3s nodes + infrastructure  
**Technology:** Zabbix 7.x (Server + Web + PostgreSQL + Agent)  
**Deployment:** StatefulSet (Zabbix Server + PostgreSQL), Deployment (Web UI)  
**VLAN:** 10 (backend), 600 (SNMP targets)

**Exposed Services:**
- Zabbix Server: 10051 TCP (agent connections)
- Zabbix Web: 8080 TCP (WebUI - internal only)
- PostgreSQL: 5432 TCP (database - internal)

**HA Strategy:**
- Zabbix Server: 1× StatefulSet (active-passive via external HA proxy - future)
- PostgreSQL: 1× StatefulSet with streaming replication (read replicas)
- Zabbix Web: 3× replicas (stateless, load balanced)
- PersistentVolume: 200 GB (Longhorn 3× replica, 90 days metrics)
- Backup: Daily pg_dump to MinIO S3

**Components:**

#### a) Zabbix Server
**Image:** `zabbix/zabbix-server-pgsql:7.0-alpine`  
**Resources:** 4 CPU, 8 GB RAM  
**Database:** PostgreSQL 16 (dedicated instance)

**Configuration:**
```yaml
# zabbix-server-config.yaml
env:
  - name: DB_SERVER_HOST
    value: "zabbix-postgresql"
  - name: DB_SERVER_PORT
    value: "5432"
  - name: POSTGRES_DB
    value: "zabbix"
  - name: POSTGRES_USER
    valueFrom:
      secretKeyRef:
        name: zabbix-db-secret
        key: username
  - name: POSTGRES_PASSWORD
    valueFrom:
      secretKeyRef:
        name: zabbix-db-secret
        key: password
  - name: ZBX_CACHESIZE
    value: "4G"  # Large cache for 57 devices
  - name: ZBX_STARTPOLLERS
    value: "50"  # Parallel SNMP pollers
  - name: ZBX_TIMEOUT
    value: "10"
```

#### b) Zabbix Web UI
**Image:** `zabbix/zabbix-web-nginx-pgsql:7.0-alpine`  
**Replicas:** 3 (HA)  
**Access:** Internal only (VPN or kubectl port-forward)

**Configuration:**
```yaml
env:
  - name: ZBX_SERVER_HOST
    value: "zabbix-server"
  - name: ZBX_SERVER_PORT
    value: "10051"
  - name: DB_SERVER_HOST
    value: "zabbix-postgresql"
  - name: PHP_TZ
    value: "Europe/Warsaw"
```

#### c) PostgreSQL Database
**Image:** `postgres:16-alpine`  
**Storage:** 200 GB PVC (Longhorn)  
**Backup:** Daily via CronJob → MinIO S3

**Initialization:**
```sql
-- Schema created automatically by Zabbix Server
-- Custom optimizations:
CREATE INDEX idx_history_clock ON history (itemid, clock);
CREATE INDEX idx_trends_clock ON trends (itemid, clock);
ALTER TABLE history SET (autovacuum_vacuum_scale_factor = 0.01);
```

#### d) Zabbix Agent (on K3s nodes)
**Deployment:** DaemonSet on all 9 K3s nodes  
**Purpose:** Monitor K3s node health (CPU, RAM, disk, network)

**Metrics Collected:**
- System uptime
- CPU utilization per core
- Memory usage (total, available, cached)
- Disk I/O (read/write IOPS, latency)
- Network traffic (RX/TX bytes, errors)
- K3s service status (kubelet, containerd)

### Monitoring Targets

#### MikroTik Devices (57 total)
**Protocol:** SNMP v3 (already configured in devices)  
**Polling Interval:** 60s (standard), 30s (critical interfaces)  
**SNMP Community:** `ZSEL-v3` with SHA256 auth + AES256 encryption

**Host Groups:**
- `MikroTik - Core Routers` (5 devices)
- `MikroTik - Aggregation Switches` (6 devices)
- `MikroTik - Distribution Switches` (16 devices)
- `MikroTik - Access Switches` (13 devices)
- `MikroTik - PoE Switches` (1 device)
- `MikroTik - WiFi Access Points` (16 devices)

**Templates Applied:**
1. **Template Net MikroTik SNMPv3**
   - CPU utilization
   - Memory usage
   - Temperature (critical for CCR2216)
   - Uptime
   - Interface status (up/down)
   - Interface traffic (bits/s, packets/s)
   - Interface errors/discards
   - ICMP ping (availability)

2. **Template Net MikroTik RouterOS**
   - System health
   - Resource usage
   - BGP peer status (Core routers)
   - OSPF neighbor status
   - DHCP pools
   - Wireless clients (APs)

3. **Custom Template: MikroTik CAPsMAN**
   - AP registration status
   - Client count per AP
   - Signal strength distribution
   - Channel utilization
   - Roaming events

**Macros (per host):**
```
{$SNMP_COMMUNITY} = ZSEL-v3
{$SNMP_AUTH_PROTOCOL} = SHA256
{$SNMP_PRIV_PROTOCOL} = AES256
{$SNMP_AUTH_PASSPHRASE} = <from K8s Secret>
{$SNMP_PRIV_PASSPHRASE} = <from K8s Secret>
{$CPU.UTIL.CRIT} = 90  # CPU critical threshold
{$TEMP.CRIT} = 70      # Temperature critical (°C)
{$MEMORY.UTIL.CRIT} = 85
{$ICMP_LOSS_WARN} = 20  # Packet loss warning (%)
{$ICMP_LOSS_CRIT} = 50
```

**Triggers (Alerts):**
```
- High CPU usage: avg(/CS-GW-CPD-01/system.cpu.util,5m) > {$CPU.UTIL.CRIT}
- High temperature: last(/CS-GW-CPD-01/sensor.temp.value) > {$TEMP.CRIT}
- Device unreachable: nodata(/CS-GW-CPD-01/icmpping,3m) = 1
- Interface down: last(/CS-GW-CPD-01/net.if.status[sfp28-1]) = 2
- High bandwidth: avg(/CS-GW-CPD-01/net.if.in[sfp28-1],5m) > 20G
- Memory low: last(/CS-GW-CPD-01/vm.memory.util) > {$MEMORY.UTIL.CRIT}
- BGP peer down: last(/CS-GW-CPD-01/bgp.peer.state[peer1]) <> 6
```

#### K3s Nodes (9 total)
**Protocol:** Zabbix Agent (active mode)  
**Polling Interval:** 60s  
**Agent Port:** 10050 TCP

**Host Groups:**
- `K3s - Control Plane` (3 nodes)
- `K3s - Workers Education` (2 nodes)
- `K3s - Workers AI/ML` (1 node)
- `K3s - Workers DevOps` (1 node)
- `K3s - Workers General` (2 nodes)

**Templates Applied:**
1. **Template OS Linux by Zabbix agent active**
   - CPU usage
   - Memory usage
   - Disk I/O
   - Network interfaces
   - System load
   - Process count

2. **Custom Template: K3s Node**
   - Kubelet status
   - Containerd status
   - etcd status (control plane only)
   - Pod count per node
   - Container count
   - PersistentVolume usage

**Zabbix Agent Configuration:**
```conf
# /etc/zabbix/zabbix_agentd.conf
Server=zabbix-server.mon-zabbix.svc.cluster.local
ServerActive=zabbix-server.mon-zabbix.svc.cluster.local:10051
Hostname=k3s-master-01
HostMetadata=k3s-node control-plane
RefreshActiveChecks=120
UserParameter=k3s.kubelet.status,systemctl is-active k3s
UserParameter=k3s.pods.count,kubectl get pods --all-namespaces --field-selector=spec.nodeName=$(hostname) | wc -l
```

#### K3s Cluster Services (via HTTP checks)
**Protocol:** HTTP/HTTPS (synthetic checks)  
**Polling Interval:** 300s (5 minutes)

**Monitored Services:**
- Samba AD LDAP: ldapsearch health check (port 389)
- FreeRADIUS: radtest synthetic auth (port 1812)
- DNS: dig query for ad.zsel.opole.pl (port 53)
- NTP: ntpdate -q health check (port 123)
- Graylog Web: HTTP 200 check (port 9000)
- Prometheus: HTTP /api/v1/status/config (port 9090)
- Grafana: HTTP /api/health (port 3000)
- MinIO: HTTP /minio/health/live (port 9000)

### Dashboards

**Pre-configured Zabbix Dashboards:**

1. **Network Overview**
   - Map widget with all 57 devices (color-coded by status)
   - Total bandwidth graph (aggregated)
   - Alerts summary (count by severity)
   - Top 10 devices by CPU usage
   - Top 10 interfaces by traffic

2. **Core Routers (CS-GW-CPD-01 to 05)**
   - CPU/RAM/Temperature per router
   - WAN uplink utilization
   - BGP peer status table
   - NAT session count
   - Firewall rule hit rate

3. **Aggregation Layer (CS-SW-AGG-CPD-01 to 06)**
   - Uplink traffic to Core
   - Downlink traffic to Distribution
   - Port errors/discards heatmap
   - SFP28 optical power (dBm)

4. **Distribution Layer (CS-SW-DIST-P0-01 to P3-04)**
   - Per-floor bandwidth
   - VLAN traffic breakdown
   - Port utilization percentage
   - PoE power consumption (where applicable)

5. **Access Layer (CS-SW-ACC-SXX-01)**
   - End-user port status (green/red grid)
   - Top bandwidth consumers
   - Link speed distribution (1G vs 10G)

6. **WiFi Network (CS-AP-01 to 16)**
   - Client count per AP (bar chart)
   - Signal strength distribution (histogram)
   - Channel utilization (2.4 GHz vs 5 GHz)
   - Roaming events timeline

7. **K3s Cluster Health**
   - Node status grid (9 nodes)
   - Total CPU/RAM usage (cluster-wide)
   - Pod count trend
   - PersistentVolume usage
   - Top 10 namespaces by resource usage

8. **Service Availability (SLA)**
   - Uptime percentage per service (99.9% target)
   - MTTR (Mean Time To Repair) per device
   - Incident timeline
   - Alert response time

### Integration with Other Services

**Zabbix → Grafana:**
- Zabbix data source plugin in Grafana
- Combined dashboards (Prometheus metrics + Zabbix alerts)
- Unified view of infrastructure

**Zabbix → Graylog:**
- Correlation of alerts with log entries
- Example: High CPU alert → fetch recent logs from Graylog

**Zabbix → Slack/Email:**
- AlertManager integration (webhook)
- Email: it@zsel.opole.pl
- Slack: #zabbix-alerts channel

**Zabbix → MinIO:**
- Daily PostgreSQL backup to S3
- Config export backup (XML)
- Retention: 90 days

### Alerting Configuration

**Action: Email Notification**
```yaml
conditions:
  - trigger_severity >= Warning
  - maintenance_status = not in maintenance
operations:
  - send_message:
      to: it@zsel.opole.pl
      subject: "[{TRIGGER.SEVERITY}] {HOST.NAME}: {TRIGGER.NAME}"
      body: |
        Problem: {EVENT.NAME}
        Host: {HOST.NAME} ({HOST.IP})
        Severity: {TRIGGER.SEVERITY}
        Time: {EVENT.DATE} {EVENT.TIME}
        Value: {ITEM.LASTVALUE}
        
        Dashboard: https://zabbix.zsel.internal/zabbix.php?action=problem.view
```

**Action: Slack Notification (Critical only)**
```yaml
conditions:
  - trigger_severity = Disaster OR High
operations:
  - webhook:
      url: https://hooks.slack.com/services/ZSEL/WEBHOOK/TOKEN
      payload: |
        {
          "channel": "#zabbix-critical",
          "username": "Zabbix Alert",
          "icon_emoji": ":rotating_light:",
          "attachments": [{
            "color": "danger",
            "title": "{HOST.NAME}: {TRIGGER.NAME}",
            "text": "{ITEM.LASTVALUE}",
            "fields": [
              {"title": "Severity", "value": "{TRIGGER.SEVERITY}", "short": true},
              {"title": "Time", "value": "{EVENT.TIME}", "short": true}
            ]
          }]
        }
```

**Escalation Steps:**
1. **0-5 minutes:** Email to it@zsel.opole.pl
2. **5-15 minutes:** Slack notification to #zabbix-alerts
3. **15-30 minutes:** SMS to on-call engineer (if critical)
4. **30+ minutes:** Page IT manager (if still unresolved)

### Auto-Discovery

**Network Discovery Rules:**
```yaml
- name: MikroTik Device Discovery
  ip_range: 192.168.255.2-62
  checks:
    - SNMP v3: sysDescr contains "RouterOS"
  actions:
    - add_to_host_group: MikroTik - Auto-discovered
    - link_template: Template Net MikroTik SNMPv3
    - set_macro: {$SNMP_COMMUNITY} = ZSEL-v3
```

**Low-Level Discovery (LLD):**
- **Network Interfaces:** Auto-discover all sfp*, ether* interfaces
- **VLANs:** Auto-discover VLANs 101-104, 110, 208-246, 300-303, 400-401, 500-501, 600
- **BGP Peers:** Auto-discover BGP neighbors on Core routers
- **Wireless Clients:** Auto-discover connected WiFi clients per AP

### Maintenance Windows

**Scheduled Maintenance:**
```yaml
- name: "Monthly Patching - K3s Nodes"
  period: "1st Sunday of month, 02:00-06:00"
  hosts: [k3s-master-*, k3s-worker-*]
  suppress_alerts: true

- name: "MikroTik Firmware Update - Rolling"
  period: "On-demand (manual trigger)"
  hosts: [Per deployment phase - 5 devices at a time]
  suppress_alerts: false  # Keep monitoring during update
```

---

## Service Dependencies

### Dependency Graph

```
┌─────────────────────────────────────────────────────────┐
│  Layer 1: Foundation Services (No dependencies)         │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐                │
│  │  NTP    │  │Samba AD │  │PostgreSQL│               │
│  │ (Chrony)│  │(Primary)│  │ (K8s DB) │               │
│  └────┬────┘  └────┬────┘  └────┬─────┘               │
└───────┼────────────┼────────────┼──────────────────────┘
        │            │            │
┌───────▼────────────▼────────────▼──────────────────────┐
│  Layer 2: Auth & Network Services                      │
│  ┌──────────────┐  ┌──────────┐  ┌──────────┐        │
│  │ FreeRADIUS   │  │   DNS    │  │  DHCP    │        │
│  │(needs AD+NTP)│  │(needs AD)│  │(needs DNS)│       │
│  └──────┬───────┘  └────┬─────┘  └────┬─────┘        │
└─────────┼───────────────┼─────────────┼───────────────┘
          │               │             │
┌─────────▼───────────────▼─────────────▼───────────────┐
│  Layer 3: Monitoring & Management                      │
│  ┌──────────────┐  ┌──────────┐  ┌──────────┐       │
│  │ Prometheus   │  │ Graylog  │  │  MinIO   │       │
│  │(SNMP export) │  │ (syslog) │  │(backups) │       │
│  └──────┬───────┘  └────┬─────┘  └────┬─────┘       │
└─────────┼───────────────┼─────────────┼──────────────┘
          │               │             │
┌─────────▼───────────────▼─────────────▼──────────────┐
│  Layer 4: Visualization & Alerting                    │
│  ┌──────────────┐  ┌──────────────┐                 │
│  │   Grafana    │  │ AlertManager │                 │
│  │  (dashboards)│  │  (notifications)                │
│  └──────────────┘  └──────────────┘                 │
└────────────────────────────────────────────────────────┘
```

### Startup Order

1. **Phase 1 (Foundation):**
   - PostgreSQL (5s)
   - Samba AD Primary DC (30s)
   - NTP (Chrony) (5s)

2. **Phase 2 (Auth & DNS):**
   - Wait for Samba AD healthy (health check: LDAP port 389)
   - DNS (Bind9) (10s)
   - FreeRADIUS (15s)
   - DHCP (Kea) (10s)

3. **Phase 3 (Monitoring):**
   - Wait for all Layer 2 services healthy
   - Prometheus SNMP Exporter (10s)
   - Graylog (Elasticsearch → MongoDB → Graylog) (60s)
   - MinIO (20s)

4. **Phase 4 (Visualization):**
   - Wait for Prometheus + Graylog data ingestion (2min)
   - Grafana (15s)
   - AlertManager (10s)

**Total Cold Start Time:** ~5 minutes (worst case)

---

## High Availability Design

### Failure Scenarios

#### Scenario 1: Single K3s Worker Node Failure
**Impact:** Minimal (services distributed)  
**Recovery:** Automatic pod rescheduling (30s)  
**Services Affected:**
- Stateless services (FreeRADIUS, DNS): 0 downtime (2+ replicas)
- Stateful services (Samba AD, Prometheus): <1min disruption (StatefulSet reschedule)
- DaemonSet (NTP): Unaffected (runs on all nodes)

#### Scenario 2: K3s Master Node Failure
**Impact:** Control plane degraded (2/3 quorum maintained)  
**Recovery:** Automatic (etcd cluster continues)  
**User Impact:** None (workloads unaffected)

#### Scenario 3: Entire K3s Cluster Outage
**Impact:** CRITICAL - all network services down  
**Recovery:** Manual restart (10-15 minutes)  
**MikroTik Fallback:**
- Local admin accounts still work (configured in all devices)
- DNS: fallback to Cloudflare 1.1.1.1 (already configured)
- NTP: fallback to pool.ntp.org (configured as secondary)
- RADIUS: fail-open to local auth

#### Scenario 4: Samba AD Primary DC Failure
**Impact:** Auth continues via Secondary DC  
**Recovery:** Automatic failover (FreeRADIUS tries secondary)  
**Downtime:** <5 seconds

#### Scenario 5: VLAN 600 Network Failure
**Impact:** CRITICAL - cannot reach any service  
**Recovery:** Fix network infrastructure (MikroTik issue)  
**Prevention:** Redundant paths (AGG layer bonding)

### Health Checks

**Kubernetes Liveness/Readiness Probes:**
```yaml
livenessProbe:
  tcpSocket:
    port: 389  # Samba AD LDAP
  initialDelaySeconds: 60
  periodSeconds: 10
  failureThreshold: 3

readinessProbe:
  exec:
    command: ["ldapsearch", "-x", "-H", "ldap://localhost", "-b", "dc=zsel,dc=local"]
  initialDelaySeconds: 30
  periodSeconds: 5
```

**External Monitoring:**
- Zabbix agent on each K3s node (monitors K8s services from outside)
- Synthetic checks from MikroTik devices (curl health endpoints)
- AlertManager notifies IT team via email/SMS

---

## Integration Points

### MikroTik → K3s Services

**CCR2216-BCU-01.rsc Updates Required:**
```routeros
# 1. RADIUS Authentication
/radius
add address=192.168.255.50 secret="SHARED_RADIUS_SECRET" \
    service=login timeout=3s

/user aaa
set use-radius=yes default-group=read

# 2. NTP (update from CCR to K3s NTP)
/system ntp client servers
remove [find address=192.168.255.2]
add address=192.168.255.54 comment="K3s Chrony NTP"

# 3. DNS (update forwarders)
/ip dns
set servers=192.168.255.53,1.1.1.1

# 4. Syslog (update remote target)
/system logging action
remove [find name=remote]
add name=remote remote=192.168.255.55 remote-port=514 target=remote

/system logging
add action=remote topics=critical
add action=remote topics=error
add action=remote topics=warning
add action=remote topics=info,!debug

# 5. SNMP (already configured, no change needed)
/snmp set enabled=yes contact="IT ZSEL" location="CPD-B3-CORE-01"
/snmp community
add name=ZSEL-v3 addresses=192.168.255.57/32 \
    security=private authentication-protocol=SHA256 \
    encryption-protocol=AES256

# 6. Backup (add S3 upload)
/system scheduler
add name=backup-to-s3 interval=1d on-event=backup-script \
    start-date=jan/01/2025 start-time=03:00:00

/system script
add name=backup-script source={
    :local backupname ("CS-GW-CPD-01_backup_" . [/system clock get date])
    /system backup save name=$backupname
    :delay 10s
    /tool fetch \
        url="http://192.168.255.56:9000/mikrotik-backups/core/CS-GW-CPD-01/$backupname.backup" \
        mode=http upload=yes src-path=($backupname . ".backup") \
        http-method=put \
        http-header-field="Host: 192.168.255.56:9000" \
        http-header-field="X-Amz-Date: [/system clock get date]" \
        http-header-field="Authorization: AWS4-HMAC-SHA256 Credential=MINIO_ACCESS_KEY/..."
    :log info "Backup uploaded to MinIO S3"
}

# 7. Custom User Groups (for RADIUS role mapping)
/user group
add name=network-admin policy=read,write,ssh,winbox,policy,password,!ftp,!telnet,!api
add name=network-operator policy=read,ssh,winbox,!write,!ftp,!reboot,!sensitive
add name=monitoring-only policy=read,winbox,!write,!ssh,!password,!sensitive
```

### Propagation to Other Devices

**Apply same changes to:**
- All CCR2216 (CS-GW-CPD-01 to 05)
- All CRS518 (CS-SW-AGG-CPD-01 to 06)
- All CRS354 (CS-SW-DIST-P0-01 to P3-04)
- All CRS326 (CS-SW-ACC-SXX-01)
- CRS328 (CS-SW-POE-CPD-01)

**Automation Options:**
1. **Ansible Playbook:** Template Jinja2 config → push via SSH
2. **NETCONF/API:** `/system script run` via REST API
3. **Manual:** Copy-paste via WinBox (13-day deployment plan)

---

## Next Steps

### Phase 1: Design → Implementation (This Document)
- [x] Architecture design
- [x] Service inventory
- [x] VLAN placement strategy
- [x] HA design
- [ ] Review with IT team
- [ ] Approve IP allocations (192.168.255.50-59)

### Phase 2: K3s Manifests Creation
- [ ] Samba AD StatefulSet + ConfigMaps
- [ ] FreeRADIUS Deployment + LDAP config
- [ ] DNS (Bind9) Deployment + zone files
- [ ] NTP (Chrony) DaemonSet
- [ ] Graylog (Elasticsearch + MongoDB + Graylog)
- [ ] Prometheus + SNMP Exporter + AlertManager
- [ ] Grafana + Dashboards
- [ ] MinIO StatefulSet + S3 buckets
- [ ] Kea DHCP Deployment + reservations

### Phase 3: MikroTik Config Updates
- [ ] Update CCR2216-BCU-01.rsc (RADIUS, NTP, DNS, syslog, backup)
- [ ] Create update scripts for all 57 devices
- [ ] Test on lab device first
- [ ] Phased rollout (Core → AGG → DIST → ACC → WiFi)

### Phase 4: Testing & Validation
- [ ] RADIUS auth test (login with AD user)
- [ ] DNS resolution test (zsel.local domain)
- [ ] NTP sync test (time accuracy)
- [ ] Syslog ingestion test (see logs in Graylog)
- [ ] SNMP metrics test (see in Grafana)
- [ ] Backup test (upload to MinIO, verify integrity)
- [ ] HA failover test (kill 1 K3s node, verify services continue)

### Phase 5: Documentation
- [ ] Administrator runbook (K8s operations)
- [ ] Network engineer runbook (MikroTik integration)
- [ ] Troubleshooting guide
- [ ] Disaster recovery procedures

---

## Questions to Resolve

1. **Samba AD Domain Name:** ✅ `ad.zsel.opole.pl` (CONFIRMED)
2. **RADIUS Shared Secret:** Generate during ArgoCD deployment (sealed-secrets)
3. **SNMP v3 Credentials:** Create dedicated service account in Samba AD
4. **Backup Retention:** 30 days in MinIO + 90 days in QNAP (default policy)
5. **Monitoring Alerts:** Email (it@zsel.opole.pl) + optional Slack integration
6. **DHCP Scope:** Only management VLAN 600 (user VLANs via MikroTik DHCP)
7. **DNS Forwarders:** Cloudflare 1.1.1.1 + Google 8.8.8.8 (dual redundancy)
8. **NTP Source:** Polish pool (primary) + European pool (fallback)
9. **Grafana Access:** Internal only (VPN required, no public exposure)
10. **MinIO S3 Encryption:** At-rest encryption enabled (KMS via K8s Secrets)
11. **ArgoCD GitOps:** ✅ All manifests deployment via ArgoCD (CONFIRMED)
12. **Zabbix Monitoring:** ✅ Add Zabbix Server to architecture (REQUIRED)

---

**Status:** 🟡 Awaiting Review  
**Next Action:** Review questions above, then proceed to Phase 2 (manifests)  
**Owner:** Łukasz Kołodziej (Cloud Architect)  
**Reviewers:** IT Team ZSEL + Network Engineer

---

**Document Version:** 1.0  
**Last Updated:** 2025-11-22  
**Related Documents:**
- [../DEPLOYMENT-PLAN.md](../DEPLOYMENT-PLAN.md) - MikroTik deployment timeline
- [../dokumentacja-techniczna/TOPOLOGIA-STRUKTURALNA.md](../dokumentacja-techniczna/TOPOLOGIA-STRUKTURALNA.md) - Network topology
- [../pfu.md](../pfu.md) - PFU naming convention (Section 2.10)
- [./README.md](./README.md) - K3s cluster overview
