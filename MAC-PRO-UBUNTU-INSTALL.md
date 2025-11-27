# 🍎🐧 Mac Pro M2 Ultra: Dual-Boot macOS + Ubuntu 24.04 ARM64

**Cel:** Powtarzalna instalacja Ubuntu Server 24.04 ARM64 w dual-boot (zachowaj macOS!)  
**Czas:** ~60 minut per maszyna (40 min automated, 20 min manual)  
**Poziom trudności:** ⭐⭐⭐⭐ (zaawansowany - wymaga precyzji)

---

## ⚠️ OSTRZEŻENIE - Przeczytaj przed rozpoczęciem!

### 🟢 BEZPIECZNE - Dual-Boot:
- ✅ **macOS zostanie zachowany** (bezpieczny fallback)
- ✅ **Dane macOS nienaruszone** (osobne partycje)
- ✅ **Boot menu** (wybór systemu przy starcie)
- ✅ **Możliwość powrotu** (usuń Ubuntu partition)
- ⚠️ **Priorytet na Ubuntu** (domyślny boot)

### 🔴 RYZYKO (minimalne, ale istnieje):
- ⚠️ **Partycjonowanie dysku** (błąd = utrata danych, BACKUP FIRST!)
- ⚠️ **Bootloader** (GRUB zastąpi Apple boot manager)
- ⚠️ **Gwarancja Apple** (instalacja non-Apple OS może void warranty)

### ✅ Wymagania:
- Mac Pro M2 Ultra (Apple Silicon ARM64)
- **Min. 1 TB wolnego miejsca** (dla Ubuntu partition)
- **BACKUP macOS** (Time Machine lub clone dysku!)
- USB drive (min 8 GB, USB 3.0+)
- Laptop pomocniczy (Windows/macOS/Linux)
- Kabel Ethernet (do internetu)
- Klawiatura + monitor (USB-C lub HDMI)

### 📋 Co będzie działać w Ubuntu:
- ✅ CPU (24 cores, pełna moc)
- ✅ RAM (192 GB, wszystko dostępne)
- ✅ NVMe SSD (pełna prędkość)
- ✅ Ethernet (10 Gbps)
- ✅ USB-C ports
- ⚠️ GPU (ograniczona obsługa, brak akceleracji Metal)
- ❌ Wi-Fi (może nie działać, użyj Ethernet)
- ❌ Bluetooth (może nie działać)
- ❌ TouchID (nie działa)

---

## 📋 Część 1: Przygotowanie (1 godzina, raz dla wszystkich)

### Krok 1.0: BACKUP macOS (KRYTYCZNE!)

**NAJPIERW BACKUP - potem instalacja!**

```bash
# Opcja 1: Time Machine (zalecane)
# System Settings → General → Time Machine → Back Up Now
# Czekaj: ~2-4 godziny (zależnie od danych)

# Opcja 2: Carbon Copy Cloner (clone dysku)
# Pobierz: https://bombich.com/
# Clone entire macOS partition → external drive

# Opcja 3: Manual backup (szybkie, ważne pliki)
rsync -av ~/Documents /Volumes/BackupDrive/
rsync -av ~/Desktop /Volumes/BackupDrive/
```

**⚠️ NIE KONTYNUUJ bez backupu!**

---

### Krok 1.1: Sprawdź wolne miejsce

**Na każdym Mac Pro (w macOS):**

```bash
# Sprawdź dostępne miejsce:
df -h /
# Output: /dev/disk3s1  8.0Ti  2.5Ti  5.5Ti  31% /

# Potrzeba: min. 1 TB wolnego dla Ubuntu
# Zalecane: 2 TB (dla K3s storage + apps)
```

**Jeśli za mało miejsca:**
```bash
# Wyczyść cache, stare pliki:
sudo rm -rf ~/Library/Caches/*
sudo rm -rf /Library/Caches/*
brew cleanup  # jeśli masz Homebrew
```

---

### Krok 1.2: Zbierz MAC adresy

**Na każdym Mac Pro (w macOS):**

```bash
# Ethernet MAC address
ifconfig en0 | grep ether
# Output: ether aa:bb:cc:dd:ee:ff

# Zapisz w pliku:
echo "k3s-master-01: $(ifconfig en0 | grep ether | awk '{print $2}')" >> mac-addresses.txt
```

**Powtórz dla wszystkich 9 maszyn, zapisz wynik:**

```
k3s-master-01: aa:bb:cc:dd:ee:01
k3s-master-02: aa:bb:cc:dd:ee:02
k3s-master-03: aa:bb:cc:dd:ee:03
k3s-worker-01: aa:bb:cc:dd:ee:04
k3s-worker-02: aa:bb:cc:dd:ee:05
k3s-worker-03: aa:bb:cc:dd:ee:06
k3s-worker-04: aa:bb:cc:dd:ee:07
k3s-worker-05: aa:bb:cc:dd:ee:08
k3s-worker-06: aa:bb:cc:dd:ee:09
```

---

### Krok 1.3: Pobierz Ubuntu 24.04 ARM64

**Na laptopie pomocniczym:**

```bash
# Ubuntu Server 24.04 LTS ARM64
wget https://cdimage.ubuntu.com/releases/24.04/release/ubuntu-24.04-live-server-arm64.iso

# Weryfikacja (opcjonalnie):
sha256sum ubuntu-24.04-live-server-arm64.iso
# Porównaj z: https://cdimage.ubuntu.com/releases/24.04/release/SHA256SUMS
```

---

### Krok 1.4: Przygotuj USB bootable

**Windows (Rufus):**
```
1. Pobierz Rufus: https://rufus.ie/
2. Uruchom Rufus
3. Device: Wybierz USB drive
4. Boot selection: SELECT → ubuntu-24.04-live-server-arm64.iso
5. Partition scheme: GPT
6. Target system: UEFI (non CSM)
7. File system: FAT32
8. START → Zapisz w ISO Image mode
9. Czekaj 5-10 minut
```

**macOS (dd):**
```bash
# Znajdź USB drive
diskutil list
# Output: /dev/disk2 (external, physical)

# Unmount (NIE eject!)
diskutil unmountDisk /dev/disk2

# Zapisz ISO (UWAGA: to zajmie 10-15 minut, brak progressu!)
sudo dd if=ubuntu-24.04-live-server-arm64.iso of=/dev/rdisk2 bs=1m
# rdisk2 = raw device (szybszy niż disk2)

# Sync (upewnij się że dane zapisane)
sync

# Eject
diskutil eject /dev/disk2
```

**Linux (dd):**
```bash
# Znajdź USB drive
lsblk
# Output: sdb (8GB, USB)

# Zapisz ISO
sudo dd if=ubuntu-24.04-live-server-arm64.iso of=/dev/sdb bs=4M status=progress
# Status=progress pokazuje postęp

# Sync
sync

# Eject
sudo eject /dev/sdb
```

---

### Krok 1.5: Przygotuj partycje w macOS (WAŻNE!)

**Na każdym Mac Pro (w macOS Terminal):**

```bash
# 1. Sprawdź aktualny layout:
diskutil list
# Output (przykład):
# /dev/disk0 (internal, physical):
#    #:  TYPE NAME          SIZE       IDENTIFIER
#    0:  GUID_partition    *8.0 TB     disk0
#    1:  EFI EFI           314.6 MB   disk0s1
#    2:  APFS Container    7.5 TB     disk0s2

# 2. Zmniejsz macOS partition (create 2 TB free space):
sudo diskutil apfs resizeContainer disk0s2 6.0T

# UWAGA: To zajmie 10-30 minut! Nie przerywaj!

# 3. Sprawdź wynik:
diskutil list
# Output (po resize):
# /dev/disk0 (internal, physical):
#    #:  TYPE NAME          SIZE       IDENTIFIER
#    0:  GUID_partition    *8.0 TB     disk0
#    1:  EFI EFI           314.6 MB   disk0s1
#    2:  APFS Container    6.0 TB     disk0s2  ← zmniejszone
#    3:  (free space)      2.0 TB               ← dla Ubuntu!

# 4. Stwórz placeholder partition (Ubuntu installer to override):
sudo diskutil addVolume disk0 ExFAT UBUNTU_PLACEHOLDER 2T

# 5. Weryfikacja:
diskutil list disk0
# Powinno być 4 partitions: EFI, macOS, Ubuntu placeholder
```

**⚠️ KRYTYCZNE:**
- **NIE** usuwaj EFI partition (disk0s1) - Mac nie zbootuje!
- **NIE** ruszaj macOS partition (disk0s2) - utrata danych!
- Resize może zająć 30+ minut na 8 TB dysku

---

### Krok 1.6: Przygotuj preseed/cloud-init (AUTOMATYZACJA!)

**Stwórz plik `user-data` (cloud-init config):**

```yaml
#cloud-config
autoinstall:
  version: 1
  
  # Locale & keyboard
  locale: pl_PL.UTF-8
  keyboard:
    layout: pl
  
  # Network (DHCP podczas instalacji, później static)
  network:
    version: 2
    ethernets:
      enp0s0:  # Może być inna nazwa, sprawdź ip link show
        dhcp4: true
  
  # User account (zmień hasło!)
  identity:
    hostname: HOSTNAME_PLACEHOLDER
    username: admin
    password: "$6$rounds=4096$SALT$HASH"  # Wygeneruj poniżej!
  
  # SSH
  ssh:
    install-server: true
    allow-pw: true
    authorized-keys:
      - "ssh-ed25519 AAAAC3...YOUR_PUBLIC_KEY"  # Dodaj swój klucz SSH!
  
  # Storage (RĘCZNE - dual-boot z macOS!)
  # UWAGA: Używamy placeholder partition stworzonej w Krok 1.5
  storage:
    layout:
      name: lvm
      match:
        # Użyj FREE SPACE (nie całego dysku!)
        # Installer wykryje partition "UBUNTU_PLACEHOLDER"
        path: /dev/nvme0n1p4  # lub p3, sprawdź: lsblk
  
  # Packages (instaluj od razu)
  packages:
    - vim
    - curl
    - wget
    - htop
    - net-tools
    - iotop
    - sysstat
    - python3
    - python3-pip
    - git
    - nfs-common
    - open-iscsi
  
  # Late commands (wykonaj po instalacji)
  late-commands:
    # Disable swap (K3s requirement)
    - swapoff -a
    - sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
    
    # Enable IP forwarding (K3s requirement)
    - echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    - echo "net.bridge.bridge-nf-call-iptables=1" >> /etc/sysctl.conf
    
    # Load kernel modules (K3s requirement)
    - echo "overlay" >> /etc/modules-load.d/k8s.conf
    - echo "br_netfilter" >> /etc/modules-load.d/k8s.conf
    
    # Disable firewall (będzie NetworkPolicy w K8s)
    - systemctl disable ufw
    - systemctl stop ufw
  
  # Reboot after install
  power:
    delay: now
    mode: reboot
    condition: true
```

**Wygeneruj hasło (na laptopie):**

```bash
# Python3 (cross-platform):
python3 -c "import crypt; print(crypt.crypt('TwojeHaslo123!', crypt.mksalt(crypt.METHOD_SHA512)))"

# Output (przykład):
$6$rounds=4096$abc123$def456...

# Skopiuj ten hash do user-data (pole password)
```

**Wygeneruj klucz SSH (jeśli nie masz):**

```bash
# Ed25519 (zalecany, krótki, bezpieczny)
ssh-keygen -t ed25519 -C "admin@zsel-k3s"
# Output: ~/.ssh/id_ed25519.pub

# Skopiuj zawartość do user-data (pole authorized-keys)
cat ~/.ssh/id_ed25519.pub
```

---

### Krok 1.7: Dodaj preseed do USB

**Mount USB ponownie:**

```bash
# Windows: Otwórz USB w Explorerze, stwórz folder `nocloud`
# Linux/macOS:
mkdir -p /mnt/usb
mount /dev/sdb1 /mnt/usb  # lub disk2s1 na macOS
mkdir -p /mnt/usb/nocloud
```

**Skopiuj pliki:**

```bash
# user-data (ZMIEŃ HOSTNAME dla każdej maszyny!)
cp user-data /mnt/usb/nocloud/user-data

# meta-data (pusty, ale wymagany)
touch /mnt/usb/nocloud/meta-data

# Unmount
umount /mnt/usb  # lub diskutil unmount na macOS
```

---

## 🚀 Część 2: Instalacja (45 minut per maszyna)

### Krok 2.1: Boot z USB

**Na Mac Pro:**

1. **Wyłącz Mac Pro** (całkowicie)
2. **Podłącz USB bootable**
3. **Trzymaj klawisz Power** (10 sekund) → pojawi się boot menu
4. **Wybierz "EFI Boot"** (USB drive)
5. **Czekaj 30 sekund** → pojawi się GRUB menu

**Jeśli nie działa boot z USB:**
- Sprawdź czy USB jest GPT + UEFI (nie MBR + BIOS)
- Spróbuj innego portu USB-C
- Niektóre Mac Pro wymagają adaptera USB-C → USB-A

---

### Krok 2.2: Instalacja (40 minut) - DUAL-BOOT!

**W GRUB menu:**

1. Wybierz **"Try or Install Ubuntu Server"**
2. **Poczekaj 2 minuty** → pojawi się installer
3. **Wybierz język:** Polski (lub English)

**⚠️ KRYTYCZNE - Storage Configuration (RĘCZNA!):**

```
Ubuntu Installer → Storage Configuration:

1. Wybierz: "Custom storage layout" (NIE "Use entire disk"!)
2. Znajdź partition "UBUNTU_PLACEHOLDER" (2 TB, ExFAT)
3. Delete partition "UBUNTU_PLACEHOLDER"
4. Stwórz nowe partitions w FREE SPACE:
   
   Partition 1: EXT4 (root filesystem)
   - Mount point: /
   - Size: 1.8 TB
   - Format: ext4
   
   Partition 2: SWAP (optional, ale zalecane)
   - Type: swap
   - Size: 200 GB
   
5. ⚠️ SPRAWDŹ:
   - EFI partition (300 MB) → NIE formatuj, NIE ruszaj!
   - macOS partition (6 TB, APFS) → NIE formatuj, NIE ruszaj!
   - Ubuntu / (1.8 TB, ext4) → format, mount /
   - Swap (200 GB) → format

6. CONFIRM → "Continue" (sprawdź 3× przed potwierdzeniem!)
```

**Co się dzieje (po confirmation):**
```
[00:00-05:00] Formatowanie Ubuntu partitions (ext4, swap)
[05:00-20:00] Instalacja pakietów base
[20:00-30:00] Instalacja dodatkowych pakietów
[30:00-35:00] Konfiguracja systemu
[35:00-40:00] Install GRUB bootloader (DUAL-BOOT!)
[40:00-42:00] Reboot
```

**WAŻNE:** NIE WYCIĄGAJ USB podczas instalacji!

---

### Krok 2.3: First boot - GRUB Boot Menu (5 minut)

**Po reboot:**

1. **Usuń USB drive** (teraz!)
2. **Pojawi się GRUB menu** (dual-boot selector):
   ```
   GNU GRUB version 2.06
   
   → Ubuntu 24.04 LTS               ← DEFAULT (priorytet)
     Advanced options for Ubuntu
     macOS
     UEFI Firmware Settings
   ```
3. **Domyślnie** (po 5 sekundach): Ubuntu bootuje automatycznie
4. **Aby wybrać macOS**: Strzałka w dół → Enter

**Test logowania (w Ubuntu):**

```bash
# Login lokalnie (monitor + klawiatura):
Username: admin
Password: [twoje hasło z preseed]

# Sprawdź hostname:
hostname
# Output: HOSTNAME_PLACEHOLDER (bo nie zmieniłeś w preseed!)

# Sprawdź IP (DHCP):
ip addr show
# Output: 192.168.x.y (lub 10.x.y.z)

# Sprawdź partycje (weryfikacja dual-boot):
lsblk
# Output:
# nvme0n1           8T  0 disk
# ├─nvme0n1p1     300M  0 part  /boot/efi  ← EFI (shared)
# ├─nvme0n1p2       6T  0 part             ← macOS (nietknięty!)
# ├─nvme0n1p3     1.8T  0 part  /          ← Ubuntu root
# └─nvme0n1p4     200G  0 part  [SWAP]     ← Ubuntu swap
```

**✅ Dual-boot działa!** macOS i Ubuntu na jednym dysku.

---

### Krok 2.4: Ustaw Ubuntu jako domyślny OS (2 minuty)

**W Ubuntu (po pierwszym boot):**

```bash
# 1. Sprawdź aktualny default:
sudo grep GRUB_DEFAULT /etc/default/grub
# Output: GRUB_DEFAULT=0  ← 0 = Ubuntu (już OK!)

# 2. Zmień timeout (opcjonalnie, default 5 sekund):
sudo nano /etc/default/grub
# Zmień: GRUB_TIMEOUT=5 → GRUB_TIMEOUT=3 (szybszy boot)

# 3. Update GRUB:
sudo update-grub

# 4. Reboot test:
sudo reboot
# Po reboot: Ubuntu bootuje automatycznie po 3 sekundach
```

**Aby zmienić priorytet na macOS (jeśli potrzeba):**
```bash
# macOS jako default (rzadko potrzebne):
sudo nano /etc/default/grub
# Zmień: GRUB_DEFAULT=0 → GRUB_DEFAULT=2  (2 = macOS w menu)
sudo update-grub
```

---

### Krok 2.5: Post-install config (10 minut per maszyna)

**SSH z laptopa (wygodniejsze niż lokalnie):**

```bash
# Find IP (jeśli nie wiesz):
nmap -sn 192.168.10.0/24  # Scan sieci

# SSH:
ssh admin@192.168.10.11  # IP z DHCP

# Lub użyj klucza SSH:
ssh -i ~/.ssh/id_ed25519 admin@192.168.10.11
```

**Na każdej maszynie (przez SSH):**

```bash
# 1. Zmień hostname (WAŻNE!)
sudo hostnamectl set-hostname k3s-master-01  # lub worker-01, worker-02, ...

# 2. Configure static IP (VLAN 110)
sudo nano /etc/netplan/00-installer-config.yaml

# Zawartość (przykład dla k3s-master-01):
network:
  version: 2
  ethernets:
    enp0s0:  # Sprawdź nazwę: ip link show
      addresses:
        - 192.168.10.11/24  # Static IP
      routes:
        - to: default
          via: 192.168.10.1  # Gateway (router)
      nameservers:
        addresses:
          - 8.8.8.8
          - 8.8.4.4

# Apply:
sudo netplan apply

# 3. Verify:
ip addr show enp0s0
# Output: inet 192.168.10.11/24

# 4. Test connectivity:
ping 192.168.10.1    # Gateway
ping 8.8.8.8         # Internet
ping google.com      # DNS

# 5. Update system:
sudo apt update && sudo apt upgrade -y

# 6. Reboot:
sudo reboot
```

---

## 🔄 Część 3: Automatyzacja (script dla wszystkich maszyn)

### Quick deploy script (execute na laptopie):

```bash
#!/bin/bash
# install-all-mac-pros.sh

NODES=(
  "k3s-master-01:192.168.10.11:aa:bb:cc:dd:ee:01"
  "k3s-master-02:192.168.10.12:aa:bb:cc:dd:ee:02"
  "k3s-master-03:192.168.10.13:aa:bb:cc:dd:ee:03"
  "k3s-worker-01:192.168.10.14:aa:bb:cc:dd:ee:04"
  "k3s-worker-02:192.168.10.15:aa:bb:cc:dd:ee:05"
  "k3s-worker-03:192.168.10.16:aa:bb:cc:dd:ee:06"
  "k3s-worker-04:192.168.10.17:aa:bb:cc:dd:ee:07"
  "k3s-worker-05:192.168.10.18:aa:bb:cc:dd:ee:08"
  "k3s-worker-06:192.168.10.19:aa:bb:cc:dd:ee:09"
)

for node in "${NODES[@]}"; do
  IFS=':' read -r hostname ip mac <<< "$node"
  
  echo "=== Installing $hostname ($ip) ==="
  
  # 1. Generate user-data with hostname
  sed "s/HOSTNAME_PLACEHOLDER/$hostname/g" user-data.template > user-data
  
  # 2. Copy to USB (manual: insert USB, run this)
  # cp user-data /mnt/usb/nocloud/user-data
  
  echo "USB ready for $hostname. Boot Mac Pro from USB, then press Enter..."
  read
  
  # 3. Wait for installation (30 minutes)
  echo "Waiting 30 minutes for automated installation..."
  sleep 1800
  
  # 4. Configure static IP (after first boot)
  echo "Configuring $hostname..."
  
  # Wait for SSH (retry 10 times)
  for i in {1..10}; do
    if ssh -o StrictHostKeyChecking=no admin@$ip "echo OK" 2>/dev/null; then
      break
    fi
    echo "Waiting for SSH ($i/10)..."
    sleep 30
  done
  
  # Configure static IP
  ssh admin@$ip << EOF
    sudo hostnamectl set-hostname $hostname
    
    sudo tee /etc/netplan/00-installer-config.yaml > /dev/null << 'NETPLAN'
network:
  version: 2
  ethernets:
    enp0s0:
      addresses:
        - $ip/24
      routes:
        - to: default
          via: 192.168.10.1
      nameservers:
        addresses:
          - 8.8.8.8
          - 8.8.4.4
NETPLAN
    
    sudo netplan apply
    sudo apt update && sudo apt upgrade -y
    sudo reboot
EOF
  
  echo "$hostname configured! Moving to next node..."
  sleep 60
done

echo "=== ALL NODES INSTALLED ==="
```

---

## ✅ Część 4: Weryfikacja (10 minut)

### Check all nodes:

```bash
#!/bin/bash
# verify-all-nodes.sh

NODES=(
  "k3s-master-01:192.168.10.11"
  "k3s-master-02:192.168.10.12"
  "k3s-master-03:192.168.10.13"
  "k3s-worker-01:192.168.10.14"
  "k3s-worker-02:192.168.10.15"
  "k3s-worker-03:192.168.10.16"
  "k3s-worker-04:192.168.10.17"
  "k3s-worker-05:192.168.10.18"
  "k3s-worker-06:192.168.10.19"
)

echo "=== VERIFYING ALL NODES ==="

for node in "${NODES[@]}"; do
  IFS=':' read -r hostname ip <<< "$node"
  
  echo -n "$hostname ($ip): "
  
  if ssh -o ConnectTimeout=5 admin@$ip "
    hostname=$(hostname)
    kernel=$(uname -r)
    cpu=$(nproc)
    ram=$(free -h | grep Mem | awk '{print \$2}')
    disk=$(df -h / | tail -1 | awk '{print \$2}')
    echo \"✅ OK - \$hostname | Kernel: \$kernel | CPU: \$cpu cores | RAM: \$ram | Disk: \$disk\"
  " 2>/dev/null; then
    :
  else
    echo "❌ FAILED - Cannot SSH"
  fi
done

echo "=== VERIFICATION COMPLETE ==="
```

**Expected output:**
```
k3s-master-01 (192.168.10.11): ✅ OK - k3s-master-01 | Kernel: 6.8.0 | CPU: 24 cores | RAM: 192G | Disk: 7.3T
k3s-master-02 (192.168.10.12): ✅ OK - k3s-master-02 | Kernel: 6.8.0 | CPU: 24 cores | RAM: 192G | Disk: 7.3T
...
```

---

## 📋 Troubleshooting

### Problem: USB nie bootuje
```
Rozwiązanie:
1. Sprawdź czy USB jest GPT + UEFI (nie MBR)
2. Użyj Rufus/Etcher zamiast dd
3. Spróbuj innego portu USB-C
4. Reset NVRAM: Power + Option + Command + R (10 sekund)
```

### Problem: Nie widzę FREE SPACE podczas partycjonowania
```
Rozwiązanie:
1. Sprawdź w macOS: diskutil list (czy resize się udał?)
2. Sprawdź w Ubuntu installer: lsblk (czy partition UBUNTU_PLACEHOLDER istnieje?)
3. Jeśli nie ma: Wróć do macOS, powtórz Krok 1.5 (resize + create partition)
```

### Problem: Installer chce sformatować cały dysk!
```
STOP! NIE KONTYNUUJ!
Rozwiązanie:
1. Wybierz "Custom storage layout" (NIE "Use entire disk")
2. Manually select tylko Ubuntu partition (UBUNTU_PLACEHOLDER)
3. NIGDY nie formatuj EFI (nvme0n1p1) ani macOS (nvme0n1p2)!
```

### Problem: Po instalacji bootuje macOS zamiast Ubuntu
```
Rozwiązanie:
1. Hold Power → Boot menu → wybierz "EFI Boot"
2. W GRUB menu → wybierz Ubuntu
3. Po boot Ubuntu: sudo update-grub (rebuild boot order)
4. Reboot → powinno bootować Ubuntu domyślnie
```

### Problem: GRUB nie wykrywa macOS
```
Rozwiązanie:
sudo apt install os-prober
sudo os-prober  # Skanuj inne OS
sudo update-grub  # Rebuild GRUB menu
sudo reboot
# macOS powinien pojawić się w GRUB menu
```

### Problem: Nie mogę wrócić do macOS
```
Rozwiązanie:
1. Hold Power podczas boot → pojawi się boot menu
2. Wybierz "Macintosh HD" (macOS partition)
3. Lub w GRUB menu → wybierz "macOS"
4. Jeśli GRUB nie startuje: Reset NVRAM (Power + Opt + Cmd + R)
```

### Problem: Instalacja zawiesza się
```
Rozwiązanie:
1. Sprawdź czy Ethernet jest podłączony (instalator potrzebuje internetu)
2. Sprawdź czy preseed jest poprawny (syntax error w YAML?)
3. Przerwij instalację (Ctrl+C), uruchom manual install
```

### Problem: Nie mogę SSH po instalacji
```
Rozwiązanie:
1. Sprawdź IP: ip addr show
2. Sprawdź firewall: sudo ufw status (powinno być inactive)
3. Sprawdź SSH service: sudo systemctl status ssh
4. Sprawdź klucz SSH: cat ~/.ssh/authorized_keys
```

### Problem: Static IP nie działa
```
Rozwiązanie:
1. Sprawdź nazwę interfejsu: ip link show (może być eno0, eth0, enp0s0)
2. Sprawdź syntax netplan: sudo netplan --debug apply
3. Sprawdź logi: sudo journalctl -u systemd-networkd
```

---

## 🎯 Timeline & Checklist

### Day 1: Preparation (3-4 hours)
- [ ] **BACKUP macOS** (Time Machine lub clone) - KRYTYCZNE!
- [ ] Sprawdź wolne miejsce (min 1 TB per Mac Pro)
- [ ] Zbierz MAC addresses (9× maszyn)
- [ ] Pobierz Ubuntu 24.04 ARM64 ISO
- [ ] Przygotuj USB bootable
- [ ] Stwórz preseed (user-data)
- [ ] Wygeneruj hasło + SSH key
- [ ] **Resize partitions w macOS** (create 2 TB free space per machine)
- [ ] Test dual-boot na 1 maszynie (pilot)

### Day 2-3: Mass Installation (6-8 hours per day)
- [ ] Install k3s-master-01 (60 min - dual-boot)
- [ ] Install k3s-master-02 (60 min - dual-boot)
- [ ] Install k3s-master-03 (60 min - dual-boot)
- [ ] Install k3s-worker-01 (60 min - dual-boot)
- [ ] Install k3s-worker-02 (60 min - dual-boot)
- [ ] Install k3s-worker-03 (60 min - dual-boot)
- [ ] Install k3s-worker-04 (60 min - dual-boot)
- [ ] Install k3s-worker-05 (60 min - dual-boot)
- [ ] Install k3s-worker-06 (60 min - dual-boot)

### Day 4: Verification & Network Config (2-3 hours)
- [ ] Verify all nodes (SSH, hostname, IP)
- [ ] Test dual-boot (reboot → GRUB menu → macOS accessible)
- [ ] Configure VLAN 110 on switches
- [ ] Test connectivity (ping all-to-all)
- [ ] Update vlans-master.yaml (MAC addresses)
- [ ] **Document rollback** (jak wrócić do macOS only)

---

## 📞 Support

**Issues?**
- Ubuntu ARM forums: https://discourse.ubuntu.com/c/arm/17
- Asahi Linux (Mac ARM): https://asahilinux.org/ (inspiracja, nie używamy)

**Ready dla K3s installation?** Następny krok: `K3S-INSTALL-ANSIBLE.md` 🚀
