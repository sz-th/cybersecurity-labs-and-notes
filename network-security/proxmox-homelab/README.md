# Proxmox Homelab — sieć, OPNsense, forensics

Dokumentacja prywatnego labu security na Proxmox VE. Konfiguracja z backupu `A:\LabBackup\` (2026-06-30). Hasła, klucze TLS/VPN i recovery keys nie są publikowane.

## Topologia

```
Sieć domowa (192.168.1.0/24)
└── Host Proxmox (192.168.1.19, vmbr0)
    ├── vmbr0 — upstream, bridge na eno1
    └── vmbr1 — izolowana sieć labu (dummy0)
        ├── VM 100 download (192.168.10.15) — Debian, stacja pobierania
        ├── VM 200 Router (OPNsense) — dual-homed: vmbr0 (WAN) + vmbr1 (LAN)
        │   ├── LAN:  192.168.10.1/24 — sieć downloadera
        │   └── LAB_NET (VLAN 10): 192.168.20.1/24 — sieć forensics
        └── VM 300 lab (192.168.20.10, VLAN tag 10) — REMnux, stacja RE/forensics
```

### Przepływ ruchu

```
[Internet] ←WAN DHCP→ [OPNsense VM200]
                          ├── LAN 192.168.10.0/24 → VM100 download
                          └── VLAN10 192.168.20.0/24 → VM300 lab

VM100 → tylko HTTP/HTTPS na WAN + SCP (22) do VM300
VM300 → brak NAT na WAN (izolacja labu)
VM100 ↛ sieć domowa, ↛ router GUI, ↛ reszta LAN
```

## VM — podsumowanie

| VMID | Nazwa | RAM | Dysk | Sieć | Rola |
|------|-------|-----|------|------|------|
| 100 | download | 4096 MB | 32 GB | vmbr1, 192.168.10.15/24 | Pobieranie próbek, izolowany egress |
| 200 | Router | 4096 MB | 32 GB | vmbr0 + vmbr1 | OPNsense — firewall, NAT, VLAN |
| 300 | lab | 4096 MB | 100 GB | vmbr1 tag=10, 192.168.20.10/24 | Forensics / RE (REMnux) |

## Pliki w repo

| Ścieżka | Opis |
|---------|------|
| `host/interfaces.example` | Mosty vmbr0/vmbr1 na hoście Proxmox |
| `host/qemu-server/*.conf` | Konfiguracje VM (z backupu, bez haseł cloud-init) |
| `guests/vm300-lab/security-tools.txt` | Pakiety security/forensics na VM300 |
| `opnsense/README.md` | OPNsense — interfejsy, VLAN, reguły |
| `opnsense/firewall-rules-summary.md` | Skrót reguł firewall + NAT |
| `opnsense/interfaces-excerpt.xml` | Fragment config.xml (bez haseł i certów) |

## Host Proxmox — mosty

```
vmbr0 (192.168.1.19/24) — upstream, eno1
vmbr1 (bez IP) — izolacja labu, dummy0 + tapy VM
```

Mosty z `brctl-show` (backup):

```
vmbr0 → eno1, fwpr200p0 (WAN routera)
vmbr1 → dummy0, fwpr100p0, fwpr200p1, fwpr300p0
```

## VM 300 — narzędzia

Wireshark, radare2, Ghidra, binwalk, YARA, Sleuthkit, hashcat, nmap, iptables, aeskeyfind i inne — pełna lista w `guests/vm300-lab/security-tools.txt` (2278 pakietów w backupie).

## OPNsense (VM 200)

- **WAN** (`vtnet0`): DHCP z sieci domowej
- **LAN** (`vtnet1`): `192.168.10.1/24`, dnsmasq DHCP `192.168.10.10–100`
- **LAB_NET** (`vlan0.1`, VLAN 10 na vtnet1): `192.168.20.1/24`
- Aliasy: `Downloader` = 192.168.10.15, `Lab` = 192.168.20.10, `home` = 192.168.1.0/24

Szczegóły reguł → `opnsense/firewall-rules-summary.md`

## Backup źródłowy

Pełny backup labu: `A:\LabBackup\`

```
LabBackup/
├── config-OPNsense.internal-20260630184127.xml   # pełny config (lokalnie, nie w repo)
├── lab-backup/
│   ├── host/          # qm conf, interfaces, ip-addr, brctl
│   └── guests/        # STATUS, packages, runtime-network per VM
└── recovery.txt       # NIE publikować
```

## Uwagi bezpieczeństwa

- Nie publikować: `recovery.txt`, hasła cloud-init, hash root OPNsense, klucze prywatne TLS/VPN
- Config OPNsense w repo to wyłącznie **fragment** bez sekretów
- Testy i skanowanie wyłącznie w autoryzowanym zakresie
