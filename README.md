# Cybersecurity Labs and Notes

Zbior materialow z laboratoriow i projektow cyberbezpieczenstwa — student 4. roku CS.

## Struktura

```
linux-hardening/CyberSentinel/          — audyt Linux (Bash/Perl/Python)
network-security/proxmox-homelab/       — dokumentacja labu Proxmox (anonimizowana)
web-app-security/xss-csrf-test-suite/   — testy XSS/CSRF (Selenium, Playwright)
devsecops/codeql-path-traversal-fix/    — SAST: CodeQL path traversal (Go + Node)
reports/                                — raporty PoC (anonimizowane)
```

## Linux Hardening — CyberSentinel

```bash
cd linux-hardening/CyberSentinel
sudo ./sentinel.sh -v -l ./data/auth.log
```

## Network Security — Proxmox Homelab

Dokumentacja homelabu: izolowana siec, VM Router (dual-homed), stacja forensics. Zobacz `network-security/proxmox-homelab/README.md`.

## Web App Security — XSS / CSRF

Testy automatyczne na aplikacji Go+React. Zobacz `web-app-security/xss-csrf-test-suite/README.md`.

## DevSecOps — CodeQL

Naprawa path traversal w projektach OSS + workflow GitHub Actions. Zobacz `devsecops/codeql-path-traversal-fix/README.md`.

## Raporty

`reports/generic-waf-pentest-report.md` — generyczny raport pentest (ACME Corp, secure-app.local).

## Disclaimer

Materialy edukacyjne. Testy i skrypty stosuj wylacznie w srodowiskach autoryzowanych.
