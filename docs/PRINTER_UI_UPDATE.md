# Printer Optional Settings - UI Update

## Overview
Implemented UI support for the 9 optional printer settings added to the database. Users can now configure advanced printer settings through an intuitive form interface with preset configurations.

## Features Added

### 1. Performance Settings Section
- **Connection Timeout** (1-10 seconds)
  - Input: Number field
  - Default: 3 seconds
  - Help: "Waktu tunggu koneksi ke printer"
  
- **Write Timeout** (3-15 seconds)
  - Input: Number field
  - Default: 5 seconds
  - Help: "Waktu tunggu pengiriman data"
  
- **Retry Attempts** (0-5 times)
  - Input: Number field
  - Default: 2 attempts
  - Help: "Jumlah percobaan ulang jika gagal"

### 2. Print Quality Settings Section
- **Print Density** (0-100%)
  - Input: Range slider
  - Default: 50%
  - Help: "Ketebalan hasil cetakan"
  - Visual labels: Ringan (0%) - Sedang (50%) - Tebal (100%)
  
- **Print Speed** (slow/normal/fast)
  - Input: Select dropdown
  - Options:
    - Lambat (Kualitas Tinggi)
    - Normal (Seimbang) ✓ Default
    - Cepat (Performa Tinggi)
  
- **Cut Mode** (full/partial/none)
  - Input: Select dropdown
  - Options:
    - Full Cut (Potong Penuh)
    - Partial Cut (Potong Sebagian) ✓ Default
    - No Cut (Manual)

### 3. Advanced Settings Section
- **Enable Beep** (checkbox)
  - Default: Enabled (1)
  - Help: "Bunyi notifikasi setelah print"
  
- **Auto Cut** (checkbox)
  - Default: Enabled (1)
  - Help: "Potong kertas otomatis"
  
- **Character Set** (latin/utf8/windows1252)
  - Input: Select dropdown
  - Default: Latin
  - Help: "Encoding karakter untuk printer"

### 4. Preset Configurations
Three one-click preset buttons for common scenarios:

#### ⚡ Fast Kitchen
- Connection Timeout: 2s
- Write Timeout: 3s
- Retry Attempts: 1
- Print Density: 40%
- Print Speed: Fast
- Cut Mode: Partial
- Enable Beep: Off
- Auto Cut: On
- Charset: Latin

**Use Case:** High-volume kitchen orders where speed is critical

#### ✨ Quality Cashier
- Connection Timeout: 3s
- Write Timeout: 5s
- Retry Attempts: 2
- Print Density: 60%
- Print Speed: Normal
- Cut Mode: Full
- Enable Beep: Off
- Auto Cut: On
- Charset: UTF-8

**Use Case:** Customer receipts requiring high quality and readability

#### 🛡️ Reliable Bar
- Connection Timeout: 4s
- Write Timeout: 6s
- Retry Attempts: 3
- Print Density: 50%
- Print Speed: Normal
- Cut Mode: Partial
- Enable Beep: On
- Auto Cut: On
- Charset: Latin

**Use Case:** Noisy bar environment with network reliability concerns

## UI Design

### Layout
- Settings organized in collapsible sections with clear icons
- Visual hierarchy: Performance → Quality → Advanced
- Help text under each field for user guidance
- Responsive design works on desktop and mobile

### Styling
- **Range Slider:** Gradient background (gray → teal → green)
- **Preset Buttons:** Color-coded hover states
  - Fast Kitchen: Yellow gradient on hover
  - Quality Cashier: Purple gradient on hover
  - Reliable Bar: Green gradient on hover
- **Sections:** Light gray background with borders
- **Form Elements:** Consistent spacing and alignment

### User Experience
1. All settings are optional (have defaults)
2. Preset buttons provide instant configuration
3. Real-time form updates when preset is applied
4. Form validates on submit
5. Settings persist to database on save

## Backend Integration

### API Changes
Updated request/response structures:

```json
{
  "name": "Kitchen Printer 1",
  "ip_address": "192.168.1.100",
  "port": 9100,
  "printer_type": "kitchen",
  "paper_size": "80mm",
  "is_active": 1,
  "connection_timeout": 2,
  "write_timeout": 3,
  "retry_attempts": 1,
  "print_density": 40,
  "print_speed": "fast",
  "cut_mode": "partial",
  "enable_beep": 0,
  "auto_cut": 1,
  "charset": "latin"
}
```

### Database Schema
All optional settings stored as nullable columns with defaults:
- INTEGER fields: connection_timeout, write_timeout, retry_attempts, print_density, enable_beep, auto_cut
- TEXT fields: print_speed, cut_mode, charset

### Layer Updates
1. **Handler** (`printer_handler.go`)
   - Added optional fields to CreatePrinterRequest and UpdatePrinterRequest
   - Built PrinterOptionalSettings struct from request

2. **Service** (`printer_service.go`)
   - Updated method signatures to accept optional settings
   - Passes settings through to repository

3. **Repository** (`printer_repository_impl.go`)
   - Converts Go types to sql.Null* types
   - Applies optional settings to sqlc params

4. **SQL Queries** (`printers.sql`)
   - CreatePrinter: INSERT with 9 optional columns
   - UpdatePrinter: UPDATE with 9 optional columns

5. **SQLC Generated Code**
   - Printer model includes all optional fields as sql.Null* types
   - CreatePrinterParams and UpdatePrinterParams support all fields

## Testing Checklist

- [x] Backend compiles without errors
- [x] SQLC generates correct models
- [x] Frontend runs on http://192.168.0.102:5173
- [ ] Create printer with optional settings
- [ ] Update printer optional settings
- [ ] Apply Fast Kitchen preset
- [ ] Apply Quality Cashier preset
- [ ] Apply Reliable Bar preset
- [ ] Verify database stores values correctly
- [ ] Test with actual printer (if available)
- [ ] Test form validation
- [ ] Test responsive layout on mobile

## Files Modified

### Backend
1. `sql/queries/printers.sql` - Updated CREATE and UPDATE queries
2. `internal/db/models.go` - Auto-generated with optional fields
3. `internal/db/printers.sql.go` - Auto-generated SQLC code
4. `internal/repositories/printer_repository.go` - Added PrinterOptionalSettings struct
5. `internal/repositories/printer_repository_impl.go` - Implemented optional settings handling
6. `internal/services/printer_service.go` - Updated method signatures
7. `internal/handlers/printer_handler.go` - Added optional fields to requests

### Frontend
1. `web/src/components/PrinterManagement.vue`
   - Added 9 form fields for optional settings
   - Added 3 preset buttons with applyPreset() function
   - Updated form data initialization
   - Updated savePrinter() payload
   - Updated editPrinter() to load optional settings
   - Updated closeModal() to reset optional fields
   - Added CSS for settings sections and preset buttons

### Documentation
1. `docs/PRINTER_OPTIONAL_SETTINGS.md` - Comprehensive guide
2. `docs/PRINTER_UI_UPDATE.md` - This file

## Performance Impact

The optional settings are designed for fine-tuning printer performance:

| Setting | Impact on Speed | Impact on Quality | Impact on Reliability |
|---------|----------------|-------------------|---------------------|
| Connection Timeout ↓ | ⬆️ Faster | ➖ Neutral | ⬇️ Lower |
| Write Timeout ↓ | ⬆️ Faster | ➖ Neutral | ⬇️ Lower |
| Retry Attempts ↓ | ⬆️ Faster | ➖ Neutral | ⬇️ Lower |
| Print Density ↓ | ⬆️ Faster | ⬇️ Lower | ➖ Neutral |
| Print Speed = Fast | ⬆️ Fastest | ⬇️ Lower | ➖ Neutral |
| Cut Mode = Partial | ⬆️ Faster | ➖ Neutral | ➖ Neutral |

## Next Steps

1. Test all features with actual thermal printers
2. Gather user feedback on preset configurations
3. Consider adding custom preset saving feature
4. Add printer setting validation on frontend
5. Add setting explanation tooltips/modals
6. Consider A/B testing different default values

## Migration Notes

Existing printers in database:
- Will have NULL for all optional fields
- Database defaults will apply when NULL
- No migration needed for existing data
- New printers get defaults from UI (connection_timeout=3, etc.)

## Support

For issues or questions:
1. Check `docs/PRINTER_OPTIONAL_SETTINGS.md` for detailed setting explanations
2. Review database schema in `sql/schema/schema.sql`
3. Check console for API errors
4. Verify printer network connectivity before changing settings
