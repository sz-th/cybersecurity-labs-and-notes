# OPNsense — VM 200 (Router)

Fragment konfiguracji z backupu `A:\LabBackup\config-OPNsense.internal-20260630184127.xml` (2026-06-30). Pełny plik z hasłami i certyfikatami pozostaje lokalnie.

## Interfejsy

| Interfejs | Urządzenie | Adres | Opis |
|-----------|------------|-------|------|
| WAN | vtnet0 | DHCP | Upstream — sieć domowa przez vmbr0 |
| LAN | vtnet1 | 192.168.10.1/24 | Sieć downloadera (VM 100) |
| LAB_NET | vlan0.1 (VLAN 10 na vtnet1) | 192.168.20.1/24 | Sieć forensics (VM 300) |
| lo0 | lo0 | 127.0.0.1/8 | Loopback |

## VLAN

| Tag | Parent | Interfejs | Sieć |
|-----|--------|-----------|------|
| 10 | vtnet1 | vlan0.1 | 192.168.20.0/24 (LAB_NET) |

VM 300 podłączona do vmbr1 z `tag=10` w Proxmox → ruch na VLAN 10.

## Aliasy firewall

| Nazwa | Typ | Zawartość |
|-------|-----|-----------|
| Downloader | host | 192.168.10.15 |
| Lab | host | 192.168.20.10 |
| home | network | 192.168.1.0/24 |

## DHCP (dnsmasq)

- Interfejs: LAN
- Zakres: 192.168.10.10 – 192.168.10.100
- Port dnsmasq: 53053

## NAT (outbound, hybrid)

| Reguła | Źródło | Akcja |
|--------|--------|-------|
| Downloader NAT jawny /32 | 192.168.10.15/32 | NAT na WAN |
| Lab bez NAT na WAN | 192.168.20.0/24 | `nonat` — brak wyjścia na internet |

## Pliki

- `interfaces-excerpt.xml` — interfejsy, VLAN, aliasy, NAT (bez `<password>`, `<cert>`, `<prv>`)
- `firewall-rules-summary.md` — reguły filtrowania w formie czytelnej
