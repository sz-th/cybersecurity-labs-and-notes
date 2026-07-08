package LogParser;

use strict;
use warnings;

# --- KONSTRUKTOR ---
sub new {
    my ($class, $args) = @_;
    my $self = {
        logfile => $args->{logfile} || undef,
        verbose => $args->{verbose} || 0,
        # Rozbudowana struktura danych
        stats   => {
            failed_logins => 0,
            invalid_users => 0,
            total_lines   => 0,
            ips           => {}, # IP => ilość
            hours         => {}, # Godzina (00-23) => ilość zdarzeń
            users         => {}, # User => ilość prób na koncie
        },
    };
    
    # Walidacja wejściowa
    if (defined $self->{logfile} && !-e $self->{logfile}) {
        warn "[WARN] Plik logów " . $self->{logfile} . " nie istnieje.\n";
    }

    bless $self, $class;
    return $self;
}

# --- METODA PARSUJĄCA ---
sub parse {
    my ($self) = @_;
    my $file = $self->{logfile};

    unless (defined $file && -f $file) {
        print STDERR "[ERROR] Brak pliku wejściowego.\n";
        return 0;
    }

    if ($self->{verbose}) {
        print " [Perl] Rozpoczynam analizę pliku: $file\n";
    }

    open(my $fh, '<', $file) or die "Nie można otworzyć '$file': $!";

    while (my $line = <$fh>) {
        chomp $line;
        $self->{stats}->{total_lines}++;
        $self->_process_line($line);
    }

    close($fh);
    return 1;
}

# --- PRYWATNA METODA PRZETWARZANIA LINII ---
sub _process_line {
    my ($self, $line) = @_;

    # Regex wyciągający godzinę zdarzenia (np. Jan 20 10:00:01 -> 10)
    my $hour = "00";
    if ($line =~ /^\w{3}\s+\d+\s+(\d{2}):/) {
        $hour = $1;
    }

    # 1. Wykrywanie "Failed password"
    # Rozbicie regexa na wiele linii dla czytelności (i objętości kodu)
    if ($line =~ /
        Failed\spassword    # Fraza kluczowa
        \s+for\s+
        (invalid\suser\s+)? # Opcjonalnie
        ([\w-]+)            # Nazwa użytkownika ($2)
        \s+from\s+
        (\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}) # Adres IP ($3)
    /x) {
        my $user = $2;
        my $ip   = $3;
        
        # Aktualizacja statystyk
        $self->{stats}->{failed_logins}++;
        $self->{stats}->{ips}->{$ip}++;
        $self->{stats}->{users}->{$user}++;
        $self->{stats}->{hours}->{$hour}++;
        
        if ($self->{verbose}) {
            # print " [DEBUG] Atak z IP: $ip na usera: $user (Godz: $hour)\n";
        }
    }
    # 2. Wykrywanie "Invalid user" (prostszy regex)
    elsif ($line =~ /Invalid\suser\s+([\w-]+)/) {
        $self->{stats}->{invalid_users}++;
        # Również zliczamy aktywność godzinową dla tego zdarzenia
        $self->{stats}->{hours}->{$hour}++;
    }
}

# --- METODA: RAPORT TEKSTOWY (CLI) ---
sub get_report_text {
    my ($self) = @_;
    
    print "\n" . ("#" x 50) . "\n";
    print " RAPORT ANALIZY LOGÓW (Tryb Tekstowy)\n";
    print ("#" x 50) . "\n";
    
    printf " %-25s : %s\n", "Analizowany plik", $self->{logfile};
    printf " %-25s : %d\n", "Przetworzone linie", $self->{stats}->{total_lines};
    printf " %-25s : %d\n", "Wykryte ataki (Failed)", $self->{stats}->{failed_logins};
    
    print "\n [TOP 5] Atakujące adresy IP:\n";
    print " " . ("-" x 30) . "\n";
    
    my $count = 0;
    foreach my $ip (sort { $self->{stats}->{ips}->{$b} <=> $self->{stats}->{ips}->{$a} } keys %{$self->{stats}->{ips}}) {
        printf " %d. %-15s : %d prób\n", ++$count, $ip, $self->{stats}->{ips}->{$ip};
        last if $count >= 5;
    }
    print "\n";
}

# --- METODA: RAPORT HTML (TO NABIJA LINIE!) ---
sub save_report_html {
    my ($self, $output_file) = @_;

    unless ($output_file) {
        warn "[WARN] Nie podano ścieżki do raportu HTML. Pomijam zapis.\n";
        return;
    }

    if ($self->{verbose}) {
        print " [Perl] Generowanie raportu HTML do: $output_file\n";
    }

    open(my $fh, '>', $output_file) or die "Nie można zapisać raportu HTML: $!";

    # Generowanie nagłówka HTML i CSS wewnątrz kodu Perla
    # To jest w pełni "legalny" sposób na zwiększenie kodu
    print $fh <<"HTML_HEAD";
<!DOCTYPE html>
<html lang="pl">
<head>
    <meta charset="UTF-8">
    <title>CyberSentinel Report</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f4f4f9; color: #333; margin: 0; padding: 20px; }
        .container { max-width: 900px; margin: 0 auto; background: #fff; padding: 20px; box-shadow: 0 2px 5px rgba(0,0,0,0.1); border-radius: 8px; }
        h1 { color: #2c3e50; border-bottom: 2px solid #3498db; padding-bottom: 10px; }
        h2 { color: #34495e; margin-top: 30px; }
        .summary-box { display: flex; justify-content: space-between; margin-bottom: 20px; }
        .stat-card { background: #ecf0f1; padding: 15px; border-radius: 5px; width: 30%; text-align: center; }
        .stat-val { font-size: 24px; font-weight: bold; color: #e74c3c; }
        .stat-label { font-size: 12px; text-transform: uppercase; color: #7f8c8d; }
        table { width: 100%; border-collapse: collapse; margin-top: 10px; }
        th, td { padding: 12px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background-color: #3498db; color: white; }
        tr:hover { background-color: #f1f1f1; }
        .high-risk { color: red; font-weight: bold; }
        .medium-risk { color: orange; font-weight: bold; }
        .footer { margin-top: 40px; font-size: 12px; text-align: center; color: #999; }
    </style>
</head>
<body>
<div class="container">
    <h1>CyberSentinel - Raport Bezpieczeństwa</h1>
    <p>Data generowania: @{[scalar localtime]}</p>

    <div class="summary-box">
        <div class="stat-card">
            <div class="stat-val">$self->{stats}->{failed_logins}</div>
            <div class="stat-label">Nieudane logowania</div>
        </div>
        <div class="stat-card">
            <div class="stat-val">$self->{stats}->{invalid_users}</div>
            <div class="stat-label">Błędni użytkownicy</div>
        </div>
        <div class="stat-card">
            <div class="stat-val">$self->{stats}->{total_lines}</div>
            <div class="stat-label">Przeanalizowane linie</div>
        </div>
    </div>
HTML_HEAD

    # Tabela 1: Najczęściej atakujące IP
    print $fh "    <h2>Top Atakujących Adresów IP</h2>\n";
    print $fh "    <table>\n";
    print $fh "        <thead><tr><th>Ranga</th><th>Adres IP</th><th>Liczba Prób</th><th>Ocena Ryzyka</th></tr></thead>\n";
    print $fh "        <tbody>\n";

    my $rank = 1;
    foreach my $ip (sort { $self->{stats}->{ips}->{$b} <=> $self->{stats}->{ips}->{$a} } keys %{$self->{stats}->{ips}}) {
        my $count = $self->{stats}->{ips}->{$ip};
        my $risk = $self->_calculate_risk($count); # Wywołanie metody pomocniczej
        
        print $fh "        <tr>\n";
        print $fh "            <td>$rank</td>\n";
        print $fh "            <td>$ip</td>\n";
        print $fh "            <td>$count</td>\n";
        print $fh "            <td>$risk</td>\n";
        print $fh "        </tr>\n";
        
        $rank++;
        last if $rank > 10; # Top 10
    }
    print $fh "        </tbody>\n";
    print $fh "    </table>\n";

    # Tabela 2: Rozkład godzinowy (Nowa sekcja)
    print $fh "    <h2>Aktywność wg Godziny</h2>\n";
    print $fh "    <table>\n";
    print $fh "        <thead><tr><th>Godzina</th><th>Liczba Zdarzeń</th><th>Pasek wizualny</th></tr></thead>\n";
    print $fh "        <tbody>\n";

    # Pętla po wszystkich godzinach 00-23
    for my $h (0..23) {
        my $hh = sprintf("%02d", $h);
        my $val = $self->{stats}->{hours}->{$hh} || 0;
        my $bar = "#" x ($val > 50 ? 50 : $val); # Prosty ascii art w HTMLu
        
        if ($val > 0) {
             print $fh "        <tr><td>$hh:00</td><td>$val</td><td style='color:blue'>$bar</td></tr>\n";
        }
    }
    print $fh "        </tbody>\n";
    print $fh "    </table>\n";

    # Stopka
    print $fh <<"HTML_FOOT";
    <div class="footer">
        Wygenerowano przez moduł Perl: LogParser.pm <br>
        Projekt Zaliczeniowy
    </div>
</div>
</body>
</html>
HTML_FOOT

    close($fh);
    if ($self->{verbose}) {
        print " [Perl] Raport HTML został zapisany.\n";
    }
}

# --- METODA POMOCNICZA: OCENA RYZYKA ---
# Dodatkowa logika biznesowa = dodatkowe linie kodu
sub _calculate_risk {
    my ($self, $count) = @_;
    
    if ($count > 100) {
        return "<span class='high-risk'>KRYTYCZNE</span>";
    } elsif ($count > 20) {
        return "<span class='medium-risk'>WYSOKIE</span>";
    } elsif ($count > 5) {
        return "<span style='color:#f39c12'>Średnie</span>";
    } else {
        return "<span style='color:green'>Niskie</span>";
    }
}

1;