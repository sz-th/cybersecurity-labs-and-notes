# CodeQL — path traversal remediation

Case study SAST: wykrycie i naprawa path traversal w dwóch projektach OSS (Go + Node.js).

## Zawartość

| Folder | Opis |
|--------|------|
| `gocat/` | Narzędzie CLI Go — `main.before.go.txt` (podatne) vs `main.go` (safePath) |
| `node-oss/` | Serwer HTTP — `server.vulnerable.js` vs `server.js` (safePublicPath) |
| `.github/workflows/codeql.yml` | Pipeline GitHub Actions (JS/TS + Go) |

## gocat (Go)

CodeQL wykrył path traversal: `filepath.Join(base, userInput)` bez walidacji.

Poprawka: `safePath` — normalizacja, odrzucenie `..` i ścieżek absolutnych.

```
cd gocat
go test ./...
```

## node-oss (JavaScript)

Podatność: parametr `file` trafia bezpośrednio do `path.join(rootDir, fileParam)`.

Poprawka: `safePublicPath` — ograniczenie do katalogu `public/`.

```
cd node-oss
node server.js
```

## CodeQL workflow

Workflow skanuje push/PR na `main` oraz cotygodniowy schedule. Języki: javascript-typescript, go.

## Narzędzia

CodeQL, GitHub Actions, SonarCloud (kontekst zajęć e-biznes)
