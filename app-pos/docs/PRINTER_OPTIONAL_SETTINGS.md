# 🖨️ Printer Optional Settings

## Overview
Printer sekarang mendukung berbagai setting opsional untuk optimasi performa dan kualitas cetak.

## ⚙️ Available Settings

### 1. Performance Settings (Kecepatan)

#### Connection Timeout
- **Field**: `connection_timeout`
- **Type**: INTEGER (seconds)
- **Default**: 3
- **Range**: 1-10
- **Description**: Waktu maksimal untuk koneksi ke printer
- **Recommendation**:
  - LAN stabil: `2-3` detik
  - WiFi/network lambat: `5-7` detik

#### Write Timeout
- **Field**: `write_timeout`
- **Type**: INTEGER (seconds)
- **Default**: 5
- **Range**: 3-15
- **Description**: Waktu maksimal untuk mengirim data ke printer
- **Recommendation**:
  - Print sederhana: `3-5` detik
  - Print kompleks (banyak item): `8-10` detik

#### Retry Attempts
- **Field**: `retry_attempts`
- **Type**: INTEGER
- **Default**: 2
- **Range**: 0-5
- **Description**: Jumlah percobaan ulang jika gagal
- **Recommendation**:
  - Network stabil: `1-2`
  - Network tidak stabil: `3-4`
  - Disable retry: `0`

### 2. Print Quality Settings (Kualitas Cetak)

#### Print Density
- **Field**: `print_density`
- **Type**: INTEGER (percentage)
- **Default**: 50
- **Range**: 0-100
- **Description**: Kegelapan/ketebalan cetakan
- **Recommendation**:
  - Kertas tipis: `30-40%` (hemat ribbon/toner)
  - Kertas tebal: `60-80%` (hasil lebih gelap)
  - Kertas berkualitas rendah: `70-90%`

#### Print Speed
- **Field**: `print_speed`
- **Type**: TEXT
- **Default**: 'normal'
- **Options**: 'slow', 'normal', 'fast'
- **Description**: Kecepatan print (trade-off dengan kualitas)
- **Recommendation**:
  - `slow`: Kualitas terbaik, untuk struk pelanggan
  - `normal`: Balanced, untuk daily operations
  - `fast`: Kecepatan maksimal, untuk kitchen/bar orders

#### Cut Mode
- **Field**: `cut_mode`
- **Type**: TEXT
- **Default**: 'partial'
- **Options**: 'full', 'partial', 'none'
- **Description**: Mode pemotongan kertas
- **Recommendation**:
  - `full`: Full cut, kertas terpisah sempurna
  - `partial`: Partial cut, masih ada sedikit lipatan (hemat waktu)
  - `none`: No cut, manual cutting (hemat blade)

### 3. Advanced Settings (Fitur Tambahan)

#### Enable Beep
- **Field**: `enable_beep`
- **Type**: INTEGER (boolean)
- **Default**: 1
- **Options**: 0 (off), 1 (on)
- **Description**: Bunyi beep setelah print selesai
- **Recommendation**:
  - Kitchen/Bar: ON (notifikasi jelas)
  - Cashier: OFF (lebih profesional/quiet)

#### Auto Cut
- **Field**: `auto_cut`
- **Type**: INTEGER (boolean)
- **Default**: 1
- **Options**: 0 (off), 1 (on)
- **Description**: Otomatis cut setelah print
- **Recommendation**:
  - Standard operation: ON
  - Continuous printing: OFF (manual cut batch)

#### Charset
- **Field**: `charset`
- **Type**: TEXT
- **Default**: 'latin'
- **Options**: 'latin', 'utf8', 'windows1252'
- **Description**: Character encoding untuk text
- **Note**: Kebanyakan printer thermal Indonesia support 'latin'

## 📊 Preset Configurations

### Preset 1: Fast Kitchen (Kecepatan Maksimal)
```json
{
  "connection_timeout": 2,
  "write_timeout": 3,
  "retry_attempts": 1,
  "print_density": 40,
  "print_speed": "fast",
  "cut_mode": "partial",
  "enable_beep": 1,
  "auto_cut": 1
}
```
**Use Case**: Kitchen orders yang perlu cepat, kualitas cukup readable

### Preset 2: Quality Cashier (Kualitas Terbaik)
```json
{
  "connection_timeout": 3,
  "write_timeout": 5,
  "retry_attempts": 2,
  "print_density": 60,
  "print_speed": "normal",
  "cut_mode": "full",
  "enable_beep": 0,
  "auto_cut": 1
}
```
**Use Case**: Struk pelanggan, butuh presentasi bagus

### Preset 3: Reliable Bar (Stabil & Andal)
```json
{
  "connection_timeout": 4,
  "write_timeout": 6,
  "retry_attempts": 3,
  "print_density": 50,
  "print_speed": "normal",
  "cut_mode": "partial",
  "enable_beep": 1,
  "auto_cut": 1
}
```
**Use Case**: Bar area dengan WiFi yang kadang tidak stabil

## 🔧 API Usage

### Create Printer with Optional Settings
```bash
curl -X POST http://localhost:8080/api/v1/printers \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Kitchen Printer 1",
    "ip_address": "192.168.1.100",
    "port": 9100,
    "printer_type": "kitchen",
    "paper_size": "80mm",
    "connection_timeout": 2,
    "write_timeout": 3,
    "retry_attempts": 1,
    "print_density": 40,
    "print_speed": "fast",
    "cut_mode": "partial",
    "enable_beep": 1,
    "auto_cut": 1,
    "charset": "latin"
  }'
```

### Update Printer Settings Only
```bash
curl -X PUT http://localhost:8080/api/v1/printers/{id} \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "print_density": 70,
    "print_speed": "slow",
    "enable_beep": 0
  }'
```

## ⚡ Performance Impact

| Setting | Impact on Speed | Impact on Quality | Impact on Hardware |
|---------|----------------|-------------------|-------------------|
| connection_timeout ↓ | ++ faster | - | + less wait |
| write_timeout ↓ | ++ faster | - | + less wait |
| retry_attempts ↓ | + faster | - reliability | + less wear |
| print_density ↑ | - slower | ++ better | - more wear |
| print_speed = fast | +++ fastest | -- lower | + more wear |
| cut_mode = none | + faster | - | ++ save blade |
| enable_beep = 0 | no impact | no impact | + quieter |
| auto_cut = 0 | + faster | - | ++ save blade |

## 🎯 Best Practices

1. **Test First**: Gunakan test print untuk cek setting optimal
2. **Network Quality**: Adjust timeout based on network stability
3. **Paper Quality**: Higher density untuk kertas murah
4. **Use Case**: Sesuaikan dengan kebutuhan (speed vs quality)
5. **Monitor**: Track error rate untuk fine-tune retry attempts

## 🚨 Troubleshooting

### Print terlalu pucat
- Increase `print_density` to 70-80%
- Change `print_speed` to 'slow' atau 'normal'

### Timeout errors
- Increase `connection_timeout` dan `write_timeout`
- Increase `retry_attempts`
- Check network stability

### Printer blade cepat tumpul
- Set `cut_mode` to 'partial' atau 'none'
- Disable `auto_cut` untuk batch cutting

### Berisik di area pelanggan
- Set `enable_beep` to 0
- Consider `print_speed` = 'normal' (lebih quiet)

## 📝 Database Schema
```sql
-- Optional Performance Settings
connection_timeout INTEGER DEFAULT 3,
write_timeout INTEGER DEFAULT 5,
retry_attempts INTEGER DEFAULT 2,

-- Optional Print Quality Settings
print_density INTEGER DEFAULT 50 CHECK (print_density >= 0 AND print_density <= 100),
print_speed TEXT DEFAULT 'normal' CHECK (print_speed IN ('slow', 'normal', 'fast')),
cut_mode TEXT DEFAULT 'partial' CHECK (cut_mode IN ('full', 'partial', 'none')),

-- Optional Advanced Settings
enable_beep INTEGER DEFAULT 1,
auto_cut INTEGER DEFAULT 1,
charset TEXT DEFAULT 'latin'
```

---

**Note**: Semua setting ini opsional. Jika tidak diisi, akan menggunakan nilai default yang sudah optimal untuk kebanyakan kasus.
