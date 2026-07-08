#!/bin/bash

# Plik: audit.sh
# Opis: Rozszerzony skrypt do audytu bezpieczeństwa i konfiguracji systemu Linux.
#
# Ten skrypt wykonuje serię sprawdzeń konfiguracyjnych i bezpieczeństwa,
# aby zidentyfikować potencjalne słabości w systemie.

# Ustalenie ścieżki do bieżącego skryptu, aby móc załadować inne pliki
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "${SCRIPT_DIR}/utils.sh"

# === Główne funkcje audytu ===

# Funkcja: Sprawdza pliki z bitem SUID/SGID (potencjalnie niebezpieczne)
function check_suid_sgid_files() {
    log_info "Audyt plików SUID/SGID"
    
    local search_paths=("/usr/bin" "/usr/sbin" "/bin" "/sbin" "/usr/local/bin" "/usr/local/sbin")
    local found_files=0

    log_debug "Przeszukiwane ścieżki: ${search_paths[*]}"

    for path in "${search_paths[@]}"; do
        if [[ ! -d "$path" ]]; then
            log_debug "Katalog $path nie istnieje, pomijam."
            continue
        fi

        # Szukamy plików SUID (4000) lub SGID (2000)
        local files=$(find "$path" \( -perm -4000 -o -perm -2000 \) -type f 2>/dev/null)

        if [[ -n "$files" ]]; then
            log_warn "Znaleziono potencjalnie niebezpieczne pliki w $path:"
            echo "$files" | while IFS= read -r file; do
                log_warn "  - $file ($(stat -c '%a %U:%G' "$file"))"
            done
            found_files=1
        fi
    done

    if [[ "$found_files" -eq 0 ]]; then
        log_info "Nie znaleziono plików SUID/SGID w standardowych lokalizacjach."
    else
        log_info "Przegląd powyższych plików jest zalecany."
    fi
}

# Funkcja: Sprawdza, czy SSH pozwala na logowanie roota i inne ustawienia
function check_ssh_config() {
    log_info "Audyt konfiguracji demona SSH"
    local ssh_config="/etc/ssh/sshd_config"
    
    if [[ ! -r "$ssh_config" ]]; then
        log_error "Brak dostępu do pliku $ssh_config - pomijam testy SSH."
        return 1
    fi

    # PermitRootLogin
    if grep -qE "^\s*PermitRootLogin\s+yes" "$ssh_config"; then
        log_error "KRYTYCZNE: Logowanie roota przez SSH jest WŁĄCZONE (PermitRootLogin yes)!"
    else
        log_info "OK: Logowanie roota przez SSH jest wyłączone lub ograniczone."
    fi

    # PasswordAuthentication
    if grep -qE "^\s*PasswordAuthentication\s+yes" "$ssh_config"; then
        log_warn "UWAGA: Uwierzytelnianie hasłem w SSH jest włączone. Zalecane jest użycie kluczy."
    else
        log_info "OK: Uwierzytelnianie hasłem w SSH jest wyłączone."
    fi

    # Protocol
    if grep -qE "^\s*Protocol\s+1" "$ssh_config"; then
        log_error "KRYTYCZNE: SSH może używać przestarzałego protokołu v1."
    else
        log_info "OK: SSH używa bezpiecznego protokołu v2."
    fi

    # X11Forwarding
    if grep -qE "^\s*X11Forwarding\s+yes" "$ssh_config"; then
        log_warn "UWAGA: X11Forwarding jest włączony. Może to stanowić ryzyko, jeśli nie jest potrzebne."
    else
        log_info "OK: X11Forwarding jest wyłączony."
    fi
}

# Funkcja: Sprawdza status firewalla (ufw lub firewalld)
function check_firewall_status() {
    log_info "Audyt stanu zapory sieciowej (Firewall)"
    
    if command -v ufw &>/dev/null; then
        log_debug "Wykryto UFW (Uncomplicated Firewall)."
        if ufw status | grep -q "Status: active"; then
            log_info "OK: Firewall UFW jest aktywny."
            log_debug "$(ufw status verbose)"
        else
            log_error "KRYTYCZNE: Firewall UFW jest nieaktywny!"
        fi
    elif command -v firewall-cmd &>/dev/null; then
        log_debug "Wykryto firewalld."
        if systemctl is-active --quiet firewalld; then
            log_info "OK: Usługa firewalld jest aktywna."
            log_debug "Stan firewalld: $(firewall-cmd --state)"
        else
            log_error "KRYTYCZNE: Usługa firewalld nie jest aktywna!"
        fi
    else
        log_warn "Nie znaleziono UFW ani firewalld. Ręczna weryfikacja iptables."
        if [[ "$VERBOSE_MODE" -eq 1 ]]; then
            iptables -L -n -v
        fi
    fi
}

# Funkcja: Sprawdza konta z pustymi hasłami
function check_empty_passwords() {
    log_info "Audyt kont użytkowników pod kątem pustych haseł"
    check_root >/dev/null || return 1 # Wymaga roota

    # Sprawdza drugi-field, jesli jest pusty to nie ma hasla.
    local empty_password_users=$(sudo awk -F: '($2 == "") { print $1 }' /etc/shadow)

    if [[ -n "$empty_password_users" ]]; then
        log_error "KRYTYCZNE: Znaleziono użytkowników z pustym hasłem:"
        echo "$empty_password_users" | while IFS= read -r user; do
            log_error "  - $user"
        done
    else
        log_info "OK: Nie znaleziono kont użytkowników z pustymi hasłami."
    fi
}

# Funkcja: Sprawdza użycie przestrzeni dyskowej
function check_disk_space() {
    log_info "Audyt przestrzeni dyskowej"
    local threshold=90
    local alert_found=0

    df -H | grep "^/dev/" | while read -r line; do
        local usage=$(echo "$line" | awk '{ print $5 }' | sed 's/%//')
        local mount_point=$(echo "$line" | awk '{ print $6 }')

        if [[ "$usage" -gt "$threshold" ]]; then
            log_warn "System plików '$mount_point' jest zajęty w $usage% (próg: ${threshold}%)."
            alert_found=1
        fi
    done

    if [[ "$alert_found" -eq 0 ]]; then
        log_info "OK: Użycie przestrzeni dyskowej jest w normie."
    fi
}

# Funkcja: Sprawdza podatność na "Shellshock"
function check_shellshock_vulnerability() {
    log_info "Audyt podatności na Shellshock (CVE-2014-6271)"
    
    local test_result
    test_result=$(env 'x=() { :;}; echo VULNERABLE' bash -c "echo Test completed" 2>/dev/null)

    if [[ "$test_result" == *"VULNERABLE"* ]]; then
        log_error "KRYTYCZNE: Wykryto podatność na atak Shellshock! Zaktualizuj powłokę bash."
    else
        log_info "OK: System nie wydaje się być podatny na podstawowy wariant Shellshock."
    fi
}

# Funkcja: Sprawdza uprawnienia do kluczowych plików systemowych
function check_critical_file_permissions() {
    log_info "Audyt uprawnień kluczowych plików systemowych"

    local files_to_check=(
        "/etc/passwd 644"
        "/etc/shadow 640"
        "/etc/group 644"
        "/etc/gshadow 640"
        "/etc/sudoers 440"
    )
    local all_ok=true

    for item in "${files_to_check[@]}"; do
        local file=$(echo "$item" | cut -d' ' -f1)
        local expected_perms=$(echo "$item" | cut -d' ' -f2)
        
        if [[ ! -e "$file" ]]; then
            log_debug "Plik $file nie istnieje, pomijam."
            continue
        fi

        # Wymagane są uprawnienia roota do odczytu niektórych plików
        if [[ ! -r "$file" ]]; then
            log_warn "Brak uprawnień do odczytu $file. Uruchom jako root dla pełnej weryfikacji."
            continue
        fi

        local current_perms=$(stat -c "%a" "$file")

        if [[ "$current_perms" != "$expected_perms" ]]; then
            log_warn "Plik $file ma niezalecane uprawnienia ($current_perms), oczekiwano ($expected_perms)."
            all_ok=false
        fi
    done

    if [[ "$all_ok" == "true" ]]; then
        log_info "OK: Uprawnienia kluczowych plików są zgodne z zaleceniami."
    fi
}

# Funkcja: Audyt zadań cron
function audit_cron_jobs() {
    log_info "Audyt zadań zaplanowanych (cron)"
    local cron_files=("/etc/crontab")
    cron_files+=($(find /etc/cron.d/ -type f))
    local insecure_path=0

    # Sprawdzenie ścieżki PATH w /etc/crontab
    if grep -q "PATH=.*:.:" /etc/crontab; then
        log_warn "W /etc/crontab znaleziono niebezpieczną ścieżkę PATH (zawiera '.')."
        insecure_path=1
    fi
    
    for cron_file in "${cron_files[@]}"; do
        if [[ ! -r "$cron_file" ]]; then continue; fi
        log_debug "Analiza pliku: $cron_file"
        
        # Sprawdzanie uprawnień - nie powinien być zapisywalny dla wszystkich
        if [[ $(stat -c "%a" "$cron_file") == *"7"* || $(stat -c "%a" "$cron_file") == *"6"* || $(stat -c "%a" "$cron_file") == *"2"* ]]; then
             if [[ $(stat -c "%a" "$cron_file") != "600" && $(stat -c "%a" "$cron_file") != "644" ]]; then
                log_warn "Plik cron '$cron_file' ma niebezpieczne uprawnienia: $(stat -c '%a' "$cron_file")"
             fi
        fi
    done
    
    if [[ "$insecure_path" -eq 0 ]]; then
        log_info "OK: Nie znaleziono podstawowych problemów z PATH w crontab."
    fi
}


# === Główna funkcja wykonawcza ===
main() {
    if [[ "$1" == "-v" ]]; then
        VERBOSE_MODE=1
        log_debug "Tryb gadatliwy włączony."
    fi

    check_root

    log_info "ROZPOCZĘCIE AUDYTU SYSTEMU ($(date))"
    
    check_ssh_config
    check_suid_sgid_files
    check_firewall_status
    check_empty_passwords
    check_disk_space
    check_shellshock_vulnerability
    check_critical_file_permissions
    audit_cron_jobs

    log_info "ZAKOŃCZENIE AUDYTU SYSTEMU"
}

# Wywołanie głównej funkcji z przekazaniem argumentów
main "$@"
