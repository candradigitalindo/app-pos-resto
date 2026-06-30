# Heartbeat Perangkat — App POS → Cloud

Telemetri kondisi perangkat dikirim app POS ke cloud secara berkala untuk
pemantauan (apakah tablet hidup, baterai, penyimpanan, status printer, koneksi).

## Endpoint (perlu dibuat backend)

```
POST /api/v1/outlets/{outlet_id}/heartbeat
Headers:
  Authorization: Bearer <cloud_api_key>
  X-Outlet-ID:   <outlet_id>
  X-Outlet-Code: <outlet_code>
  Content-Type:  application/json
```

Cloud cukup **menyimpan snapshot terakhir per perangkat/outlet** (upsert) + opsional
histori. Tidak ada retry dari app (heartbeat basi tak berguna) — kirim tiap siklus sync.

## Payload

```jsonc
{
  "device": {
    "app_version": "1.2.0+82805322",
    "battery": 84,                 // 0..100 (persen)
    "battery_state": "discharging",// charging | discharging | full | unknown
    "model": "samsung SM-X115",
    "os": "Android 16 (SDK 36)",
    "storage_total_mb": 60000,
    "storage_free_mb": 12000
  },
  "printers": [
    { "name": "Dapur", "address": "192.168.1.50:9100", "ip": "192.168.1.50",
      "type": "lan", "roles": "Dapur", "connected": true, "online": true },
    { "name": "Kasir", "address": "DC:0D:30:xx:xx:xx",
      "type": "bluetooth", "roles": "Kasir", "connected": true, "online": true }
  ],
  "network": {
    "online": true,               // siklus sync terakhir tidak gagal jaringan
    "pending_sync": 3,            // jumlah item antrian sync (pending + failed)
    "last_sync_at": "2026-06-30T07:15:00.000Z"
  },
  "reported_at": "2026-06-30T07:15:05.000Z"  // UTC + Z
}
```

### Catatan field

| Field | Keterangan |
|---|---|
| `device.battery_state` | Dari battery_plus: `charging`/`discharging`/`full`/`unknown`. |
| `device.storage_*` | Penyimpanan internal (data dir) dalam MB. |
| `device.model`/`os` | Dari Android `Build.*` (MethodChannel native). |
| `printers[].ip` | **IP lokal** printer (hanya LAN). |
| `printers[].connected` | Status **terhubung/terjangkau**. **LAN**: hasil ping ke `IP:port` (akurat). **Bluetooth**: status *paired* (best-effort). `online` = alias yang sama (kompatibilitas). |
| `printers[].type` | `lan` \| `bluetooth`. |

> **Ping tidak mengganggu cetak.** Ping LAN diserialisasi dengan job cetak ke
> printer yang sama (kunci per-alamat) — bila printer sedang mencetak, ping
> menunggu sampai selesai lalu cepat. Printer thermal umumnya hanya menerima 1
> koneksi di port 9100, jadi serialisasi ini mencegah perintah order tertabrak.
| `network.online` | `true` bila siklus sync terakhir tidak gagal jaringan. |
| `network.pending_sync` | Banyaknya item yang belum tersinkron (indikasi koneksi/antrean). |
| `reported_at` | Waktu snapshot, **UTC + `Z`** (lihat kontrak zona waktu di SYNC_PAYMENTS.md). |

## Frekuensi

Dikirim di **akhir tiap siklus sync** (`CloudSyncService.syncCycle`). Bila perangkat
offline, heartbeat gagal diam-diam dan dicoba lagi pada siklus berikutnya — tidak
memengaruhi sync data.

## Sumber (app)

- `app-pos-flutter/lib/services/device_heartbeat_service.dart` — kumpulkan telemetri
- `app-pos-flutter/lib/services/cloud_sync_service.dart` → `_sendHeartbeat()` — kirim
- `app-pos-flutter/android/.../MainActivity.kt` — MethodChannel `pos/device`
  (`storage`, `deviceInfo`)
