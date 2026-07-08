#!/bin/bash

# --- Definicje kolorów do outputu ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Zmienna globalna kontrolująca tryb gadatliwy
VERBOSE_MODE=0

# Funkcja: Drukuje logi informacyjne
# Argument 1: Treść wiadomości
function log_info() {
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo -e "${BLUE}[INFO]${NC} [${timestamp}] $1"
}

# Funkcja: Drukuje błędy na stderr
# Argument 1: Treść błędu
function log_error() {
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo -e "${RED}[ERROR]${NC} [${timestamp}] $1" >&2
}

# Funkcja: Drukuje ostrzeżenia
function log_warn() {
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo -e "${YELLOW}[WARN]${NC} [${timestamp}] $1"
}

# Funkcja: Logowanie szczegółowe (tylko gdy -v jest włączone)
function log_debug() {
    if [[ "$VERBOSE_MODE" -eq 1 ]]; then
         echo -e "${NC}[DEBUG] $1${NC}"
    fi
}

# Funkcja: Sprawdza czy użytkownik to root
function check_root() {
    if [[ $EUID -ne 0 ]]; then
       log_error "Ten skrypt powinien być uruchomiony jako root, aby mieć dostęp do logów systemowych."
       # Nie kończymy działania, bo to projekt studencki, ale ostrzegamy
       return 1
    fi
    return 0
}