// ============================================
// CARA MENGGUNAKAN ALERT GLOBAL
// ============================================

// 1. Import composable di component manapun
import { useNotification } from '../composables/useNotification'

// 2. Destructure methods yang dibutuhkan
const { created, updated, deleted, error, confirm, success, warning, info } = useNotification()

// ============================================
// CONTOH PENGGUNAAN
// ============================================

// CREATE - Hijau Modern
created('Produk berhasil ditambahkan')
created('Kategori baru telah dibuat')

// UPDATE - Kuning Modern
updated('Data berhasil diperbarui')
updated('Profil telah diupdate')

// DELETE - Merah Modern (dengan success feedback)
deleted('Produk berhasil dihapus')
deleted('User telah dihapus dari sistem')

// ERROR - Merah Modern
error('Kategori wajib dipilih')
error('Gagal menyimpan data')
error('Password tidak boleh kosong')

// SUCCESS - Hijau Modern
success('Login berhasil!')
success('Data tersimpan')

// WARNING - Kuning Modern
warning('Stok hampir habis')
warning('Perhatian: Data akan diubah')

// INFO - Biru Modern
info('Sistem akan maintenance')
info('Update tersedia')

// CONFIRM - Konfirmasi dengan Callback
confirm('Apakah yakin hapus produk ini?', async () => {
  // Action yang dijalankan jika user klik "Ya, Hapus"
  await api.delete('/products/123')
  deleted('Produk berhasil dihapus')
})

confirm('Logout dari sistem?', () => {
  localStorage.removeItem('token')
  router.push('/login')
})

// ============================================
// CUSTOM DURATION (Optional)
// ============================================

created('Pesan singkat', 1500) // 1.5 detik
error('Pesan error lebih lama', 4000) // 4 detik

// ============================================
// CONTOH DI BERBAGAI COMPONENT
// ============================================

// Di ProductView.vue
const saveProduct = async () => {
  try {
    await api.post('/products', productForm.value)
    created('Produk berhasil ditambahkan')
  } catch (err) {
    error('Gagal menyimpan produk')
  }
}

// Di CategoryView.vue
const deleteCategory = (category) => {
  confirm(`Hapus kategori "${category.name}"?`, async () => {
    await api.delete(`/categories/${category.id}`)
    deleted('Kategori berhasil dihapus')
  })
}

// Di LoginView.vue
const handleLogin = async () => {
  try {
    const response = await api.post('/auth/login', credentials)
    success('Login berhasil!')
    router.push('/dashboard')
  } catch (err) {
    error('Username atau password salah')
  }
}

// Di SettingsView.vue
const saveSettings = async () => {
  try {
    await api.put('/settings', settings.value)
    updated('Pengaturan berhasil diperbarui')
  } catch (err) {
    error('Gagal menyimpan pengaturan')
  }
}

// Di OrderView.vue
const cancelOrder = (order) => {
  confirm(`Batalkan pesanan #${order.id}?`, async () => {
    await api.put(`/orders/${order.id}/cancel`)
    warning('Pesanan telah dibatalkan')
  })
}

// ============================================
// KAPAN MENGGUNAKAN MASING-MASING?
// ============================================

/**
 * created() - Hijau
 * - Setelah berhasil CREATE/POST data baru
 * - Menambah produk, kategori, user, dll
 * 
 * updated() - Kuning
 * - Setelah berhasil UPDATE/PUT data existing
 * - Edit profil, ubah settings, update stock
 * 
 * deleted() - Merah
 * - Setelah berhasil DELETE data
 * - Hapus produk, kategori, user
 * 
 * error() - Merah
 * - Validasi gagal (required field kosong)
 * - API error (network error, 4xx, 5xx)
 * - Operation gagal
 * 
 * success() - Hijau
 * - General success message
 * - Login berhasil, logout berhasil
 * - Action berhasil tanpa CRUD spesifik
 * 
 * warning() - Kuning
 * - Peringatan untuk user
 * - Stok menipis, limit tercapai
 * - Tidak blocking tapi perlu perhatian
 * 
 * info() - Biru
 * - Informasi umum
 * - Update available, maintenance schedule
 * - Non-critical information
 * 
 * confirm() - Orange
 * - Konfirmasi sebelum action berbahaya
 * - Delete, logout, cancel order
 * - Action yang tidak bisa di-undo
 */
