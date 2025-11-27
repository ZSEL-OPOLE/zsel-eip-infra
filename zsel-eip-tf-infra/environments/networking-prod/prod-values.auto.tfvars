# =============================================================================
# Terraform Configuration - AUTO-GENERATED
# =============================================================================
# Generated from: common/vlans-master.yaml
# Generator: scripts/generate-terraform.py
# PFU 2.7 COMPLIANT - Physical room numbers (8,9,23-31,41-46) = VLAN 208-246
# DO NOT EDIT MANUALLY - Run generator instead!
# =============================================================================

# ===== MIKROTIK CONNECTION =====
mikrotik_host     = "192.168.255.1"
mikrotik_username = "admin"

# ===== VLANS =====
vlans = {
  # === SALE DYDAKTYCZNE (Teaching Classrooms) 101-104 ===
  "101" = { name = "dydactic-P0", subnet = "192.168.1.0/24" }
  "102" = { name = "dydactic-P1", subnet = "192.168.2.0/24" }
  "103" = { name = "dydactic-P2", subnet = "192.168.3.0/24" }
  "104" = { name = "dydactic-P3", subnet = "192.168.4.0/24" }

  # === TELEWIZORY INFORMACYJNE 110 ===
  "110" = { name = "tv-info", subnet = "192.168.10.0/24" }

  # === PRACOWNIE UCZNIOWSKIE (Labs) 208-246 ===
  # VLAN = Numer SALI FIZYCZNEJ (8,9,23,24,25,26,27,28,30,31,41,42,43,44,46)
  "208" = { name = "lab-8", subnet = "10.8.0.0/16" }
  "209" = { name = "lab-9", subnet = "10.9.0.0/16" }
  "223" = { name = "lab-23", subnet = "10.23.0.0/16" }
  "224" = { name = "lab-24", subnet = "10.24.0.0/16" }
  "225" = { name = "lab-25", subnet = "10.25.0.0/16" }
  "226" = { name = "lab-26", subnet = "10.26.0.0/16" }
  "227" = { name = "lab-27", subnet = "10.27.0.0/16" }
  "228" = { name = "lab-28", subnet = "10.28.0.0/16" }
  "230" = { name = "lab-30", subnet = "10.30.0.0/16" }
  "231" = { name = "lab-31", subnet = "10.31.0.0/16" }
  "241" = { name = "lab-41", subnet = "10.41.0.0/16" }
  "242" = { name = "lab-42", subnet = "10.42.0.0/16" }
  "243" = { name = "lab-43", subnet = "10.43.0.0/16" }
  "244" = { name = "lab-44", subnet = "10.44.0.0/16" }
  "246" = { name = "lab-46", subnet = "10.46.0.0/16" }

  # === WIFI UCZNIOWSKA 300-303 ===
  "300" = { name = "wifi-student-P0", subnet = "10.100.1.0/24" }
  "301" = { name = "wifi-student-P1", subnet = "10.100.2.0/24" }
  "302" = { name = "wifi-student-P2", subnet = "10.100.3.0/24" }
  "303" = { name = "wifi-student-P3", subnet = "10.100.4.0/24" }

  # === SERWERY UCZNIOWSKIE 400-401 ===
  "400" = { name = "server-student-400", subnet = "10.200.100.0/24" }
  "401" = { name = "server-student-401", subnet = "10.200.200.0/24" }

  # === SIEĆ ADMINISTRACYJNA 500 ===
  "500" = { name = "admin", subnet = "172.20.20.0/24" }

  # === KAMERY CCTV 501 ===
  "501" = { name = "cctv", subnet = "172.21.1.0/24" }

  # === ZARZĄDZANIE INFRASTRUKTURĄ 600 ===
  "600" = { name = "management", subnet = "192.168.255.0/28" }
}

# ===== QoS SIMPLE QUEUE (PFU 2.7 Compliant) =====
queue_simple = {
  # === PRACOWNIE (60 Mbps + burst 80 Mbps) ===
  "lab-8" = {
    name            = "QoS-Lab-8"
    target          = "10.8.0.0/16"
    max_limit       = "60M/60M"
    burst_limit     = "80M/80M"
    burst_threshold = "50M/50M"
    burst_time      = "30s"
    priority        = 3
    comment         = "PFU 2.7 - Pracownia 8 (P0, fixed, 32 ports)"
  }
  "lab-9" = {
    name            = "QoS-Lab-9"
    target          = "10.9.0.0/16"
    max_limit       = "60M/60M"
    burst_limit     = "80M/80M"
    burst_threshold = "50M/50M"
    burst_time      = "30s"
    priority        = 3
    comment         = "PFU 2.7 - Pracownia 9 (P0, fixed, 32 ports)"
  }
  "lab-23" = {
    name            = "QoS-Lab-23"
    target          = "10.23.0.0/16"
    max_limit       = "60M/60M"
    burst_limit     = "80M/80M"
    burst_threshold = "50M/50M"
    burst_time      = "30s"
    priority        = 3
    comment         = "PFU 2.7 - Pracownia 23 (P1, fixed, 32 ports)"
  }
  "lab-24" = {
    name            = "QoS-Lab-24"
    target          = "10.24.0.0/16"
    max_limit       = "60M/60M"
    burst_limit     = "80M/80M"
    burst_threshold = "50M/50M"
    burst_time      = "30s"
    priority        = 3
    comment         = "PFU 2.7 - Pracownia 24 (P1, fixed, 32 ports)"
  }
  "lab-25" = {
    name            = "QoS-Lab-25"
    target          = "10.25.0.0/16"
    max_limit       = "60M/60M"
    burst_limit     = "80M/80M"
    burst_threshold = "50M/50M"
    burst_time      = "30s"
    priority        = 3
    comment         = "PFU 2.7 - Pracownia 25 (P1, fixed, 32 ports)"
  }
  "lab-26" = {
    name            = "QoS-Lab-26"
    target          = "10.26.0.0/16"
    max_limit       = "60M/60M"
    burst_limit     = "80M/80M"
    burst_threshold = "50M/50M"
    burst_time      = "30s"
    priority        = 3
    comment         = "PFU 2.7 - Pracownia 26 (P2, fixed, 32 ports)"
  }
  "lab-27" = {
    name            = "QoS-Lab-27"
    target          = "10.27.0.0/16"
    max_limit       = "60M/60M"
    burst_limit     = "80M/80M"
    burst_threshold = "50M/50M"
    burst_time      = "30s"
    priority        = 3
    comment         = "PFU 2.7 - Pracownia 27 (P2, fixed, 32 ports)"
  }
  "lab-28" = {
    name            = "QoS-Lab-28"
    target          = "10.28.0.0/16"
    max_limit       = "60M/60M"
    burst_limit     = "80M/80M"
    burst_threshold = "50M/50M"
    burst_time      = "30s"
    priority        = 3
    comment         = "PFU 2.7 - Pracownia 28 (P2, fixed, 32 ports)"
  }
  "lab-30" = {
    name            = "QoS-Lab-30"
    target          = "10.30.0.0/16"
    max_limit       = "60M/60M"
    burst_limit     = "80M/80M"
    burst_threshold = "50M/50M"
    burst_time      = "30s"
    priority        = 3
    comment         = "PFU 2.7 - Pracownia 30 (P2, fixed, 20 ports)"
  }
  "lab-31" = {
    name            = "QoS-Lab-31"
    target          = "10.31.0.0/16"
    max_limit       = "60M/60M"
    burst_limit     = "80M/80M"
    burst_threshold = "50M/50M"
    burst_time      = "30s"
    priority        = 3
    comment         = "PFU 2.7 - Pracownia 31 (P2, fixed, 32 ports)"
  }
  "lab-41" = {
    name            = "QoS-Lab-41"
    target          = "10.41.0.0/16"
    max_limit       = "60M/60M"
    burst_limit     = "80M/80M"
    burst_threshold = "50M/50M"
    burst_time      = "30s"
    priority        = 3
    comment         = "PFU 2.7 - Pracownia 41 (P3, mobile, 18 ports)"
  }
  "lab-42" = {
    name            = "QoS-Lab-42"
    target          = "10.42.0.0/16"
    max_limit       = "60M/60M"
    burst_limit     = "80M/80M"
    burst_threshold = "50M/50M"
    burst_time      = "30s"
    priority        = 3
    comment         = "PFU 2.7 - Pracownia 42 (P3, fixed, 32 ports)"
  }
  "lab-43" = {
    name            = "QoS-Lab-43"
    target          = "10.43.0.0/16"
    max_limit       = "60M/60M"
    burst_limit     = "80M/80M"
    burst_threshold = "50M/50M"
    burst_time      = "30s"
    priority        = 3
    comment         = "PFU 2.7 - Pracownia 43 (P3, mobile, 18 ports)"
  }
  "lab-44" = {
    name            = "QoS-Lab-44"
    target          = "10.44.0.0/16"
    max_limit       = "60M/60M"
    burst_limit     = "80M/80M"
    burst_threshold = "50M/50M"
    burst_time      = "30s"
    priority        = 3
    comment         = "PFU 2.7 - Pracownia 44 (P3, mobile, 18 ports)"
  }
  "lab-46" = {
    name            = "QoS-Lab-46"
    target          = "10.46.0.0/16"
    max_limit       = "60M/60M"
    burst_limit     = "80M/80M"
    burst_threshold = "50M/50M"
    burst_time      = "30s"
    priority        = 3
    comment         = "PFU 2.7 - Pracownia 46 (P3, mobile, 18 ports)"
  }

  # === SALE DYDAKTYCZNE (1000 Mbps per piętro) ===
  "dydactic-P0" = {
    name      = "QoS-Dydactic-P0"
    target    = "192.168.1.0/24"
    max_limit = "1000M/1000M"
    priority  = 2
    comment   = "PFU 2.7 - Sale dydaktyczne P0"
  }
  "dydactic-P1" = {
    name      = "QoS-Dydactic-P1"
    target    = "192.168.2.0/24"
    max_limit = "1000M/1000M"
    priority  = 2
    comment   = "PFU 2.7 - Sale dydaktyczne P1"
  }
  "dydactic-P2" = {
    name      = "QoS-Dydactic-P2"
    target    = "192.168.3.0/24"
    max_limit = "1000M/1000M"
    priority  = 2
    comment   = "PFU 2.7 - Sale dydaktyczne P2"
  }
  "dydactic-P3" = {
    name      = "QoS-Dydactic-P3"
    target    = "192.168.4.0/24"
    max_limit = "1000M/1000M"
    priority  = 2
    comment   = "PFU 2.7 - Sale dydaktyczne P3"
  }

  # === WIFI UCZNIOWSKA (200 Mbps per piętro) ===
  "wifi-P0" = {
    name      = "QoS-WiFi-P0"
    target    = "10.100.1.0/24"
    max_limit = "200M/200M"
    priority  = 1
    comment   = "PFU 2.7 - WiFi uczniowska P0"
  }
  "wifi-P1" = {
    name      = "QoS-WiFi-P1"
    target    = "10.100.2.0/24"
    max_limit = "200M/200M"
    priority  = 1
    comment   = "PFU 2.7 - WiFi uczniowska P1"
  }
  "wifi-P2" = {
    name      = "QoS-WiFi-P2"
    target    = "10.100.3.0/24"
    max_limit = "200M/200M"
    priority  = 1
    comment   = "PFU 2.7 - WiFi uczniowska P2"
  }
  "wifi-P3" = {
    name      = "QoS-WiFi-P3"
    target    = "10.100.4.0/24"
    max_limit = "200M/200M"
    priority  = 1
    comment   = "PFU 2.7 - WiFi uczniowska P3"
  }
}

# ===== BGP CONFIGURATION (MetalLB Peering) =====
bgp_instances = {
  "default" = {
    as       = 65000
    disabled = false
  }
}

bgp_peers = {
  "k3s-master-01" = {
    remote_address = "10.20.0.11"
    remote_as      = 65001
    hold_time      = "3m"
    keepalive_time = "1m"
  }
  "k3s-master-02" = {
    remote_address = "10.20.0.12"
    remote_as      = 65001
    hold_time      = "3m"
    keepalive_time = "1m"
  }
  "k3s-master-03" = {
    remote_address = "10.20.0.13"
    remote_as      = 65001
    hold_time      = "3m"
    keepalive_time = "1m"
  }
}

bgp_networks = {
  "network-10-22-0" = {
    network = "10.22.0.0/24"
    comment = "MetalLB PROD LoadBalancer pool"
  }
  "network-10-12-0" = {
    network = "10.12.0.0/24"
    comment = "MetalLB DEV LoadBalancer pool"
  }
  "network-10-32-0" = {
    network = "10.32.0.0/24"
    comment = "MetalLB ADM LoadBalancer pool"
  }
  "network-10-20-0" = {
    network = "10.20.0.0/22"
    comment = "K3s services network"
  }
}
