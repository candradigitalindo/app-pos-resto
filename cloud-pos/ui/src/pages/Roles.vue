<template>
  <div class="space-y-6">
    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
      <div>
        <h1 class="text-2xl font-bold text-gray-900">Role & Hak Akses</h1>
        <p class="text-sm text-gray-500 mt-1">Kelola role dan atur wewenang setiap pengguna di sistem.</p>
      </div>
      <AppButton @click="showCreate = true" class="shrink-0 flex items-center gap-2">
        <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M10 3a1 1 0 011 1v5h5a1 1 0 110 2h-5v5a1 1 0 11-2 0v-5H4a1 1 0 110-2h5V4a1 1 0 011-1z" clip-rule="evenodd" /></svg>
        Tambah Role
      </AppButton>
    </div>

    <AppAlert type="error" :message="errorMsg" />

    <!-- Roles List -->
    <div v-if="loading" class="py-12 flex justify-center">
      <AppSpinner size="lg" class="text-blue-600" />
    </div>
    
    <div v-else class="grid gap-4">
      <div 
        v-for="role in roles" 
        :key="role.name" 
        class="bg-white rounded-xl shadow-sm border overflow-hidden transition-all duration-200 hover:shadow-md"
        :class="expandedRole === role.name ? 'ring-2 ring-blue-500/20 border-blue-300' : 'border-gray-200'"
      >
        <!-- Card Header / Summary -->
        <div 
          class="p-5 flex flex-col sm:flex-row sm:items-center justify-between gap-4 cursor-pointer bg-white hover:bg-gray-50/80 transition-colors"
          @click="expandedRole = expandedRole === role.name ? '' : role.name"
        >
          <div class="flex items-start gap-4">
            <div 
              class="w-12 h-12 rounded-xl flex items-center justify-center text-white font-bold text-xl shadow-inner flex-shrink-0"
              :class="role.is_system ? 'bg-gradient-to-br from-gray-600 to-gray-800' : 'bg-gradient-to-br from-blue-500 to-blue-700'"
            >
              {{ role.name.charAt(0).toUpperCase() }}
            </div>
            <div>
              <div class="flex items-center gap-2 mb-1">
                <h2 class="text-lg font-bold text-gray-900 capitalize">{{ role.name }}</h2>
                <AppBadge v-if="role.is_system" variant="secondary" class="bg-gray-100 text-gray-700 border-gray-200">Sistem</AppBadge>
              </div>
              <p class="text-sm text-gray-500 mb-2.5 line-clamp-1">{{ role.description || 'Tidak ada deskripsi' }}</p>
              
              <div class="flex flex-wrap items-center gap-2">
                <span class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-md text-xs font-medium border transition-colors" 
                      :class="(roleScopes[role.name]?.scope_type ?? role.scope_type) === 'all' ? 'bg-indigo-50 text-indigo-700 border-indigo-200' : 'bg-sky-50 text-sky-700 border-sky-200'">
                  <svg xmlns="http://www.w3.org/2000/svg" class="h-3.5 w-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" /></svg>
                  {{ (roleScopes[role.name]?.scope_type ?? role.scope_type) === 'all' ? 'Semua Unit Kerja' : 'Unit Kerja Tertentu' }}
                </span>
                <span class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-md text-xs font-medium border transition-colors"
                      :class="role.is_system ? 'bg-gray-50 text-gray-600 border-gray-200' : 'bg-emerald-50 text-emerald-700 border-emerald-200'">
                  <svg xmlns="http://www.w3.org/2000/svg" class="h-3.5 w-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 7a2 2 0 012 2m4 0a6 6 0 01-7.743 5.743L11 17H9v2H7v2H4a1 1 0 01-1-1v-2.586a1 1 0 01.293-.707l5.964-5.964A6 6 0 1121 9z" /></svg>
                  <template v-if="role.is_system">Akses Penuh</template>
                  <template v-else>{{ countPerms(role.name) }} dari {{ allPermissions.length }} Akses</template>
                </span>
                <span class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-md text-xs font-medium border bg-amber-50 text-amber-700 border-amber-200 transition-colors">
                  <svg xmlns="http://www.w3.org/2000/svg" class="h-3.5 w-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 9l3 3m0 0l-3 3m3-3H8m13 0a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
                  Login → {{ getRedirectLabel(role.redirect_to) }}
                </span>
              </div>
            </div>
          </div>

          <div class="flex items-center justify-end sm:justify-start gap-2 self-end sm:self-center shrink-0 w-full sm:w-auto mt-2 sm:mt-0">
            <button 
              @click.stop="openEditRole(role)" 
              class="p-2 text-blue-400 hover:text-blue-600 hover:bg-blue-50 rounded-lg transition-colors"
              title="Edit Role"
            >
              <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" /></svg>
            </button>
            <button 
              @click.stop="!role.is_system && confirmDelete(role)" 
              class="p-2 rounded-lg transition-colors"
              :class="role.is_system ? 'text-gray-300 cursor-not-allowed' : 'text-red-400 hover:text-red-600 hover:bg-red-50'"
              :title="role.is_system ? 'Role sistem tidak dapat dihapus' : 'Hapus Role'"
            >
              <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" /></svg>
            </button>
            <button 
              class="flex items-center gap-1.5 px-3 py-2 text-sm font-medium rounded-lg transition-colors"
              :class="expandedRole === role.name ? 'text-blue-700 bg-blue-50' : 'text-gray-600 hover:bg-gray-100'"
            >
               {{ expandedRole === role.name ? 'Tutup Pengaturan' : 'Kelola Akses' }}
               <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 transform transition-transform duration-200" :class="{'rotate-180': expandedRole === role.name}" viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M5.293 7.293a1 1 0 011.414 0L10 10.586l3.293-3.293a1 1 0 111.414 1.414l-4 4a1 1 0 01-1.414 0l-4-4a1 1 0 010-1.414z" clip-rule="evenodd" /></svg>
            </button>
          </div>
        </div>

        <!-- Detail / Expanded Rules -->
        <div v-show="expandedRole === role.name" class="border-t border-gray-200 bg-gray-50/50 p-5 sm:p-6 shadow-inner">
          
          <div v-if="role.is_system" class="mb-6 p-4 bg-gray-100/80 border border-gray-200 rounded-xl flex items-start gap-3">
             <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-gray-500 mt-0.5" viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd" /></svg>
             <div>
               <h3 class="text-sm font-bold text-gray-800">Role Sistem (Read-only)</h3>
               <p class="text-sm text-gray-600 mt-1">Role <strong>"{{role.name}}"</strong> memberikan akses penuh ke semua fitur dan unit kerja secara bawaan. Pengaturan hak akses untuk role sistem tidak dapat diubah.</p>
             </div>
          </div>

          <div class="grid grid-cols-1 lg:grid-cols-3 gap-6" :class="{'opacity-60 pointer-events-none select-none grayscale': role.is_system, 'pointer-events-none opacity-50': savingRole === role.name}">
            
            <!-- Scope Section -->
            <div class="lg:col-span-1 space-y-4">
              <div>
                <h3 class="text-sm font-bold text-gray-900 flex items-center gap-2">
                  <span class="text-base">🏢</span> Batasan Unit Kerja
                </h3>
                <p class="text-xs text-gray-500 mt-1">Tentukan unit kerja mana yang dapat diakses oleh role ini ketika melihat data transaksi atau stok.</p>
              </div>
              
              <div class="bg-white rounded-xl border border-gray-200 p-4 shadow-sm">
                <div class="space-y-3">
                  <label class="flex items-start gap-3 cursor-pointer group">
                    <div class="pt-0.5">
                      <input 
                        type="radio" 
                        :name="'scope_'+role.name" 
                        value="all" 
                        :checked="(roleScopes[role.name]?.scope_type ?? role.scope_type) === 'all'" 
                        @change="updateScope(role.name, 'all', [])"
                        class="h-4 w-4 border-gray-300 text-blue-600 focus:ring-blue-500"
                      />
                    </div>
                    <div>
                      <span class="block text-sm font-medium text-gray-900 group-hover:text-blue-600 transition-colors">Semua Unit Kerja</span>
                      <span class="block text-xs text-gray-500 mt-0.5">Role ini bisa mengakses data dari seluruh outlet dan unit kerja.</span>
                    </div>
                  </label>
                  
                  <div class="h-px bg-gray-100"></div>

                  <label class="flex items-start gap-3 cursor-pointer group">
                    <div class="pt-0.5">
                      <input 
                        type="radio" 
                        :name="'scope_'+role.name" 
                        value="specific" 
                        :checked="(roleScopes[role.name]?.scope_type ?? role.scope_type) === 'specific'" 
                        @change="showScopeModal(role.name)"
                        class="h-4 w-4 border-gray-300 text-blue-600 focus:ring-blue-500"
                      />
                    </div>
                    <div>
                      <span class="block text-sm font-medium text-gray-900 group-hover:text-blue-600 transition-colors">Unit Kerja Tertentu</span>
                      <span class="block text-xs text-gray-500 mt-0.5">Role ini hanya bisa mengakses unit kerja yang dipilih saja.</span>
                    </div>
                  </label>

                  <!-- Selected units preview -->
                  <div v-if="(roleScopes[role.name]?.scope_type ?? role.scope_type) === 'specific'" class="mt-3 pl-7">
                    <div class="bg-indigo-50/50 rounded-lg p-3 border border-indigo-100/50">
                      <div class="flex flex-wrap gap-1.5">
                        <span 
                          v-for="wuId in (roleScopes[role.name]?.work_unit_ids ?? [])" 
                          :key="wuId" 
                          class="inline-flex items-center rounded-md bg-white border border-gray-200 px-2 py-1 text-xs font-medium text-gray-700 shadow-sm"
                        >{{ getWorkUnitName(wuId) }}</span>
                        <span v-if="!(roleScopes[role.name]?.work_unit_ids?.length)" class="text-xs text-gray-400 italic">Klik untuk memilih unit kerja</span>
                      </div>
                      <button 
                        @click="showScopeModal(role.name)"
                        :disabled="savingScope === role.name"
                        class="mt-2.5 text-xs text-blue-600 hover:text-blue-800 font-bold flex items-center gap-1 disabled:opacity-50"
                      >
                        <svg xmlns="http://www.w3.org/2000/svg" class="h-3 w-3" viewBox="0 0 20 20" fill="currentColor"><path d="M13.586 3.586a2 2 0 112.828 2.828l-.793.793-2.828-2.828.793-.793zM11.379 5.793L3 14.172V17h2.828l8.38-8.379-2.83-2.828z" /></svg>
                        Ubah Pilihan
                      </button>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            <!-- Permissions Section -->
            <div class="lg:col-span-2 space-y-4">
              <div>
                <div class="flex items-center justify-between">
                  <h3 class="text-sm font-bold text-gray-900 flex items-center gap-2">
                    <span class="text-base">🔐</span> Hak Akses Menu & Fitur
                  </h3>
                  <span v-if="savingRole === role.name" class="text-xs text-blue-600 font-medium animate-pulse">Menyimpan...</span>
                </div>
                <p class="text-xs text-gray-500 mt-1">Centang kotak untuk memberikan izin akses secara otomatis tanpa perlu tombol simpan.</p>
              </div>

              <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div 
                  v-for="group in PERM_GROUPS" 
                  :key="group.label" 
                  class="bg-white rounded-xl border p-4 shadow-sm transition-all duration-200"
                  :class="groupActive(group, role.name) ? 'border-emerald-300 ring-1 ring-emerald-50 bg-emerald-50/10' : 'border-gray-200 hover:border-gray-300'"
                >
                  <div class="flex items-center gap-2 mb-3 pb-2 border-b border-gray-100">
                    <span class="text-lg" v-html="group.icon"></span>
                    <span class="text-sm font-bold text-gray-800">{{ group.label }}</span>
                  </div>

                  <!-- Single permission -->
                  <template v-if="group.single">
                    <label class="flex items-start gap-2.5 cursor-pointer group/item">
                      <div class="pt-0.5">
                        <input type="checkbox" :checked="roleHas(role.name, group.key)" @change="togglePermission(role.name, group.key)" class="h-4 w-4 rounded border-gray-300 text-emerald-600 focus:ring-emerald-500 transition-colors" />
                      </div>
                      <div>
                        <span class="block text-sm font-medium text-gray-700 group-hover/item:text-emerald-700 transition-colors">Akses Menu</span>
                        <span class="block text-xs text-gray-500 leading-relaxed mt-0.5">{{ group.desc }}</span>
                      </div>
                    </label>
                  </template>

                  <!-- Dual permission -->
                  <template v-else-if="!group.multi">
                    <div class="space-y-3">
                      <label class="flex items-start gap-2.5 cursor-pointer group/item">
                        <div class="pt-0.5">
                          <input type="checkbox" :checked="roleHas(role.name, group.module+'.view')" @change="togglePermission(role.name, group.module+'.view')" class="h-4 w-4 rounded border-gray-300 text-emerald-600 focus:ring-emerald-500 transition-colors" />
                        </div>
                        <div>
                          <span class="block text-sm font-medium text-gray-700 group-hover/item:text-emerald-700 transition-colors">Lihat Data (View)</span>
                          <span class="block text-xs text-gray-500 leading-relaxed mt-0.5">{{ group.viewDesc }}</span>
                        </div>
                      </label>
                      <label class="flex items-start gap-2.5 cursor-pointer group/item">
                        <div class="pt-0.5">
                          <input type="checkbox" :checked="roleHas(role.name, group.module+'.manage')" @change="togglePermission(role.name, group.module+'.manage')" class="h-4 w-4 rounded border-gray-300 text-emerald-600 focus:ring-emerald-500 transition-colors" />
                        </div>
                        <div>
                          <span class="block text-sm font-medium text-gray-700 group-hover/item:text-emerald-700 transition-colors">Kelola (Ubah / Hapus)</span>
                          <span class="block text-xs text-gray-500 leading-relaxed mt-0.5">{{ group.manageDesc }}</span>
                        </div>
                      </label>
                    </div>
                  </template>

                  <!-- Multi permission -->
                  <template v-else>
                    <div class="space-y-3">
                      <label v-for="p in group.perms" :key="p.key" class="flex items-start gap-2.5 cursor-pointer group/item">
                        <div class="pt-0.5">
                          <input type="checkbox" :checked="roleHas(role.name, p.key)" @change="togglePermission(role.name, p.key)" class="h-4 w-4 rounded border-gray-300 text-emerald-600 focus:ring-emerald-500 transition-colors" />
                        </div>
                        <div>
                          <span class="block text-sm font-medium text-gray-700 group-hover/item:text-emerald-700 transition-colors">{{ p.label }}</span>
                          <span class="block text-xs text-gray-500 leading-relaxed mt-0.5">{{ p.desc }}</span>
                        </div>
                      </label>
                    </div>
                  </template>
                </div>
              </div>
            </div>
            
          </div>
        </div>
      </div>

      <div v-if="roles.length === 0" class="bg-gray-50 border border-dashed border-gray-300 rounded-xl p-12 text-center">
         <div class="text-5xl mb-4 opacity-70">👥</div>
         <h3 class="text-base font-bold text-gray-900 mb-1">Belum ada role</h3>
         <p class="text-sm text-gray-500">Klik "Tambah Role" untuk membuat peran baru.</p>
      </div>
    </div>

    <!-- Create Role Modal -->
    <AppModal v-model="showCreate" title="Tambah Role Baru" size="2xl">
      <form class="space-y-6" @submit.prevent="createRole">
        <AppAlert type="error" :message="createError" />
        
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <AppInput v-model="form.name" label="Nama Role" placeholder="contoh: kasir" :error="formErrors.name" />
          <AppInput v-model="form.description" label="Deskripsi (opsional)" placeholder="Deskripsi singkat role" />
        </div>

        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Halaman Setelah Login</label>
          <select v-model="form.redirect_to" class="block w-full rounded-lg border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 text-sm py-2 px-3 border">
            <option v-for="opt in REDIRECT_OPTIONS" :key="opt.value" :value="opt.value">{{ opt.label }}</option>
          </select>
          <p class="text-xs text-gray-400 mt-1">Halaman tujuan saat pengguna dengan role ini berhasil login.</p>
        </div>

        <div class="border-t border-gray-100 pt-4">
          <h3 class="text-sm font-bold text-gray-900 mb-3 flex items-center gap-2">
            <span class="text-base">🏢</span> Scope Unit Kerja
          </h3>
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div class="space-y-2">
              <label class="flex items-start gap-3 cursor-pointer group bg-white border border-gray-200 rounded-lg p-3 hover:border-blue-300 transition-colors" :class="{'ring-1 ring-blue-500 border-blue-500 bg-blue-50/20': form.scope_type === 'all'}">
                <div class="pt-0.5">
                  <input type="radio" name="create_scope" value="all" v-model="form.scope_type" class="h-4 w-4 border-gray-300 text-blue-600 focus:ring-blue-500" />
                </div>
                <div>
                  <span class="block text-sm font-medium text-gray-900">Keseluruhan</span>
                  <span class="block text-xs text-gray-500 mt-0.5">Akses semua unit kerja di berbagai outlet.</span>
                </div>
              </label>
              <label class="flex items-start gap-3 cursor-pointer group bg-white border border-gray-200 rounded-lg p-3 hover:border-blue-300 transition-colors" :class="{'ring-1 ring-blue-500 border-blue-500 bg-blue-50/20': form.scope_type === 'specific'}">
                <div class="pt-0.5">
                  <input type="radio" name="create_scope" value="specific" v-model="form.scope_type" class="h-4 w-4 border-gray-300 text-blue-600 focus:ring-blue-500" />
                </div>
                <div>
                  <span class="block text-sm font-medium text-gray-900">Unit Kerja Tertentu</span>
                  <span class="block text-xs text-gray-500 mt-0.5">Pilih unit kerja spesifik di bawah ini.</span>
                </div>
              </label>
            </div>
            <div>
              <div v-if="form.scope_type === 'specific'" class="h-32 overflow-y-auto border border-gray-200 rounded-lg p-2 space-y-1 bg-gray-50 shadow-inner">
                <label v-for="wu in workUnits" :key="wu.id" class="flex items-center gap-2 cursor-pointer select-none p-2 rounded-md hover:bg-white hover:shadow-sm border border-transparent transition-colors">
                  <input
                    type="checkbox"
                    :checked="form.work_unit_ids.includes(wu.id)"
                    @change="toggleFormWorkUnit(wu.id)"
                    class="h-4 w-4 rounded border-gray-300 text-blue-600 focus:ring-blue-500"
                  />
                  <div>
                    <span class="text-sm font-medium text-gray-700 block">{{ wu.name }}</span>
                    <span v-if="wu.outlet_name" class="text-xs text-gray-500 block">{{ wu.outlet_name }}</span>
                  </div>
                </label>
                <p v-if="workUnits.length === 0" class="text-xs text-gray-400 text-center py-4">Belum ada unit kerja.</p>
              </div>
              <div v-else class="h-32 rounded-lg border border-gray-200 border-dashed flex items-center justify-center bg-gray-50 text-gray-400 text-sm">
                (Akses Semua Unit)
              </div>
            </div>
          </div>
        </div>

        <div class="border-t border-gray-100 pt-4">
          <h3 class="text-sm font-bold text-gray-900 mb-3 flex items-center gap-2">
            <span class="text-base">🔐</span> Hak Akses
          </h3>
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div
              v-for="group in PERM_GROUPS"
              :key="group.label"
              class="rounded-lg border p-3 border-gray-200 bg-white"
            >
              <div class="flex items-center gap-2 mb-2 pb-2 border-b border-gray-100">
                <span class="text-lg" v-html="group.icon"></span>
                <span class="text-sm font-bold text-gray-800">{{ group.label }}</span>
              </div>

              <!-- Single permission -->
              <template v-if="group.single">
                <label class="flex items-start gap-2 cursor-pointer group/item">
                  <input type="checkbox" :checked="form.permissions.includes(group.key)" @change="toggleFormPermission(group.key)" class="mt-0.5 h-4 w-4 rounded border-gray-300 text-emerald-600 focus:ring-emerald-500" />
                  <p class="text-xs text-gray-600">{{ group.desc }}</p>
                </label>
              </template>

              <!-- Dual permission -->
              <template v-else-if="!group.multi">
                <div class="space-y-2">
                  <label class="flex items-start gap-2 cursor-pointer group/item">
                    <input type="checkbox" :checked="form.permissions.includes(group.module+'.view')" @change="toggleFormPermission(group.module+'.view')" class="mt-0.5 h-4 w-4 rounded border-gray-300 text-emerald-600 focus:ring-emerald-500" />
                    <div class="flex-1 min-w-0">
                      <span class="text-xs font-bold text-gray-700">Lihat (View)</span>
                    </div>
                  </label>
                  <label class="flex items-start gap-2 cursor-pointer group/item">
                    <input type="checkbox" :checked="form.permissions.includes(group.module+'.manage')" @change="toggleFormPermission(group.module+'.manage')" class="mt-0.5 h-4 w-4 rounded border-gray-300 text-emerald-600 focus:ring-emerald-500" />
                    <div class="flex-1 min-w-0">
                      <span class="text-xs font-bold text-gray-700">Kelola (Manage)</span>
                    </div>
                  </label>
                </div>
              </template>

              <!-- Multi permission -->
              <template v-else>
                <div class="space-y-2">
                  <label v-for="p in group.perms" :key="p.key" class="flex items-start gap-2 cursor-pointer group/item">
                    <input type="checkbox" :checked="form.permissions.includes(p.key)" @change="toggleFormPermission(p.key)" class="mt-0.5 h-4 w-4 rounded border-gray-300 text-emerald-600 focus:ring-emerald-500" />
                    <div class="flex-1 min-w-0">
                      <span class="text-xs font-bold text-gray-700">{{ p.label }}</span>
                    </div>
                  </label>
                </div>
              </template>
            </div>
          </div>
        </div>
      </form>
      <template #footer>
        <AppButton variant="secondary" @click="showCreate = false">Batal</AppButton>
        <AppButton :loading="creating" @click="createRole" class="min-w-[100px]">Buat Role</AppButton>
      </template>
    </AppModal>

    <!-- Edit Role Modal -->
    <AppModal v-model="showEdit" title="Edit Role" size="md">
      <form class="space-y-4" @submit.prevent="submitEditRole">
        <AppAlert type="error" :message="editError" />
        <AppInput v-model="editForm.name" label="Nama Role" placeholder="contoh: kasir" :error="editFormErrors.name" :disabled="editForm.isSystem" />
        <p v-if="editForm.isSystem" class="-mt-2 text-xs text-gray-400">Nama role sistem tidak dapat diubah.</p>
        <AppInput v-model="editForm.description" label="Deskripsi" placeholder="Deskripsi singkat role" />
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Halaman Setelah Login</label>
          <select v-model="editForm.redirect_to" class="block w-full rounded-lg border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 text-sm py-2 px-3 border">
            <option v-for="opt in REDIRECT_OPTIONS" :key="opt.value" :value="opt.value">{{ opt.label }}</option>
          </select>
          <p class="text-xs text-gray-400 mt-1">Halaman tujuan saat pengguna dengan role ini berhasil login.</p>
        </div>
      </form>
      <template #footer>
        <AppButton variant="secondary" @click="showEdit = false">Batal</AppButton>
        <AppButton :loading="editing" @click="submitEditRole" class="min-w-[100px]">Simpan</AppButton>
      </template>
    </AppModal>

    <!-- Delete Confirm Modal -->
    <AppModal v-model="showDeleteConfirm" title="Hapus Role" size="sm">
      <div class="flex flex-col items-center text-center pb-2">
        <div class="w-12 h-12 bg-red-100 text-red-600 rounded-full flex items-center justify-center mb-4">
          <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" /></svg>
        </div>
        <p class="text-sm text-gray-600">
          Yakin ingin menghapus role <strong class="capitalize text-gray-900 border-b border-dashed border-gray-400">{{ deleteTarget?.name }}</strong>?<br/>
          Semua hak akses untuk role ini akan hilang.
        </p>
      </div>
      <template #footer>
        <AppButton variant="secondary" @click="showDeleteConfirm = false">Batal</AppButton>
        <AppButton variant="danger" :loading="deletingRole === deleteTarget?.name" @click="doDelete">Hapus Permanen</AppButton>
      </template>
    </AppModal>

    <!-- Scope Edit Modal -->
    <AppModal v-model="showScopeEdit" title="Ubah Unit Kerja Akses" size="md">
      <p class="text-sm text-gray-600 mb-4">
        Pilih <strong>Unit Kerja</strong> yang dapat diakses oleh pengguna dengan role <strong class="capitalize text-gray-900">{{ scopeEditRole }}</strong>:
      </p>
      <div class="max-h-72 overflow-y-auto border border-gray-200 rounded-xl p-2 space-y-1 bg-gray-50 shadow-inner">
        <label v-for="wu in workUnits" :key="wu.id" class="flex items-center gap-3 cursor-pointer select-none p-2.5 rounded-lg hover:bg-white hover:shadow-sm border border-transparent transition-all">
          <input
            type="checkbox"
            :checked="scopeEditIDs.includes(wu.id)"
            @change="toggleScopeEditWU(wu.id)"
            class="h-4 w-4 rounded border-gray-300 text-blue-600 focus:ring-blue-500"
          />
          <div>
            <span class="text-sm font-semibold text-gray-800 block">{{ wu.name }}</span>
            <span v-if="wu.outlet_name" class="text-xs text-gray-500 block">{{ wu.outlet_name }}</span>
          </div>
        </label>
        <div v-if="workUnits.length === 0" class="text-center py-8 text-gray-400 text-sm">
          <svg xmlns="http://www.w3.org/2000/svg" class="h-8 w-8 mx-auto mb-2 opacity-50" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" /></svg>
          Belum ada unit kerja yang tersedia.
        </div>
      </div>
      <template #footer>
        <AppButton variant="secondary" @click="showScopeEdit = false">Batal</AppButton>
        <AppButton :loading="savingScope === scopeEditRole" @click="saveScopeEdit">Simpan Perubahan</AppButton>
      </template>
    </AppModal>
  </div>
</template>

<script setup>
import { ref, reactive, watch } from 'vue'
import { adminsApi } from '@/api/admins.js'
import { workUnitsApi } from '@/api/workUnits.js'
import { useToastStore } from '@/stores/toast.js'
import { useAuthStore } from '@/stores/auth.js'
import AppButton  from '@/components/ui/AppButton.vue'
import AppModal   from '@/components/ui/AppModal.vue'
import AppInput   from '@/components/ui/AppInput.vue'
import AppAlert   from '@/components/ui/AppAlert.vue'
import AppBadge   from '@/components/ui/AppBadge.vue'
import AppSpinner from '@/components/ui/AppSpinner.vue'

const toast = useToastStore()
const authStore = useAuthStore()

// Redirect route options for roles
const REDIRECT_OPTIONS = [
  { value: '/', label: 'Dashboard' },
  { value: '/manager-dashboard', label: 'Manager Dashboard' },
  { value: '/outlets', label: 'Outlets' },
  { value: '/products', label: 'Produk & Kategori' },
  { value: '/sales-report', label: 'Laporan Pendapatan' },
  { value: '/product-sales-report', label: 'Penjualan Produk' },
  { value: '/cash-flow-report', label: 'Pemasukan & Pengeluaran' },
  { value: '/balance-report', label: 'Laporan Neraca' },
  { value: '/profit-loss-report', label: 'Profit & Loss' },
  { value: '/general-ledger', label: 'Buku Besar' },
  { value: '/tax-report', label: 'Laporan Pajak' },
  { value: '/procurement-dashboard', label: 'Dashboard Pengadaan' },
  { value: '/purchase-goods', label: 'Pengadaan Barang' },
  { value: '/purchase-services', label: 'Pengadaan Jasa' },
  { value: '/work-units', label: 'Unit Kerja' },
  { value: '/admins', label: 'Admin' },
  { value: '/roles', label: 'Role' },
  { value: '/settings/company', label: 'Identitas Perusahaan' },
  { value: '/settings/timezone', label: 'Zona Waktu' },
  { value: '/settings/tax', label: 'Pengaturan Pajak' },
]

const PERM_GROUPS = [
  {
    label: 'Dashboard', icon: '📊', multi: true, module: 'dashboard',
    perms: [
      { key: 'dashboard', label: 'Dashboard Utama', desc: 'Lihat ringkasan data, statistik penjualan, dan grafik performa.' },
      { key: 'dashboard.manager', label: 'Manager Dashboard', desc: 'Akses dashboard manager dengan KPI, grafik, dan ranking outlet.' },
    ],
  },
  {
    label: 'Outlet', icon: '🏪', module: 'outlets',
    viewDesc: 'Lihat daftar outlet, detail, transaksi, pesanan, produk, printer, dan sync log.',
    manageDesc: 'Tambah, edit, hapus outlet, regenerasi API key, toggle aktif/nonaktif.',
  },
  {
    label: 'Produk', icon: '📦', module: 'products',
    viewDesc: 'Lihat master produk dan kategori yang berlaku untuk semua outlet.',
    manageDesc: 'Tambah, edit, dan hapus produk serta kategori.',
  },
  {
    label: 'Laporan', icon: '📈', single: true, key: 'reports',
    desc: 'Akses laporan pendapatan, penjualan produk, pajak, arus kas, neraca, dan laba rugi.',
  },
  {
    label: 'Pengadaan', icon: '🛒', multi: true, module: 'procurement',
    perms: [
      { key: 'procurement.view', label: 'Lihat', desc: 'Lihat daftar pengajuan barang & jasa, dan unit kerja.' },
      { key: 'procurement.submit', label: 'Pengaju', desc: 'Buat pengajuan, serah terima, batalkan.' },
      { key: 'procurement.approve', label: 'Approval', desc: 'Setujui / tolak pengajuan, kelola unit kerja.' },
      { key: 'procurement.purchasing', label: 'Purchasing', desc: 'Isi harga pengajuan (tanpa melihat HPS).' },
      { key: 'procurement.finance', label: 'Finance', desc: 'Bayar pengajuan yang sudah ada harga.' },
      { key: 'procurement.work_units', label: 'Unit Kerja', desc: 'Lihat, tambah, dan edit unit kerja.' },
      { key: 'procurement.vendors', label: 'Vendor', desc: 'Lihat, tambah, edit, dan kelola data vendor.' },
    ],
  },
  {
    label: 'Pengguna & Role', icon: '👥', module: 'users',
    viewDesc: 'Lihat daftar admin dan role beserta hak aksesnya.',
    manageDesc: 'Tambah admin, ubah role, kelola hak akses, buat & hapus role.',
  },
  {
    label: 'Pengaturan', icon: '⚙️', module: 'settings',
    viewDesc: 'Lihat identitas perusahaan dan pengaturan zona waktu.',
    manageDesc: 'Ubah identitas perusahaan dan pengaturan zona waktu.',
  },
]

const roles           = ref([])
const rolePermissions = ref({})
const roleScopes      = ref({})
const allPermissions  = ref([])
const workUnits       = ref([])
const loading         = ref(false)
const errorMsg        = ref('')
const savingRole      = ref('')
const savingScope     = ref('')
const expandedRole    = ref('')

const showCreate  = ref(false)
const creating    = ref(false)
const createError = ref('')
const form        = reactive({ name: '', description: '', permissions: [], scope_type: 'all', work_unit_ids: [], redirect_to: '/' })
const formErrors  = reactive({ name: '' })

const showEdit       = ref(false)
const editing        = ref(false)
const editError      = ref('')
const editForm       = reactive({ name: '', description: '', originalName: '', isSystem: false, redirect_to: '/' })
const editFormErrors = reactive({ name: '' })

const showDeleteConfirm = ref(false)
const deleteTarget      = ref(null)
const deletingRole      = ref('')

// Scope edit modal state
const showScopeEdit  = ref(false)
const scopeEditRole  = ref('')
const scopeEditIDs   = ref([])

/** Get work unit name by ID */
function getWorkUnitName(id) {
  const wu = workUnits.value.find(w => w.id === id)
  return wu ? wu.name : id
}

/** Get redirect label for display */
function getRedirectLabel(path) {
  const opt = REDIRECT_OPTIONS.find(o => o.value === path)
  return opt ? opt.label : (path || 'Dashboard')
}

/** Toggle work unit in scope edit modal */
function toggleScopeEditWU(id) {
  const idx = scopeEditIDs.value.indexOf(id)
  if (idx >= 0) scopeEditIDs.value.splice(idx, 1)
  else scopeEditIDs.value.push(id)
}

/** Toggle work unit in create form */
function toggleFormWorkUnit(id) {
  const idx = form.work_unit_ids.indexOf(id)
  if (idx >= 0) form.work_unit_ids.splice(idx, 1)
  else form.work_unit_ids.push(id)
}

/** Show scope edit modal for a role */
function showScopeModal(roleName) {
  scopeEditRole.value = roleName
  scopeEditIDs.value = [...(roleScopes.value[roleName]?.work_unit_ids ?? [])]
  showScopeEdit.value = true
}

/** Update scope to "all" or open modal for "specific" */
async function updateScope(roleName, type, wuIDs) {
  savingScope.value = roleName
  try {
    await adminsApi.updateRoleScope(roleName, { scope_type: type, work_unit_ids: wuIDs })
    roleScopes.value = { ...roleScopes.value, [roleName]: { scope_type: type, work_unit_ids: wuIDs } }
    toast.success(`Scope ${roleName} diperbarui`)
    if (roleName === authStore.admin?.role) {
      await authStore.fetchPermissions()
    }
  } catch (err) {
    toast.error(err?.message ?? 'Gagal memperbarui scope')
  } finally {
    savingScope.value = ''
  }
}

/** Save scope from edit modal */
async function saveScopeEdit() {
  await updateScope(scopeEditRole.value, 'specific', scopeEditIDs.value)
  showScopeEdit.value = false
}

function countPerms(roleName) {
  return (rolePermissions.value[roleName] ?? []).length
}

/** Helper: does role have a specific permission key */
function roleHas(roleName, key) {
  return (rolePermissions.value[roleName] ?? []).includes(key)
}

/** Helper: is any perm in a group active for a role (for card highlight) */
function groupActive(group, roleName) {
  if (group.single) return roleHas(roleName, group.key)
  if (group.multi) return group.perms.some(p => roleHas(roleName, p.key))
  return roleHas(roleName, group.module + '.view') || roleHas(roleName, group.module + '.manage')
}

/** Same for create form */
function groupActiveForm(group) {
  if (group.single) return form.permissions.includes(group.key)
  if (group.multi) return group.perms.some(p => form.permissions.includes(p.key))
  return form.permissions.includes(group.module + '.view') || form.permissions.includes(group.module + '.manage')
}

loadRoles()

async function loadRoles() {
  loading.value = true; errorMsg.value = ''
  try {
    const [rolesRes, wuRes] = await Promise.all([
      adminsApi.listRoles(),
      workUnitsApi.list().catch(() => []),
    ])
    roles.value           = rolesRes.roles ?? []
    rolePermissions.value = rolesRes.permissions ?? {}
    allPermissions.value  = rolesRes.all_permissions ?? []
    roleScopes.value      = rolesRes.scopes ?? {}
    workUnits.value       = Array.isArray(wuRes) ? wuRes : (wuRes?.data ?? wuRes ?? [])
  } catch (err) {
    errorMsg.value = err?.message ?? 'Gagal memuat data role.'
  } finally { loading.value = false }
}

async function togglePermission(role, perm) {
  if (role === 'superadmin' || roles.value.find(r => r.name === role)?.is_system) {
    return // Safety check, GUI should disable checkboxes anyway
  }
  
  const current = [...(rolePermissions.value[role] ?? [])]
  let updated
  const has = current.includes(perm)

  if (has) {
    // Unchecking: remove the perm
    updated = current.filter(p => p !== perm)
    // If unchecking .view, also remove .manage and all sub-perms of this module
    if (perm.endsWith('.view')) {
      const module = perm.replace('.view', '')
      updated = updated.filter(p => !p.startsWith(module + '.'))
    }
    // If unchecking a base perm (no dot), also remove all sub-perms (e.g. dashboard → dashboard.*)
    if (!perm.includes('.')) {
      updated = updated.filter(p => !p.startsWith(perm + '.'))
    }
  } else {
    // Checking: add the perm
    updated = [...current, perm]
    // If checking .manage, also add .view
    if (perm.endsWith('.manage')) {
      const viewKey = perm.replace('.manage', '.view')
      if (!updated.includes(viewKey)) updated.push(viewKey)
    }
    // If checking any non-.view sub-perm, also ensure module.view is present (only for standard modules)
    if (!perm.endsWith('.view') && perm.includes('.')) {
      const module = perm.substring(0, perm.indexOf('.'))
      const viewKey = module + '.view'
      if (allPermissions.value.includes(viewKey) && !updated.includes(viewKey)) updated.push(viewKey)
    }
  }

  rolePermissions.value = { ...rolePermissions.value, [role]: updated }
  savingRole.value = role
  try {
    await adminsApi.updatePermissions(role, { permissions: updated })
    toast.success(`Hak akses ${role} diperbarui`)
    // Refresh current user's permissions if their role was modified
    if (role === authStore.admin?.role) {
      await authStore.fetchPermissions()
    }
  } catch (err) {
    rolePermissions.value = { ...rolePermissions.value, [role]: current }
    toast.error(err?.message ?? 'Gagal memperbarui hak akses')
  } finally {
    savingRole.value = ''
  }
}

function toggleFormPermission(perm) {
  const idx = form.permissions.indexOf(perm)
  if (idx >= 0) {
    // Unchecking: remove the perm
    form.permissions.splice(idx, 1)
    // If unchecking .view, remove all sub-perms of this module
    if (perm.endsWith('.view')) {
      const module = perm.replace('.view', '')
      for (let i = form.permissions.length - 1; i >= 0; i--) {
        if (form.permissions[i].startsWith(module + '.')) form.permissions.splice(i, 1)
      }
    }
    // If unchecking a base perm (no dot), also remove all sub-perms
    if (!perm.includes('.')) {
      for (let i = form.permissions.length - 1; i >= 0; i--) {
        if (form.permissions[i].startsWith(perm + '.')) form.permissions.splice(i, 1)
      }
    }
  } else {
    // Checking: add the perm
    form.permissions.push(perm)
    // If checking .manage, also add .view
    if (perm.endsWith('.manage')) {
      const viewKey = perm.replace('.manage', '.view')
      if (!form.permissions.includes(viewKey)) form.permissions.push(viewKey)
    }
    // If checking any non-.view sub-perm, also ensure module.view is present (only for standard modules)
    if (!perm.endsWith('.view') && perm.includes('.')) {
      const module = perm.substring(0, perm.indexOf('.'))
      const viewKey = module + '.view'
      if (allPermissions.value.includes(viewKey) && !form.permissions.includes(viewKey)) form.permissions.push(viewKey)
    }
  }
}

async function createRole() {
  formErrors.name = form.name.trim() ? '' : 'Nama role wajib diisi'
  if (formErrors.name) return

  creating.value = true; createError.value = ''
  try {
    await adminsApi.createRole({
      name: form.name.trim(),
      description: form.description.trim(),
      permissions: form.permissions,
      scope_type: form.scope_type,
      work_unit_ids: form.scope_type === 'specific' ? form.work_unit_ids : [],
      redirect_to: form.redirect_to || '/',
    })
    toast.success('Role berhasil dibuat!')
    showCreate.value = false
    await loadRoles()
  } catch (err) {
    createError.value = err?.message ?? 'Gagal membuat role.'
  } finally { creating.value = false }
}

function openEditRole(role) {
  editForm.name = role.name
  editForm.description = role.description || ''
  editForm.originalName = role.name
  editForm.isSystem = !!role.is_system
  editForm.redirect_to = role.redirect_to || '/'
  editFormErrors.name = ''
  editError.value = ''
  showEdit.value = true
}

async function submitEditRole() {
  editFormErrors.name = editForm.name.trim() ? '' : 'Nama role wajib diisi'
  if (editFormErrors.name) return

  editing.value = true; editError.value = ''
  try {
    await adminsApi.updateRole(editForm.originalName, {
      name: editForm.name.trim(),
      description: editForm.description.trim(),
      redirect_to: editForm.redirect_to || '/',
    })
    toast.success('Role berhasil diperbarui!')
    showEdit.value = false
    await loadRoles()
  } catch (err) {
    editError.value = err?.message ?? 'Gagal memperbarui role.'
  } finally { editing.value = false }
}

function confirmDelete(role) {
  deleteTarget.value = role
  showDeleteConfirm.value = true
}

async function doDelete() {
  if (!deleteTarget.value) return
  deletingRole.value = deleteTarget.value.name
  try {
    await adminsApi.deleteRole(deleteTarget.value.name)
    toast.success(`Role ${deleteTarget.value.name} dihapus`)
    showDeleteConfirm.value = false
    await loadRoles()
  } catch (err) {
    toast.error(err?.message ?? 'Gagal menghapus role')
  } finally {
    deletingRole.value = ''
  }
}

watch(showCreate, (v) => {
  if (!v) {
    form.name = ''; form.description = ''; form.permissions = []
    form.scope_type = 'all'; form.work_unit_ids = []; form.redirect_to = '/'
    formErrors.name = ''; createError.value = ''
  }
})
</script>