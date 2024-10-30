# README.md
# Domain Expiry Sentinel 🚨

Tool monitoring domain yang powerful untuk memantau status dan masa aktif domain secara otomatis. Dirancang khusus untuk kemudahan pengelolaan multiple domain dengan notifikasi real-time via Telegram.

## ✨ Fitur Utama

- 🔄 Pemeriksaan otomatis untuk multiple domain
- 📱 Notifikasi Telegram real-time
- 📊 Laporan detail dalam berbagai format
- 🔍 Mendukung berbagai TLD (.id, .co.id, .com, dll)
- ⚡ Parallel processing untuk kecepatan optimal
- 🔄 Sistem retry otomatis untuk koneksi tidak stabil
- 📝 Logging lengkap untuk audit
- 💾 Penyimpanan cache untuk efisiensi

## 🚀 Cara Penggunaan

### Prasyarat
```bash
# Install whois jika belum terinstall
sudo apt-get install whois

# Install curl untuk notifikasi Telegram
sudo apt-get install curl
```

### Instalasi
```bash
# Clone repository
git clone https://github.com/classyid/domain-expiry-sentinel.git

# Masuk ke direktori
cd domain-expiry-sentinel

# Berikan izin eksekusi
chmod +x domain_checker.sh
```

### Konfigurasi
1. Buka file `domain_checker.sh`
2. Sesuaikan konfigurasi Telegram:
```bash
TELEGRAM_TOKEN="your_telegram_bot_token"
CHAT_ID="your_chat_id"
```
3. Edit array domains sesuai kebutuhan:
```bash
domains=(
    "domain1.com"
    "domain2.co.id"
    # Tambahkan domain lainnya
)
```

### Menjalankan Script
```bash
./domain_checker.sh
```

## 📋 Format Output

### File Output (domain_info.txt)
```
Domain: example.com
Registry Expiry Date: 2025-01-01
Days Until Expiration: 365 days
Name Servers:
  - ns1.example.com
  - ns2.example.com
Status: active
----------------------------------------
```

### Notifikasi Telegram
- Notifikasi awal pemeriksaan
- Ringkasan hasil dengan statistik
- File hasil lengkap
- File log untuk audit

## 🔧 Kustomisasi

### Mengubah Timeout dan Retry
```bash
TIMEOUT_SECONDS=60
RETRY_COUNT=3
RETRY_DELAY=5
```

### Format Output
Mendukung beberapa format output:
- TEXT (default)
- JSON
- CSV

## 🤝 Kontribusi
Kontribusi selalu welcome! Silakan buat Pull Request atau laporkan issue.

## 📝 Lisensi
MIT License - lihat file [LICENSE](LICENSE) untuk detail lengkap.
