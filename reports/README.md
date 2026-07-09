# Raporty — OWASP ZAP

Eksporty i analizy z autoryzowanych testów własnych (nauka / lab). Jedyna redakcja względem oryginału: **nazwy firm i domen** → `[REDACTED-TARGET-A]`, `[REDACTED-TARGET-B]`.

## Raporty markdown

| Plik | Opis |
|------|------|
| `waf-active-scan-report.md` | Active Scan, analiza WAF/Incapsula/Cloudflare, SQLi w kontekście blokad |
| `zap-additional-findings-report.md` | CSP, CSRF, cookies, JS libs, XSS surface, porównanie dwóch celów |

## Surowe eksporty ZAP (lokalne)

| Ścieżka | Cel | Rozmiar |
|---------|-----|---------|
| `E:\zap\2026-06-05-ZAP-Report-www.[REDACTED-TARGET-A].html` | `[REDACTED-TARGET-A]` | ~25 MB |
| `A:\tools\Zed Attack Proxy\2026-06-19-ZAP-Report-www.[REDACTED-TARGET-B].html` | `[REDACTED-TARGET-B]` | ~12 MB |
| `E:\2026-05-25-ZAP-Report-.html` | `[REDACTED-TARGET-B]` (wcześniejszy) | ~31 MB |
| `E:\2026-05-29-ZAP-Report-www.[REDACTED-TARGET-A].html` | `[REDACTED-TARGET-A]` | ~22 MB |

Parsowanie: `owasp-zap-extensions-and-scripts/utils/parse_zap_report.py`
