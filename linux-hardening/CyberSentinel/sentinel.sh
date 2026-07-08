#!/bin/bash

# ==============================================================================
# PROJEKT ZALICZENIOWY: CyberSentinel
# Projekt zaliczeniowy — audyt bezpieczeństwa Linux
# Data: Styczeń 2026
# ==============================================================================

# 1. Ustalanie ścieżki absolutnej do katalogu skryptu (wymóg szukania modułów)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
LIB_DIR="$SCRIPT_DIR/lib/bash"
CONFIG_FILE="$SCRIPT_DIR/config/sentinel.conf"
PERL_SCRIPT="$SCRIPT_DIR/bin/analyzer.pl"

# 2. Import modułów własnych (z walidacją istnienia plików)
if [[ -f "$LIB_DIR/utils.sh" ]]; then
    source "$LIB_DIR/utils.sh"
else
    echo "BŁĄD KRYTYCZNY: Brak modułu utils.sh w $LIB_DIR"
    exit 1
fi

if [[ -f "$LIB_DIR/audit.sh" ]]; then
    source "$LIB_DIR/audit.sh"
else
    log_error "Brak modułu audit.sh w $LIB_DIR"
    exit 1
fi

# 3. Definicja funkcji HELP (musi być, wywołanie z -h)
function show_help() {
    echo "CyberSentinel v1.0 - Narzędzie audytu bezpieczeństwa"
    echo "Użycie: $0 [OPCJE]"
    echo ""
    echo "Opcje:"
    echo "  -h          Wyświetla ten komunikat pomocy i kończy działanie (kod 0)."
    echo "  -v          Włącza tryb verbose (szczegółowe logowanie)."
    echo "  -c PLIK     Wskazuje niestandardowy plik konfiguracyjny."
    echo "  -l PLIK     Ścieżka do pliku logów do analizy przez moduł Perla."
    echo ""
    echo "Opis działania:"
    echo "  Program przeprowadza serię testów bezpieczeństwa systemu (SUID, SSH),"
    echo "  a następnie uruchamia podsystem w Perlu do analizy logów pod kątem"
    echo "  prób nieautoryzowanego dostępu."
    echo ""
    echo "Przykład:"
    echo "  $0 -v -l ./data/auth.log"
    exit 0
}

# 4. Parsowanie argumentów (getopts)
LOG_FILE_PATH=""

while getopts ":hvc:l:" opt; do
  case ${opt} in
    h)
      show_help
      ;;
    v)
      VERBOSE_MODE=1
      log_debug "Tryb verbose został włączony."
      ;;
    c)
      CONFIG_FILE="$OPTARG"
      log_debug "Ustawiono plik konfiguracyjny na: $CONFIG_FILE"
      ;;
    l)
      LOG_FILE_PATH="$OPTARG"
      ;;
    \?)
      log_error "Nieprawidłowa opcja: -$OPTARG"
      show_help
      ;;
    :)
      log_error "Opcja -$OPTARG wymaga argumentu."
      exit 1
      ;;
  esac
done

# 5. Walidacja wstępna
if [[ ! -f "$CONFIG_FILE" ]]; then
    log_warn "Nie znaleziono pliku konfiguracyjnego $CONFIG_FILE. Używam ustawień domyślnych."
    # Tutaj można by stworzyć domyślny plik
fi

# 6. Główna pętla programu BASH
log_info "Uruchamianie CyberSentinel..."
check_root

log_info "--- FAZA 1: Audyt Systemu (Bash) ---"
check_ssh_config
check_suid_files

# 7. Wywołanie części PERLOWEJ
log_info "--- FAZA 2: Analiza Logów (Perl) ---"
# ... fragment w sentinel.sh ...

# Definiujemy ścieżkę raportu (np. w bieżącym katalogu lub w /tmp)
REPORT_FILE="$SCRIPT_DIR/report_$(date +%F).html"

log_info "Uruchamiam analizator Perl..."
perl "$PERL_SCRIPT" $PERL_ARGS --file "$LOG_FILE_PATH" --report "$REPORT_FILE"

# Sprawdzenie czy raport powstał
if [[ -f "$REPORT_FILE" ]]; then
    log_info "Raport HTML został wygenerowany: $REPORT_FILE"
else
    log_warn "Raport HTML nie został utworzony."
fi
if [[ -z "$LOG_FILE_PATH" ]]; then
    # Jeśli użytkownik nie podał logu, szukamy w configu lub domyślnie
    LOG_FILE_PATH="$SCRIPT_DIR/data/auth.log"
fi

if [[ -x "$(command -v perl)" ]]; then
    if [[ -f "$PERL_SCRIPT" ]]; then
        # Przekazujemy argumenty do Perla
        # Zauważ: przekazujemy flagę -v jeśli jest włączona w Bashu
        PERL_ARGS=""
        if [[ "$VERBOSE_MODE" -eq 1 ]]; then
            PERL_ARGS="-v"
        fi
        
        log_debug "Uruchamiam: perl $PERL_SCRIPT $PERL_ARGS --file $LOG_FILE_PATH"
        perl "$PERL_SCRIPT" $PERL_ARGS --file "$LOG_FILE_PATH"
        
        PERL_EXIT_CODE=$?
        if [[ $PERL_EXIT_CODE -eq 0 ]]; then
            log_info "Moduł Perla zakończył pracę pomyślnie."
        else
            log_error "Moduł Perla zwrócił błąd (kod: $PERL_EXIT_CODE)."
        fi
    else
        log_error "Nie znaleziono skryptu Perla: $PERL_SCRIPT"
    fi
else
    log_error "Interpreter Perla nie jest zainstalowany w systemie."
fi

log_info "Zakończono działanie."