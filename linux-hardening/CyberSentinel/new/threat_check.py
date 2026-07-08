import json
import threading
import time
import random
import queue
import argparse
import sys
from datetime import datetime


# Opis: Moduł "Threat Intelligence" wykorzystujący wielowątkowość.
#       Pobiera adresy IP z raportu JSON i równolegle sprawdza ich reputację
#       (symulacja zapytań do zewnętrznego API).

# Konfiguracja
NUM_THREADS = 4
CHECK_DELAY_MIN = 0.5
CHECK_DELAY_MAX = 2.0

print_lock = threading.Lock()
#Wczytuje dane z pliku JSON.
def load_data(filepath):
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            return json.load(f)
    except FileNotFoundError:
        with print_lock:
            print(f"[ERROR] Nie znaleziono pliku: {filepath}")
        sys.exit(1)
#Funkcja wykonywana przez każdy wątek.
def worker_threat_scanner(q, worker_id):
    
    while True:
        try:
            # Pobierz IP z kolejki 
            ip_data = q.get_nowait()
        except queue.Empty:
            break

        ip = ip_data.get('ip')
        attempts = ip_data.get('count')

        # Symulacja pracy sieciowej 
        delay = random.uniform(CHECK_DELAY_MIN, CHECK_DELAY_MAX)
        time.sleep(delay)

        # Symulacja wyniku (Randomowa ocena reputacji)
        risk_score = random.randint(0, 100)
        
        # Logika biznesowa oceny
        status = "CZYSTY"
        color = "\033[92m" # Zielony
        
        if risk_score > 80:
            status = "BLACKLISTA"
            color = "\033[91m" # Czerwony
        elif risk_score > 50:
            status = "PODEJRZANY"
            color = "\033[93m" # Żółty
            
        reset = "\033[0m"

        # Bezpieczne wypisanie wyniku (sekcja krytyczna)
        with print_lock:
            print(f"[Wątek-{worker_id}] Sprawdzanie {ip:<15} (Prób: {attempts}) -> {color}{status} (Score: {risk_score}/100){reset}")

        q.task_done()

def main():
    parser = argparse.ArgumentParser(description="Multi-threaded Threat Checker")
    parser.add_argument("-j", "--json", required=True, help="Ścieżka do raportu JSON")
    args = parser.parse_args()

    print(f"--- Uruchamianie skanera zagrożeń (Wątki: {NUM_THREADS}) ---")
    
    data = load_data(args.json)
    attackers = data.get('top_attackers', [])

    if not attackers:
        print("Brak danych do przetworzenia.")
        return

    # 1. Utworzenie kolejki zadań
    task_queue = queue.Queue()
    
    for item in attackers:
        task_queue.put(item)
    
    print(f"Załadowano {task_queue.qsize()} adresów IP do kolejki analizy.\n")

    # 2. Uruchomienie wątków
    threads = []
    for i in range(NUM_THREADS):
        t = threading.Thread(target=worker_threat_scanner, args=(task_queue, i+1))
        t.start()
        threads.append(t)

    # 3. Oczekiwanie na zakończenie wątków
    for t in threads:
        t.join()

    print("\n--- Analiza zakończona. Wszystkie wątki zameldowały wykonanie zadań. ---")

if __name__ == "__main__":
    main()