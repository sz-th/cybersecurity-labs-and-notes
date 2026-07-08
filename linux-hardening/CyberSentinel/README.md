# CyberSentinel

Narzędzie audytu bezpieczeństwa systemów Linux — projekt zaliczeniowy (Bash + Perl + Python).

## Funkcje

- Audyt konfiguracji SSH
- Wykrywanie plików SUID/SGID
- Sprawdzanie firewall (UFW/firewalld)
- Analiza uprawnień `/etc/shadow`, cron, Shellshock
- Parser logów auth — nieudane logowania, adresy IP (Perl)
- Raport HTML (`bin/analyser.pl`)
- Symulacja threat intelligence (`new/threat_check.py`)

## Uruchomienie

```bash
chmod +x sentinel.sh
sudo ./sentinel.sh -h
sudo ./sentinel.sh -v -l ./data/auth.log
```

## Struktura

```
sentinel.sh          — orchestrator
lib/bash/            — moduły audytu
lib/perl/            — parser logów
bin/analyser.pl      — generator raportu HTML
data/auth.log        — przykładowe logi
new/                 — rozszerzenia (threat check)
config/sentinel.conf — konfiguracja (opcjonalna)
```

## Wymagania

- Linux (Debian/Ubuntu)
- bash, perl, python3
- Uprawnienia root dla pełnego audytu
