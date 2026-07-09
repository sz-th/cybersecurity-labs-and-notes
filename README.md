# Cybersecurity Labs and Notes

Zbior materialow z laboratoriow i projektow cyberbezpieczenstwa — student 4. roku CS.

## Struktura

```
linux-hardening/CyberSentinel/          — audyt Linux (Bash/Perl/Python)
network-security/proxmox-homelab/       — lab Proxmox + OPNsense (z backupu A:\LabBackup)
web-app-security/xss-csrf-test-suite/   — testy XSS/CSRF (Selenium, Playwright)
devsecops/codeql-path-traversal-fix/    — SAST: CodeQL path traversal (Go + Node)
reports/                                — raporty z eksportow OWASP ZAP
```

## Linux Hardening — CyberSentinel

```bash
cd linux-hardening/CyberSentinel
sudo ./sentinel.sh -v -l ./data/auth.log
```

## Network Security — Proxmox Homelab

Pelna topologia: izolowana siec vmbr1, OPNsense (WAN/LAN/VLAN 10), VM download + lab forensics. Zobacz `network-security/proxmox-homelab/README.md` i `opnsense/`.

## Web App Security — XSS / CSRF

Testy automatyczne na aplikacji Go+React. Zobacz `web-app-security/xss-csrf-test-suite/README.md`.

## DevSecOps — CodeQL

Naprawa path traversal w projektach OSS + workflow GitHub Actions. Zobacz `devsecops/codeql-path-traversal-fix/README.md`.

## Raporty ZAP

| Raport | Opis |
|--------|------|
| `reports/waf-active-scan-report.md` | Active Scan, WAF/Incapsula, SQLi w kontekście blokad |
| `reports/zap-additional-findings-report.md` | CSP, CSRF, cookies, JS libs, XSS, porównanie celów |
| `reports/README.md` | Indeks raportow i sciezek do surowych eksportow |

Domeny w raportach: `[REDACTED-TARGET-A]`, `[REDACTED-TARGET-B]` — jedyne redakcje wzgledem oryginalu.

## Disclaimer

Materialy edukacyjne. Testy i skrypty wylacznie w srodowiskach autoryzowanych.
