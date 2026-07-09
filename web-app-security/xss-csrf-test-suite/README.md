# XSS / CSRF Test Suite

Automatyczne testy bezpieczeństwa aplikacji demo (Go + React).

## Zakres testów

| Test | Plik | Opis |
|------|------|------|
| XSS | `tests/selenium/test_3_5_xss.py` | 10 payloadów — weryfikacja braku wykonania JS |
| CSRF | `tests/selenium/test_4_5_csrf.py` | Atak z zewnętrznej strony `csrf_attack.html` |
| Rejestracja | `tests/selenium/test_3_registration.py` | Walidacja formularza |
| E2E | `tests/playwright/tests/e2e.spec.js` | Scenariusz end-to-end |

## Uruchomienie

Backend:
```
cd app/backend
go run .
```

Frontend:
```
cd app/frontend
npm install
npm run dev
```

Selenium (conftest podnosi backend :8088 i frontend :5174):
```
cd tests/selenium
pip install -r requirements.txt
pytest -v test_3_5_xss.py test_4_5_csrf.py
```

Playwright:
```
cd tests/playwright
npm install
npm test
```

## Disclaimer

Aplikacja testowa do weryfikacji zabezpieczeń w ramach zajęć. Używaj wyłącznie lokalnie.
