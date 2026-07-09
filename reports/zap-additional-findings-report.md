# Dodatkowe ustalenia z eksportów OWASP ZAP

Raport uzupełniający do `waf-active-scan-report.md`. Obejmuje ustalenia **poza** głównym wątkiem WAF/SQLi — nagłówki bezpieczeństwa, konfigurację cookies, CSP, CSRF, biblioteki JS i powierzchnię ataku.

**Źródła (lokalne eksporty):**

| Plik | Cel | Data | Alerty |
|------|-----|------|--------|
| `E:\zap\2026-06-05-ZAP-Report-www.[REDACTED-TARGET-A].html` | `[REDACTED-TARGET-A]` e-commerce | 2026-06-05 | 3207 inst. / 123 kat. |
| `A:\tools\Zed Attack Proxy\2026-06-19-ZAP-Report-www.[REDACTED-TARGET-B].html` | `[REDACTED-TARGET-B]` WordPress/WooCommerce | 2026-06-19 | 218 inst. / 62 kat. |
| `E:\2026-05-25-ZAP-Report-.html` | `[REDACTED-TARGET-B]` (wcześniejszy skan) | 2026-05-25 | ~8000+ inst. |

---

## 1. [REDACTED-TARGET-A] — Medium i High (poza SQLi)

### High

| Inst. | Alert | Uwagi |
|-------|-------|-------|
| 105 | SQL Injection | WAF — patrz raport WAF |
| 2 | Vulnerable JS Library | jQuery / pluginy — wersje ze znanymi CVE |
| 1 | HTTPS Security Configuration Issues | Konfiguracja TLS do weryfikacji ręcznej |
| 1 | PII Disclosure | Potencjalny wyciek PII w odpowiedzi — wymaga triage |

### Medium

| Inst. | Alert | Rekomendacja |
|-------|-------|--------------|
| 14 | Sub Resource Integrity Attribute Missing | Dodać `integrity` na zewnętrzne `<script>`/`<link>` |
| 10 | Content Security Policy (CSP) Header Not Set | Zdefiniować restrykcyjny CSP |
| 8 | Absence of Anti-CSRF Tokens | Tokeny na formularzach POST (cart, login) |
| 7 | Missing Anti-clickjacking Header | `X-Frame-Options: DENY` lub CSP `frame-ancestors` |
| 6 | Proxy Disclosure | Ukryć nagłówki ujawniające proxy/CDN |
| 4 | Directory Browsing | Wyłączyć listing katalogów na origin |
| 2 | Bypassing 403 | ZAP wykrył obejścia 403 — do ręcznej weryfikacji |
| 2 | Hidden File Found | Pliki ukryte dostępne z zewnątrz |
| 1 | Application Error Disclosure | Stack trace / błąd aplikacji w odpowiedzi |
| 1 | ELMAH Information Leak | Endpoint diagnostyczny .NET |
| 1 | Relative Path Confusion | Potencjalna dezambiguacja ścieżek |

### Low — wybrane

| Inst. | Alert |
|-------|-------|
| 14 | Cross-Domain JavaScript Source File Inclusion |
| 11 | Timestamp Disclosure - Unix |
| 10 | X-Content-Type-Options Header Missing |
| 7 | Cookie No HttpOnly Flag |
| 7 | Strict-Transport-Security Header Not Set |
| 3 | Cookie Without Secure Flag |
| 3 | Cookie with SameSite Attribute None |
| 3 | Server Leaks Version Information via Server header |

### Informational — istotne dla powierzchni ataku

| Inst. | Alert |
|-------|-------|
| 2157 | Base64 Disclosure |
| 252 | Information in Browser localStorage |
| 54 | User Controllable HTML Element Attribute (Potential XSS) |
| 50 | Hidden File Found |
| 19 | .env Information Leak |
| 19 | .htaccess Information Leak |
| 18 | Trace.axd Information Leak |

---

## 2. [REDACTED-TARGET-B] — WordPress / WooCommerce

### High — SQLi (56 instancji)

| Inst. | Alert | Endpoint (top) |
|-------|-------|----------------|
| 31 | SQL Injection - SQLite (Time Based) | `my-account/lost-password/` |
| 22 | SQL Injection | `my-account/`, `user_login/` |
| 1 | Advanced SQL Injection - AND boolean-based blind | — |
| 1 | Advanced SQL Injection - MySQL stacked queries | — |
| 1 | Advanced SQL Injection - MySQL stacked queries (comment) | — |

**Kontekst:** 52× HTTP 200, 7× 302, 2× 403, 4× Cloudflare block w odpowiedziach. Payloady time-based (`SLEEP`) obecne w raporcie — wymagają ręcznej weryfikacji czy to false positive pluginu WordPress czy realna podatność.

Najczęściej testowane:

| Req | Metoda | URL |
|-----|--------|-----|
| 25 | GET | `https://www.[REDACTED-TARGET-B].example/my-account/lost-password/` |
| 16 | POST | `https://www.[REDACTED-TARGET-B].example/my-account/` |
| 7 | POST | `https://www.[REDACTED-TARGET-B].example/my-account/lost-password/` |

Parametry: `wpdiscuz_nonce_*`, `wp_lang`, cookies sesji WooCommerce.

### Medium

| Inst. | Alert |
|-------|-------|
| 3 | Absence of Anti-CSRF Tokens |
| 3 | CSP: script-src unsafe-inline |
| 3 | CSP: style-src unsafe-inline |
| 3 | CSP: Wildcard Directive |
| 3 | CSP: Failure to Define Directive with No Fallback |
| 3 | Sub Resource Integrity Attribute Missing |
| 1 | Content Security Policy (CSP) Header Not Set |

### Low — wybrane

| Inst. | Alert |
|-------|-------|
| 3 | Cookie No HttpOnly Flag |
| 3 | Cookie Without Secure Flag |
| 3 | Cross-Domain JavaScript Source File Inclusion |
| 3 | Strict-Transport-Security Header Not Set |
| 3 | X-Content-Type-Options Header Missing |
| 3 | Timestamp Disclosure - Unix |

### Informational — XSS surface

| Inst. | Alert |
|-------|-------|
| 7 | User Controllable HTML Element Attribute (Potential XSS) |
| 7 | Information in Browser localStorage |

Wcześniejszy skan (2026-05-25, ten sam cel): **2660× Potential XSS** w atrybutach HTML — znacznie szersza powierzchnia niż w późniejszym, wolniejszym skanie z rate limiterem.

---

## 3. Porównanie celów

| Aspekt | [REDACTED-TARGET-A] | [REDACTED-TARGET-B] |
|--------|---------------------|---------------------|
| Stack | PHP, WooCommerce, Cloudflare + Incapsula | WordPress, WooCommerce, Cloudflare |
| WAF primary | Incapsula na `secure.*`, CF na `www.*` | Cloudflare |
| SQLi High | 105 inst., brak time-based | 56 inst., SQLite time-based + advanced |
| CSP/CSRF | Brak CSP, brak CSRF tokenów | unsafe-inline w CSP, brak CSRF |
| Cookie issues | HttpOnly, Secure, SameSite | HttpOnly, Secure |
| XSS potential | 54 inst. (controlled attributes) | 2660 inst. (wcześniejszy skan) |

---

## 4. Rekomendacje (na podstawie alertów ZAP)

1. **CSP** — zdefiniować politykę bez `unsafe-inline`/`unsafe-eval`, dodać `frame-ancestors`
2. **CSRF** — tokeny na wszystkich formularzach zmieniających stan (WooCommerce account, cart)
3. **Cookies** — `HttpOnly`, `Secure`, `SameSite=Lax/Strict` na sesyjnych
4. **SRI** — integrity hash na CDN (jQuery, cdnjs, pluginy WP)
5. **HSTS** — `Strict-Transport-Security` z `includeSubDomains`
6. **Ukrycie wersji** — usunąć `Server` banner i endpointy diagnostyczne (`.env`, `trace.axd`, ELMAH)
7. **Triage SQLi** — ręczna weryfikacja z proxy; alert ZAP ≠ CVE bez PoC na origin

---

## 5. Jak odtworzyć analizę

```bash
cd owasp-zap-extensions-and-scripts/utils
python parse_zap_report.py "E:\zap\2026-06-05-ZAP-Report-www.[REDACTED-TARGET-A].html"
python parse_zap_report.py "A:\tools\Zed Attack Proxy\2026-06-19-ZAP-Report-www.[REDACTED-TARGET-B].html"
python analyze_hars.py <plik.har>
```

Skrypty ZAP użyte podczas skanów: `rate-limit.js`, `mullvad-rotate-on-waf.js` — repo `owasp-zap-extensions-and-scripts`.

---

*Nazwy firm i domen zastąpione tagami `[REDACTED-TARGET-*]`. Liczby alertów pochodzą bezpośrednio z eksportów HTML ZAP.*
