# 🛠️ Cacti Auto Installer for Ubuntu

Script ini dibuat untuk otomatisasi proses instalasi **Cacti** di Ubuntu.  
Semua dependensi seperti Apache, PHP, MariaDB, SNMP, RRDTool, dan konfigurasi dasar akan disiapkan otomatis.

---

## 📦 Fitur yang Diinstal
- Apache2 + PHP (beserta ekstensi yang dibutuhkan Cacti)
- MariaDB (dengan tuning performa buat Cacti)
- SNMP + RRDTool
- Cacti (latest version)
- Konfigurasi database dan cron job poller
- Virtual host Apache untuk akses via `http://your_ip/cacti`

---

## 🚀 Cara Pakai

1. Simpan script ini sebagai `install-cacti.sh`
2. Jalankan perintah:
   ```bash
   chmod +x install-cacti.sh
   sudo ./install-cacti.sh
