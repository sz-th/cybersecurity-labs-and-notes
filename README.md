# Cybersecurity Labs and Notes

Zbiór materiałów z laboratoriów i projektów z obszaru cyberbezpieczeństwa — student 4. roku CS.

## Struktura

```
linux-hardening/CyberSentinel/   — audyt bezpieczeństwa Linux (projekt zaliczeniowy)
reports/                         — przykładowe raporty (anonimizowane)
```

## Linux Hardening — CyberSentinel

Automatyczny audyt systemu Linux: konfiguracja SSH, pliki SUID/SGID, firewall, uprawnienia `/etc/shadow`, analiza logów auth (Perl), raport HTML, moduł threat intelligence (Python).

```bash
cd linux-hardening/CyberSentinel
sudo ./sentinel.sh -v -l ./data/auth.log
```

Wymagania: Bash, Perl, Python 3, uprawnienia root (część testów audytowych).

## Raporty

`reports/generic-waf-pentest-report.md` — generyczny raport z testów webowych z WAF (dane fikcyjne: ACME Corp, secure-app.local). Służy jako próbka formatu raportu w portfolio.

## Disclaimer

Materiały edukacyjne. Testy penetracyjne i skrypty ofensywne stosuj wyłącznie w środowiskach autoryzowanych.
