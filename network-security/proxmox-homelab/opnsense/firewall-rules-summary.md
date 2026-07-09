# OPNsense — reguły firewall (skrót)

Wyekstrahowane z `config-OPNsense.internal-20260630184127.xml`. Kolejność quick rules ma znaczenie.

## WAN

| Akcja | Protokół | Źródło | Cel | Opis |
|-------|----------|--------|-----|------|
| pass | tcp | home (192.168.1.0/24) | (self):443,22 | Admin z sieci domowej do GUI/SSH |
| reject | * | Lab (192.168.20.10) | any | Blokada labu na WAN |

## LAN — VM 100 (Downloader)

| Akcja | Protokół | Źródło | Cel | Opis |
|-------|----------|--------|-----|------|
| pass | udp | Downloader | (self):53 | DNS UDP do OPNsense |
| pass | tcp | Downloader | (self):53 | DNS TCP do OPNsense |
| block | * | Downloader | (self) | Blokada dostępu do routera |
| block | * | Downloader | home | Blokada do sieci domowej |
| block | * | Downloader | lan (reszta) | Blokada do reszty LAN |
| pass | tcp | Downloader | Lab:22 | SCP do stacji forensics |
| block | tcp | Downloader | Lab (inne porty) | Izolacja labu poza SCP |
| pass | tcp | Downloader | any:443 | HTTPS na WAN |
| pass | tcp | Downloader | any:80 | HTTP na WAN |

## Domyślne (wyłączone)

| Akcja | Opis | Status |
|-------|------|--------|
| pass | Default allow LAN to any | disabled |
| pass | Default allow LAN IPv6 to any | disabled |

## Model izolacji

```
Downloader (192.168.10.15)
  ✓ DNS → OPNsense
  ✓ HTTP/HTTPS → Internet (przez NAT /32)
  ✓ TCP 22 → Lab (192.168.20.10)
  ✗ Router GUI/SSH
  ✗ Sieć domowa 192.168.1.0/24
  ✗ Inne hosty LAN
  ✗ Lab poza portem 22

Lab (192.168.20.10)
  ✗ NAT na WAN (nonat)
  ✗ Ruch wychodzący na internet
```

## VLAN / LAB_NET

Ruch między 192.168.10.0/24 a 192.168.20.0/24 kontrolowany regułami LAN — downloader ma wyłącznie SCP do Lab.

## Hardening (z opisów w config)

Reguły tagowane w backupie jako `malware-lab hardening fix A/B/v8` — iteracyjne zaostrzanie polityki downloadera i izolacji labu.
