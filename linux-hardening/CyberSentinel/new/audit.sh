#!/bin/bash


#   Skrypt przeprowadza audyt bezpieczeństwa systemu operacyjnego Linux.
#   Weryfikuje uprawnienia plików, konfigurację sieci, SSH oraz konta użytkowników.
#

#   wymagane - Uprawnienia root (dla pełnego raportu)

#IMPORT 
# Ustalanie ścieżki do skryptu, aby działał niezależnie od miejsca wywołania
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -f "$SCRIPT_DIR/utils.sh" ]]; then
    source "$SCRIPT_DIR/utils.sh"
else
    echo "CRITICAL ERROR: Nie znaleziono pliku utils.sh w $SCRIPT_DIR"
    exit 1
fi

# ZMIENNE KONFIGURACYJNE 
REPORT_FILE="audit_report.txt"
VERBOSE=0

DIR_TO_SCAN_SUID="/usr/bin"
DIR_TO_SCAN_WW="/etc" 
FILE_SSH_CONFIG="/etc/ssh/sshd_config"
FILE_SHADOW="/etc/shadow"

# FUNKCJE AUDYTUJĄCE

# Cel: Wykrywanie plików z ustawionym bitem SUID (4000) lub SGID (2000).
# Ryzyko: Takie pliki uruchamiają się z uprawnieniami właściciela (często roota).
function check_suid_sgid_files() {
    log_info "Rozpoczynam skanowanie plików SUID/SGID..."
    echo -e "\n========================================================" >> "$REPORT_FILE"
    echo " SEKCJA 1: NIEBEZPIECZNE ATRYBUTY (SUID/SGID)" >> "$REPORT_FILE"
    echo -e "========================================================\n" >> "$REPORT_FILE"
    echo "Skanowany katalog: $DIR_TO_SCAN_SUID" >> "$REPORT_FILE"

    if [[ ! -d "$DIR_TO_SCAN_SUID" ]]; then
        log_error "Katalog $DIR_TO_SCAN_SUID nie istnieje. Pomijam test."
        echo "BŁĄD: Katalog docelowy nie istnieje." >> "$REPORT_FILE"
        return 1
    fi

    # -perm /6000 oznacza szukanie bitu 4000 (SUID) LUB 2000 (SGID)
    local dangerous_files=$(find "$DIR_TO_SCAN_SUID" -perm /6000 -type f 2>/dev/null | head -n 15)

    if [[ -z "$dangerous_files" ]]; then
        log_info "Nie znaleziono plików SUID/SGID w badanym obszarze."
        echo "STATUS: OK (Brak wyników w próbce)" >> "$REPORT_FILE"
    else
        log_warn "Wykryto pliki z bitem SUID/SGID!"
        echo "OSTRZEŻENIE: Poniższe pliki mogą służyć do eskalacji uprawnień:" >> "$REPORT_FILE"
        echo "$dangerous_files" >> "$REPORT_FILE"
        
        # zliczanie
        local count=$(echo "$dangerous_files" | wc -l)
        echo -e "\nŁącznie znaleziono: $count plików (pokazano max 15)." >> "$REPORT_FILE"
    fi
}

# Cel: Wykrywanie plików, które może edytować każdy użytkownik (chmod 777/666).
# Ryzyko: Użytkownik może dopisać złośliwy kod do skryptu systemowego.
function check_world_writable() {
    log_info "Szukanie plików z powszechnym prawem zapisu (World-Writable)..."
    echo -e "\n========================================================" >> "$REPORT_FILE"
    echo " SEKCJA 2: PLIKI WORLD-WRITABLE (Zapis dla każdego)" >> "$REPORT_FILE"
    echo -e "========================================================\n" >> "$REPORT_FILE"

    if [[ ! -d "$DIR_TO_SCAN_WW" ]]; then
        log_warn "Katalog $DIR_TO_SCAN_WW nie istnieje."
        return 1
    fi

    # -perm -0002 oznacza, że bit zapisu dla "others" jest ustawiony
    local ww_files=$(find "$DIR_TO_SCAN_WW" -type f -perm -0002 2>/dev/null | head -n 10)

    if [[ -n "$ww_files" ]]; then
        log_error "ZNALEZIONO KRYTYCZNE LUKI W UPRAWNIENIACH!"
        echo "ALARM: Każdy użytkownik może zmodyfikować te pliki:" >> "$REPORT_FILE"
        echo "$ww_files" >> "$REPORT_FILE"
    else
        log_info "Nie znaleziono plików world-writable w $DIR_TO_SCAN_WW."
        echo "STATUS: OK (System plików wygląda bezpiecznie w $DIR_TO_SCAN_WW)" >> "$REPORT_FILE"
    fi
}

# Funkcja: check_ssh_config
# Cel: Weryfikacja utwardzenia serwera SSH.
function check_ssh_config() {
    log_info "Weryfikacja konfiguracji SSH..."
    echo -e "\n========================================================" >> "$REPORT_FILE"
    echo " SEKCJA 3: KONFIGURACJA SSH" >> "$REPORT_FILE"
    echo -e "========================================================\n" >> "$REPORT_FILE"

    if [[ ! -f "$FILE_SSH_CONFIG" ]]; then
        log_warn "Nie znaleziono pliku konfiguracyjnego SSH: $FILE_SSH_CONFIG"
        echo "INFO: Brak pliku konfiguracyjnego (Usługa nie zainstalowana?)" >> "$REPORT_FILE"
        return 0
    fi

    # Sprawdzamy logowanie roota
    if grep -q "^PermitRootLogin yes" "$FILE_SSH_CONFIG"; then
        log_error "SSH: Logowanie roota jest WŁĄCZONE!"
        echo "RYZYKO KRYTYCZNE: PermitRootLogin yes (Root może się logować zdalnie)" >> "$REPORT_FILE"
    else
        log_info "SSH: Logowanie roota bezpieczne (wyłączone lub zablokowane hasło)."
        echo "STATUS: OK (Root login disabled/prohibit-password)" >> "$REPORT_FILE"
    fi

    # Sprawdzamy puste hasła
    if grep -q "^PermitEmptyPasswords yes" "$FILE_SSH_CONFIG"; then
        log_error "SSH: Dozwolone puste hasła!"
        echo "RYZYKO: PermitEmptyPasswords yes" >> "$REPORT_FILE"
    else
        echo "STATUS: OK (Puste hasła zablokowane)" >> "$REPORT_FILE"
    fi

    #Sprawdzamy port (czy domyślny 22)
    local ssh_port=$(grep "^Port " "$FILE_SSH_CONFIG" | awk '{print $2}')
    if [[ -z "$ssh_port" ]]; then
        echo "INFO: SSH działa na domyślnym porcie 22 (Zalecana zmiana)." >> "$REPORT_FILE"
    else
        echo "INFO: SSH działa na niestandardowym porcie: $ssh_port" >> "$REPORT_FILE"
    fi
}

# Funkcja: check_firewall
# Cel: Sprawdzenie statusu mechanizmów obronnych (UFW / IPTables).
function check_firewall() {
    log_info "Sprawdzanie statusu Firewalla..."
    echo -e "\n========================================================" >> "$REPORT_FILE"
    echo " SEKCJA 4: STATUS FIREWALLA" >> "$REPORT_FILE"
    echo -e "========================================================\n" >> "$REPORT_FILE"

    local fw_active=0

    # Sprawdzenie UFW (Uncomplicated Firewall)
    if command -v ufw &> /dev/null; then
        local ufw_status=$(ufw status | head -n 1)
        echo "UFW Status: $ufw_status" >> "$REPORT_FILE"
        if [[ "$ufw_status" == *"active"* ]] && [[ "$ufw_status" != *"inactive"* ]]; then
            fw_active=1
        fi
    fi

    # Sprawdzenie IPTables (jeśli UFW nie jest głównym)
    if command -v iptables &> /dev/null; then
        local rules_count=$(iptables -L -n | grep -v "^Chain" | grep -v "^target" | wc -l)
        if [[ "$rules_count" -gt 0 ]]; then
            echo "IPTables: Znaleziono $rules_count aktywnych reguł." >> "$REPORT_FILE"
            fw_active=1
        else
            echo "IPTables: Puste łańcuchy reguł." >> "$REPORT_FILE"
        fi
    fi

    if [[ $fw_active -eq 0 ]]; then
        log_warn "Wygląda na to, że Firewall jest NIEAKTYWNY!"
        echo "ALARM: Brak aktywnej ochrony sieciowej!" >> "$REPORT_FILE"
    else
        log_info "Firewall wydaje się być aktywny."
        echo "STATUS: Ochrona sieciowa aktywna." >> "$REPORT_FILE"
    fi
}

# Funkcja: check_users_shadow
# Cel: Analiza pliku /etc/shadow pod kątem kont bez haseł.
function check_users_shadow() {
    log_info "Analiza bezpieczeństwa kont użytkowników..."
    echo -e "\n========================================================" >> "$REPORT_FILE"
    echo " SEKCJA 5: UŻYTKOWNICY I HASŁA" >> "$REPORT_FILE"
    echo -e "========================================================\n" >> "$REPORT_FILE"

    if [[ ! -r "$FILE_SHADOW" ]]; then
        log_error "Brak uprawnień do odczytu $FILE_SHADOW. Uruchom jako root."
        echo "BŁĄD: Brak dostępu do /etc/shadow (wymagany root)." >> "$REPORT_FILE"
        return 1
    fi

    # Szukamy użytkowników, gdzie drugie pole (hash hasła) jest puste
    local empty_pass=$(awk -F: '($2 == "") {print $1}' "$FILE_SHADOW")

    if [[ -n "$empty_pass" ]]; then
        log_error "Znaleziono konta bez hasła!"
        echo "RYZYKO: Następujące konta nie mają hasła:" >> "$REPORT_FILE"
        echo "$empty_pass" >> "$REPORT_FILE"
    else
        log_info "Wszystkie konta posiadają hasła."
        echo "STATUS: OK (Brak pustych haseł)." >> "$REPORT_FILE"
    fi

    # Sprawdzenie UID 0 (kto jest rootem oprócz roota)
    local root_users=$(awk -F: '($3 == 0) {print $1}' /etc/passwd)
    echo "Użytkownicy z uprawnieniami roota (UID 0):" >> "$REPORT_FILE"
    echo "$root_users" >> "$REPORT_FILE"
}

# Cel: Wykrywanie otwartych portów nasłuchujących na połączenia.
# Ryzyko: Każdy otwarty port to potencjalny wektor ataku.
function check_open_ports() {
    log_info "Skanowanie otwartych portów sieciowych..."
    echo -e "\n========================================================" >> "$REPORT_FILE"
    echo " SEKCJA 6: OTWARTE PORTY SIECIOWE" >> "$REPORT_FILE"
    echo -e "========================================================\n" >> "$REPORT_FILE"

    if ! command -v ss &> /dev/null; then
        log_warn "Polecenie 'ss' nie jest dostępne. Próba użycia 'netstat'."
        if ! command -v netstat &> /dev/null; then
            log_error "Brak poleceń 'ss' i 'netstat'. Pomijam skanowanie portów."
            echo "BŁĄD: Brak narzędzi do skanowania portów." >> "$REPORT_FILE"
            return 1
        fi
        local open_ports=$(netstat -tuln)
    else
        local open_ports=$(ss -tuln)
    fi

    if [[ -z "$open_ports" ]]; then
        log_info "Nie znaleziono aktywnych portów nasłuchujących."
        echo "STATUS: OK (Brak otwartych portów TCP/UDP)." >> "$REPORT_FILE"
    else
        log_warn "Wykryto otwarte porty. Zweryfikuj, czy są niezbędne."
        echo "OSTRZEŻENIE: Poniższe porty są otwarte na połączenia:" >> "$REPORT_FILE"
        echo "$open_ports" >> "$REPORT_FILE"
    fi
}

# Cel: Weryfikacja polityki haseł w systemie.
# Ryzyko: Słaba polityka haseł ułatwia ataki brute-force.
function check_password_policy() {
    log_info "Sprawdzanie polityki haseł w /etc/login.defs..."
    echo -e "\n========================================================" >> "$REPORT_FILE"
    echo " SEKCJA 7: POLITYKA HASEŁ (login.defs)" >> "$REPORT_FILE"
    echo -e "========================================================\n" >> "$REPORT_FILE"
    
    local login_defs="/etc/login.defs"
    if [[ ! -r "$login_defs" ]]; then
        log_error "Brak dostępu do pliku $login_defs."
        echo "BŁĄD: Nie można odczytać pliku $login_defs." >> "$REPORT_FILE"
        return 1
    fi

    local pass_max_days=$(grep "^PASS_MAX_DAYS" "$login_defs" | awk '{print $2}')
    local pass_min_days=$(grep "^PASS_MIN_DAYS" "$login_defs" | awk '{print $2}')
    local pass_warn_age=$(grep "^PASS_WARN_AGE" "$login_defs" | awk '{print $2}')

    echo "POLITYKA WYGASANIA HASEŁ:" >> "$REPORT_FILE"
    echo " - Maksymalna ważność hasła (dni): $pass_max_days" >> "$REPORT_FILE"
    echo " - Minimalna ważność hasła (dni): $pass_min_days" >> "$REPORT_FILE"
    echo " - Ostrzeżenie o wygasaniu (dni): $pass_warn_age" >> "$REPORT_FILE"

    if (( pass_max_days > 90 )); then
        log_warn "Polityka haseł: Maksymalna ważność hasła jest większa niż 90 dni ($pass_max_days)."
        echo "UWAGA: Długi okres ważności hasła zwiększa ryzyko." >> "$REPORT_FILE"
    fi
    if (( pass_min_days < 1 )); then
        log_warn "Polityka haseł: Użytkownicy mogą zmieniać hasło natychmiast."
        echo "UWAGA: Brak minimalnego okresu ważności hasła." >> "$REPORT_FILE"
    fi
    log_info "Analiza polityki haseł zakończona."
}

# Cel: Weryfikacja kluczowych parametrów bezpieczeństwa jądra systemu.
# Ryzyko: Niewłaściwe ustawienia jądra mogą osłabić mechanizmy obronne.
function check_kernel_parameters() {
    log_info "Sprawdzanie parametrów bezpieczeństwa jądra (sysctl)..."
    echo -e "\n========================================================" >> "$REPORT_FILE"
    echo " SEKCJA 8: PARAMETRY JĄDRA SYSTEMU (sysctl)" >> "$REPORT_FILE"
    echo -e "========================================================\n" >> "$REPORT_FILE"

    if ! command -v sysctl &> /dev/null; then
        log_error "Polecenie 'sysctl' nie jest dostępne. Pomijam ten test."
        echo "BŁĄD: Brak polecenia sysctl." >> "$REPORT_FILE"
        return 1
    fi

    # Sprawdzenie ASLR (Address Space Layout Randomization)
    local aslr_status=$(sysctl -n kernel.randomize_va_space)
    echo "ASLR (kernel.randomize_va_space) = $aslr_status" >> "$REPORT_FILE"
    if [[ "$aslr_status" != "2" ]]; then
        log_warn "ASLR nie jest w pełni włączone (wartość: $aslr_status, zalecane: 2)."
        echo "UWAGA: ASLR nie jest w pełni aktywne. Utrudnia to ataki typu 'return-to-libc'." >> "$REPORT_FILE"
    else
        log_info "ASLR jest poprawnie skonfigurowane."
        echo "STATUS: OK (ASLR włączone)." >> "$REPORT_FILE"
    fi

    # Blokowanie logowania pakietów z fałszywym adresem źródłowym
    local rp_filter_status=$(sysctl -n net.ipv4.conf.all.rp_filter)
    echo "RP Filter (net.ipv4.conf.all.rp_filter) = $rp_filter_status" >> "$REPORT_FILE"
    if [[ "$rp_filter_status" != "1" ]]; then
        log_warn "Ochrona przed IP spoofingiem (rp_filter) nie jest włączona."
        echo "UWAGA: Zalecane ustawienie 'net.ipv4.conf.all.rp_filter = 1'." >> "$REPORT_FILE"
    else
        log_info "Ochrona przed IP spoofingiem jest aktywna."
        echo "STATUS: OK (rp_filter włączony)." >> "$REPORT_FILE"
    fi
}

# Cel: Identyfikacja procesów zużywających najwięcej zasobów.
# Ryzyko: Nietypowe, zasobożerne procesy mogą wskazywać na malware lub problemy.
function check_running_processes() {
    log_info "Analiza uruchomionych procesów..."
    echo -e "\n========================================================" >> "$REPORT_FILE"
    echo " SEKCJA 9: PROCESY ZUŻYWAJĄCE NAJWIĘCEJ ZASOBÓW" >> "$REPORT_FILE"
    echo -e "========================================================\n" >> "$REPORT_FILE"

    echo "Procesy o największym zużyciu pamięci (Top 10):" >> "$REPORT_FILE"
    ps -eo comm,pid,user,%mem --sort=-%mem | head -n 11 >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    
    echo "Procesy o największym zużyciu CPU (Top 10):" >> "$REPORT_FILE"
    ps -eo comm,pid,user,%cpu --sort=-%cpu | head -n 11 >> "$REPORT_FILE"

    log_info "Zakończono analizę procesów."
}

#FUNKCJE POMOCNICZE I CLI

function show_help() {
    echo "CyberSentinel - System Audit (Bash)"
    echo "-----------------------------------"
    echo "Skrypt do audytu bezpieczeństwa lokalnego systemu Linux."
    echo ""
    echo "Użycie: $0 [OPCJE]"
    echo "Opcje:"
    echo "  -o, --output <plik>    Ścieżka do zapisu raportu (domyślnie: audit_report.txt)"
    echo "  -v, --verbose          Tryb szczegółowy (debug na konsolę)"
    echo "  -h, --help             Wyświetla tę pomoc"
    echo ""
    echo "Przykład:"
    echo "  sudo ./audit.sh -o raport_koncowy.txt -v"
    exit 0
}

#  GŁÓWNA PĘTLA PROGRAMU (MAIN)

# Parsowanie argumentów
while [[ $# -gt 0 ]]; do
    case "$1" in
        -o|--output)
            REPORT_FILE="$2"
            shift; shift
            ;;
        -v|--verbose)
            VERBOSE=1
            # Ustawienie zmiennej w zaimportowanym utils.sh
            VERBOSE_MODE=1
            shift
            ;;
        -h|--help)
            show_help
            ;;
        *)
            log_error "Nieznana opcja: $1"
            show_help
            ;;
    esac
done

# Start audytu
echo "Rozpoczynanie audytu CyberSentinel..."
log_info "Plik wyjściowy raportu: $REPORT_FILE"

# Inicjalizacja pliku raportu
echo "CYBERSENTINEL - RAPORT AUDYTU SYSTEMOWEGO" > "$REPORT_FILE"
echo "Data: $(date)" >> "$REPORT_FILE"
echo "Host: $(hostname)" >> "$REPORT_FILE"
echo "--------------------------------------------------------" >> "$REPORT_FILE"

# Sprawdzenie uprawnień
check_root
if [[ $? -ne 0 ]]; then
    log_warn "Skrypt uruchomiony bez uprawnień roota. Niektóre testy zostaną pominięte."
    echo "UWAGA: Audyt uruchomiony bez uprawnień roota!" >> "$REPORT_FILE"
fi

# Wykonanie poszczególnych modułów
check_suid_sgid_files
check_world_writable
check_ssh_config
check_firewall
check_users_shadow
check_open_ports
check_password_policy
check_kernel_parameters
check_running_processes

# Zakończenie
echo -e "\n========================================================" >> "$REPORT_FILE"
echo " KONIEC RAPORTU" >> "$REPORT_FILE"
echo "========================================================" >> "$REPORT_FILE"

log_info "Audyt zakończony sukcesem."
log_info "Wyniki zapisano w: $REPORT_FILE"

exit 0