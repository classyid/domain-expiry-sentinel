#!/bin/bash

# Konfigurasi
MAX_PARALLEL_PROCESSES=3
TIMEOUT_SECONDS=60
RETRY_COUNT=3
RETRY_DELAY=5
LOG_FILE="domain_checker.log"
OUTPUT_FILE="domain_info.txt"
DEBUG_MODE=false

# Konfigurasi Telegram
TELEGRAM_TOKEN="<ID-TOKEN>"
CHAT_ID="<ID-CHAT>"

# Fungsi untuk mengirim pesan ke Telegram
send_telegram_message() {
    local message="$1"
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
        -d "chat_id=${CHAT_ID}" \
        -d "text=${message}" \
        -d "parse_mode=HTML"
}

# Fungsi untuk mengirim file ke Telegram
send_telegram_document() {
    local file="$1"
    local caption="$2"
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendDocument" \
        -F "chat_id=${CHAT_ID}" \
        -F "document=@${file}" \
        -F "caption=${caption}"
}

# Fungsi logging
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    if [ "$DEBUG_MODE" = true ] && [ "$level" = "DEBUG" ]; then
        echo "[$timestamp] [$level] $message"
    fi
}

# Fungsi untuk mengekstrak Registry Expiry Date
extract_registry_expiry() {
    local whois_output="$1"
    
    local expiry_patterns=(
        'Registry Expiry Date:'
        'Registrar Registration Expiration Date:'
        'Registry Expiration Date:'
        'Expiration Date:'
        'Expires:'
        'Expiry Date:'
    )
    
    for pattern in "${expiry_patterns[@]}"; do
        local expiry_date=$(echo "$whois_output" | grep -i "^[[:space:]]*$pattern" | cut -d':' -f2- | awk '{$1=$1};1' | head -1)
        if [ ! -z "$expiry_date" ]; then
            expiry_date=$(echo "$expiry_date" | sed -E 's/\s*\[.*\]\s*//g' | tr -d ',' | sed 's/[[:space:]]*$//')
            if date -d "$expiry_date" >/dev/null 2>&1; then
                echo "$expiry_date"
                return 0
            fi
        fi
    done
    
    echo "N/A"
    return 1
}

# Fungsi untuk menghitung selisih hari
calculate_days_difference() {
    local expiration_date="$1"
    
    if [ "$expiration_date" = "N/A" ]; then
        echo "N/A"
        return 0
    fi
    
    local current_date=$(date +%s)
    local expiration_timestamp=$(date -d "$expiration_date" +%s)
    
    local days_difference=$((($expiration_timestamp - $current_date) / (86400)))
    echo "$days_difference"
}

# Fungsi untuk memproses satu domain dengan retry
process_domain() {
    local domain="$1"
    local temp_file="temp_whois_${domain}"
    local retry=0
    local success=false
    
    log_message "INFO" "Memeriksa domain: $domain"
    
    while [ $retry -lt $RETRY_COUNT ] && [ "$success" = false ]; do
        if [ $retry -gt 0 ]; then
            log_message "INFO" "Mencoba ulang ($retry/$RETRY_COUNT) untuk domain: $domain"
            sleep $RETRY_DELAY
        fi
        
        if timeout $TIMEOUT_SECONDS whois "$domain" > "$temp_file" 2>/dev/null; then
            if [ -s "$temp_file" ]; then
                success=true
                break
            fi
        fi
        
        retry=$((retry + 1))
    done
    
    if [ "$success" = false ]; then
        log_message "ERROR" "Gagal mengambil data whois untuk $domain setelah $RETRY_COUNT percobaan"
        echo "Domain: $domain"
        echo "Status: Error - Tidak dapat mengambil data whois"
        echo "----------------------------------------"
        rm -f "$temp_file"
        return 1
    fi
    
    local whois_output=$(cat "$temp_file")
    local expiry_date=$(extract_registry_expiry "$whois_output")
    local days_until=$(calculate_days_difference "$expiry_date")
    
    {
        echo "Domain: $domain"
        echo "Registry Expiry Date: $expiry_date"
        if [ "$days_until" = "N/A" ]; then
            echo "Days Until Expiration: N/A"
        else
            echo "Days Until Expiration: $days_until days"
        fi
        
        echo "Name Servers:"
        echo "$whois_output" | grep -i "^[[:space:]]*Name Server:" | cut -d':' -f2- | sed 's/^[[:space:]]*/  - /'
        
        local status=$(echo "$whois_output" | grep -i "^[[:space:]]*Domain Status:" | head -1 | cut -d':' -f2- | sed 's/^[[:space:]]*//')
        echo "Status: ${status:-N/A}"
        echo "----------------------------------------"
    } | tee -a "$OUTPUT_FILE"
    
    rm -f "$temp_file"
}

# Array nama domain
domains=(
    "s.id" "github.com" "telegram.org" "whatsapp.com" "mikrotik.com"
)

# Inisialisasi
mkdir -p cache
echo "" > "$LOG_FILE"
> "$OUTPUT_FILE"

# Dapatkan timestamp untuk laporan
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
TOTAL_DOMAINS=${#domains[@]}

log_message "INFO" "Memulai pemeriksaan domain"
send_telegram_message "🔍 <b>Mulai Pemeriksaan Domain</b>
📅 Waktu: $TIMESTAMP
📊 Total Domain: $TOTAL_DOMAINS

⏳ Proses pemeriksaan sedang berjalan..."

current=0

# Process domains
for domain in "${domains[@]}"; do
    process_domain "$domain"
    current=$((current + 1))
    echo -ne "\rProgress: $current/$TOTAL_DOMAINS domains processed"
done

echo -e "\n"
log_message "INFO" "Pemeriksaan domain selesai"

# Hitung statistik
EXPIRED_COUNT=$(grep -c "Days Until Expiration: -" "$OUTPUT_FILE")
ERROR_COUNT=$(grep -c "Status: Error" "$OUTPUT_FILE")
ACTIVE_COUNT=$((TOTAL_DOMAINS - EXPIRED_COUNT - ERROR_COUNT))

# Buat ringkasan untuk caption Telegram
SUMMARY="📊 <b>Laporan Pemeriksaan Domain</b>
📅 Waktu: $TIMESTAMP

📈 Statistik:
✅ Domain Aktif: $ACTIVE_COUNT
⚠️ Domain Expired: $EXPIRED_COUNT
❌ Gagal Check: $ERROR_COUNT
📝 Total Domain: $TOTAL_DOMAINS"

# Kirim pesan ringkasan
send_telegram_message "$SUMMARY"

# Kirim file hasil
send_telegram_document "$OUTPUT_FILE" "💾 Hasil pemeriksaan domain lengkap
🕒 Generated: $TIMESTAMP"

# Kirim file log
send_telegram_document "$LOG_FILE" "📋 Log file pemeriksaan domain
🕒 Generated: $TIMESTAMP"

echo "=== Pengecekan Domain Selesai ==="
echo "Hasil lengkap tersimpan di: $OUTPUT_FILE"
echo "Log tersimpan di: $LOG_FILE"
echo "Laporan telah dikirim ke Telegram"
