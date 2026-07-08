# Proxmox Homelab — sieć i forensics

Dokumentacja prywatnego labu security na Proxmox VE. Konfiguracje zanonimizowane (RFC1918, bez haseł, bez UUID hosta).

## Topologia

```
Host Proxmox (10.0.0.1)
├── vmbr0 → sieć upstream (10.0.0.0/24)
└── vmbr1 → izolowana sieć labu
    ├── VM 100 download (10.0.10.15) — stacja pobierania
    ├── VM 200 Router — vmbr0 + vmbr1, firewall=1
    └── VM 300 lab (10.0.20.10, VLAN 10) — stacja forensics/RE
```

## Pliki

| Plik | Opis |
|------|------|
| `host/interfaces.example` | Mosty vmbr0/vmbr1 |
| `host/qemu-server/100-download.conf` | VM Debian — download |
| `host/qemu-server/200-router.conf` | VM Router — dual-homed |
| `host/qemu-server/300-lab.conf` | VM lab — REMnux-style tooling |
| `guests/vm300-lab/security-tools.txt` | Wybrane pakiety security/forensics |

## VM 300 — narzędzia

Wireshark, radare2, Ghidra, binwalk, YARA, Sleuthkit, hashcat, nmap, iptables, aeskeyfind i inne (pełna lista w `security-tools.txt`).

## Uwagi

- Nie publikować: recovery keys, backup OPNsense z kluczami VPN, hasła cloud-init
- IP w plikach to placeholder `10.0.x.x` — dostosuj do własnej sieci labu
