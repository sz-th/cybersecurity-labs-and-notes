# gocat

Minimalna narzedzia open source do wypisywania plikow z katalogu bazowego.

## CodeQL

CodeQL wykryl podatnosc path traversal w wersji sprzed poprawki (`main.before.go.txt`):
wejscie uzytkownika trafia do `filepath.Join` bez walidacji, co pozwala na odczyt plikow poza katalogiem bazowym (`../../etc/passwd`).

Poprawka w `main.go`:
- `safePath` czysci sciezke i weryfikuje, czy wynik pozostaje wewnatrz katalogu bazowego
- odrzucane sa sciezki absolutne i segmenty `..`

## Uruchomienie

```
cd 6/oss/gocat
go test ./...
go run main.go -base ./testdata hello.txt
```
