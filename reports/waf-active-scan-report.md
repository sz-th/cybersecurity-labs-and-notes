# Active Scan — analiza WAF i blokad

**Cel:** `https://[REDACTED-TARGET-A].example` (platforma e-commerce / płatności)  
**Zakres:** Aplikacja webowa, model Gray-Box (własne testy w ramach nauki)  
**Okres:** maj–czerwiec 2026  
**Narzędzia:** OWASP ZAP 2.16, Burp Suite, Python (`parse_zap_report.py`, `analyze_hars.py`), sqlmap przez proxy ZAP

**Źródło danych:** `E:\zap\2026-06-05-ZAP-Report-www.[REDACTED-TARGET-A].html` (3207 instancji alertów, 123 kategorie)

---

## 1. Podsumowanie

Testy bezpieczeństwa publicznej aplikacji webowej w modelu Gray-Box. Infrastruktura chroniona przez **WAF klasy enterprise** (Cloudflare na warstwie CDN, Incapsula na subdomenie płatności `secure.[REDACTED-TARGET-A].example`).

W trakcie Active Scan **nie potwierdzono exploitable SQL Injection** prowadzącej do ekfiltracji danych — odpowiedzi na payloady SQLi to strony challenge/blokady WAF, nie błędy backendu.

| Metryka | Wynik |
|---------|-------|
| Kategorie alertów ZAP | 123 |
| Instancje alertów | 3207 |
| High (instancje) | 109 |
| Medium (instancje) | 64 |
| Potwierdzone exploity | 0 |
| Dominujący wzorzec HTTP | 200 (backend/WAF), 403 (blokada) |
| Cloudflare block w odpowiedziach | 0 (Incapsula na secure.*) |

---

## 2. Wykryte mechanizmy WAF

### 2.1 Sygnatury odpowiedzi

- **Incapsula:** `_Incapsula_Resource`, `xinfo` w query, HTTP 403 z krótkim body „Loading”
- **Cloudflare:** `cf-mitigated`, `server: cloudflare`, challenge na `www.*`
- **Blokada IP:** HTTP 403/429 po ~50–100 requestach Active Scan

### 2.2 Zachowanie przy skanowaniu

Active Scan generował setki requestów z payloadami SQLi. Po przekroczeniu progu requestów następowała **blokada źródłowego IP**. Kolejne requesty zwracały stronę challenge bez dostępu do origin aplikacji.

Endpointy najczęściej testowane (z raportu ZAP):

| Req | Metoda | URL |
|-----|--------|-----|
| 9 | GET | `https://www.[REDACTED-TARGET-A].example/` |
| 6 | POST | `https://secure.[REDACTED-TARGET-A].example/cart` |
| 3 | GET | `https://secure.[REDACTED-TARGET-A].example/_Incapsula_Resource?...` |
| 2 | GET | `https://secure.[REDACTED-TARGET-A].example/.env` |

---

## 3. Metodyka

### 3.1 Rekonesans

- Mapowanie endpointów przez proxy ZAP (8080)
- Technology Detection (add-on Marketplace): PHP, WooCommerce, jQuery, Cloudflare, Apache
- Eksport HAR → analiza offline (`analyze_hars.py`)

### 3.2 Rate limiting

Skrypt **rate-limit.js** (HTTP Sender):
- `INTERVAL_MS = 2000` — min. 2 s między requestami
- Jitter ±10%
- Active Scan: 1 wątek / 1 host

### 3.3 Rotacja IP przy blokadzie WAF

Skrypt **mullvad-rotate-on-waf.js**:
1. Wykrycie odpowiedzi WAF (kod + wzorzec body/header)
2. Enqueue oryginalnego requestu
3. `mullvad reconnect` (PowerShell helper)
4. Retry z nowego IP (max 3 / request)

Rotacja IP pozwalała kontynuować skan, ale WAF nadal blokował payloady na poziomie sygnatury.

### 3.4 Analiza wyników

```bash
python parse_zap_report.py "E:\zap\2026-06-05-ZAP-Report-www.[REDACTED-TARGET-A].html"
python analyze_hars.py <eksport.har>
```

---

## 4. SQL Injection — kontekst alertów High

ZAP zgłosił **105 instancji** alertu „SQL Injection” (High). Analiza odpowiedzi HTTP:

| Status | Liczba | Interpretacja |
|--------|--------|---------------|
| 200 | 84 | Strona WAF/challenge lub normalna odpowiedź — brak błędów SQL |
| 403 | 14 | Blokada WAF |
| 301 | 7 | Redirect |

Wzorce ataku w raporcie: głównie boolean AND i generic — **brak potwierdzenia time-based** na tym celu (w przeciwieństwie do [REDACTED-TARGET-B], patrz drugi raport).

---

## 5. Wnioski

1. WAF skutecznie blokuje automatyczne skanowanie i agresywne payloady
2. Alerty ZAP High ≠ potwierdzona podatność — wymagana ręczna weryfikacja odpowiedzi
3. Subdomena `secure.*` za Incapsula — osobna polityka niż `www.*` za Cloudflare
4. Próby dostępu do `.env` (2× GET) — zablokowane / bez wycieku

Szczegóły pozostałych kategorii (CSP, CSRF, cookies, JS libraries) → `zap-additional-findings-report.md`

---

*Nazwy firm i domen zastąpione tagami `[REDACTED-TARGET-*]`. Pozostałe dane pochodzą z rzeczywistych eksportów ZAP.*
