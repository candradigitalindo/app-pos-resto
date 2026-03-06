<template>
  <Transition name="modal">
    <div v-if="notification" class="notification-overlay" @click="notification.isConfirm ? null : hideNotification">
      <div :class="['notification-modal', `notification-${notification.type}`]" @click.stop>
        <div :class="['notification-icon-circle', `icon-${notification.type}`]">
          <div class="icon-inner">
            <svg v-if="notification.type === 'confirm'" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <circle cx="12" cy="12" r="10"/>
              <line x1="12" y1="8" x2="12" y2="12"/>
              <line x1="12" y1="16" x2="12.01" y2="16"/>
            </svg>
            <svg v-else-if="notification.type === 'created'" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <path d="M12 5v14M5 12h14"/>
            </svg>
            <svg v-else-if="notification.type === 'updated'" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/>
              <path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/>
            </svg>
            <svg v-else-if="notification.type === 'deleted'" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <polyline points="3 6 5 6 21 6"/>
              <path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/>
              <line x1="10" y1="11" x2="10" y2="17"/>
              <line x1="14" y1="11" x2="14" y2="17"/>
            </svg>
            <svg v-else-if="notification.type === 'success'" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
              <polyline points="20 6 9 17 4 12"/>
            </svg>
            <svg v-else-if="notification.type === 'error'" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
              <circle cx="12" cy="12" r="10"/>
              <line x1="15" y1="9" x2="9" y2="15"/>
              <line x1="9" y1="9" x2="15" y2="15"/>
            </svg>
            <svg v-else-if="notification.type === 'warning'" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
              <path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/>
              <line x1="12" y1="9" x2="12" y2="13"/>
              <line x1="12" y1="17" x2="12.01" y2="17"/>
            </svg>
            <svg v-else xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
              <circle cx="12" cy="12" r="10"/>
              <line x1="12" y1="16" x2="12" y2="12"/>
              <line x1="12" y1="8" x2="12.01" y2="8"/>
            </svg>
          </div>
        </div>
        
        <h3 class="notification-title">
          {{ notification.type === 'confirm' ? 'Konfirmasi' :
             notification.type === 'created' ? 'Berhasil!' : 
             notification.type === 'updated' ? 'Diperbarui!' : 
             notification.type === 'deleted' ? 'Terhapus!' : 
             notification.type === 'error' ? 'Oops!' : 'Sukses!' }}
        </h3>
        
        <p class="notification-message">{{ notification.message }}</p>
        
        <div v-if="notification.isConfirm" class="notification-buttons">
          <button class="notification-button button-cancel" @click="handleCancel">
            Batal
          </button>
          <button class="notification-button button-confirm" @click="handleConfirm">
            Ya, Hapus
          </button>
        </div>
        <button v-else class="notification-button" @click="hideNotification">
          OK
        </button>
      </div>
    </div>
  </Transition>
</template>

<script setup>
import { useNotification } from '../composables/useNotification'

const { notification, hideNotification, handleConfirm, handleCancel } = useNotification()
</script>

<style scoped>
.notification-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(0, 0, 0, 0.6);
  backdrop-filter: blur(8px);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 9999;
  padding: 1rem;
}

.notification-modal {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 1.5rem;
  padding: 3rem 2.5rem 2.5rem;
  border-radius: 1.5rem;
  background: white;
  box-shadow: 
    0 30px 60px -12px rgba(0, 0, 0, 0.25),
    0 0 0 1px rgba(0, 0, 0, 0.05);
  max-width: 480px;
  width: 100%;
  position: relative;
  animation: modalBounceIn 0.5s cubic-bezier(0.68, -0.55, 0.265, 1.55);
}

@media (max-width: 640px) {
  .notification-modal {
    padding: 2.5rem 2rem 2rem;
    max-width: 90%;
    gap: 1.25rem;
  }
}

.notification-icon-circle {
  width: 5.5rem;
  height: 5.5rem;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  position: relative;
  animation: iconPulse 0.6s ease-out;
}

@media (max-width: 640px) {
  .notification-icon-circle {
    width: 5rem;
    height: 5rem;
  }
}

.icon-created {
  background: linear-gradient(135deg, #10b981 0%, #059669 100%);
  box-shadow: 
    0 0 0 8px rgba(16, 185, 129, 0.1),
    0 0 0 16px rgba(16, 185, 129, 0.05),
    0 8px 24px rgba(16, 185, 129, 0.4);
}

.icon-updated {
  background: linear-gradient(135deg, #fbbf24 0%, #f59e0b 100%);
  box-shadow: 
    0 0 0 8px rgba(251, 191, 36, 0.1),
    0 0 0 16px rgba(251, 191, 36, 0.05),
    0 8px 24px rgba(251, 191, 36, 0.4);
}

.icon-deleted {
  background: linear-gradient(135deg, #ef4444 0%, #dc2626 100%);
  box-shadow: 
    0 0 0 8px rgba(239, 68, 68, 0.1),
    0 0 0 16px rgba(239, 68, 68, 0.05),
    0 8px 24px rgba(239, 68, 68, 0.4);
}

.icon-success {
  background: linear-gradient(135deg, #10b981 0%, #059669 100%);
  box-shadow: 
    0 0 0 8px rgba(16, 185, 129, 0.1),
    0 0 0 16px rgba(16, 185, 129, 0.05),
    0 8px 24px rgba(16, 185, 129, 0.4);
}

.icon-error {
  background: linear-gradient(135deg, #ef4444 0%, #dc2626 100%);
  box-shadow: 
    0 0 0 8px rgba(239, 68, 68, 0.1),
    0 0 0 16px rgba(239, 68, 68, 0.05),
    0 8px 24px rgba(239, 68, 68, 0.4);
}

.icon-warning {
  background: linear-gradient(135deg, #fbbf24 0%, #f59e0b 100%);
  box-shadow: 
    0 0 0 8px rgba(251, 191, 36, 0.1),
    0 0 0 16px rgba(251, 191, 36, 0.05),
    0 8px 24px rgba(251, 191, 36, 0.4);
}

.icon-confirm {
  background: linear-gradient(135deg, #f59e0b 0%, #d97706 100%);
  box-shadow: 
    0 0 0 8px rgba(245, 158, 11, 0.1),
    0 0 0 16px rgba(245, 158, 11, 0.05),
    0 8px 24px rgba(245, 158, 11, 0.4);
}

.icon-info {
  background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%);
  box-shadow: 
    0 0 0 8px rgba(59, 130, 246, 0.1),
    0 0 0 16px rgba(59, 130, 246, 0.05),
    0 8px 24px rgba(59, 130, 246, 0.4);
}

.icon-inner {
  width: 100%;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  color: white;
}

.icon-inner svg {
  width: 3rem;
  height: 3rem;
  stroke-width: 2.5;
  filter: drop-shadow(0 2px 8px rgba(0, 0, 0, 0.2));
}

@media (max-width: 640px) {
  .icon-inner svg {
    width: 2.75rem;
    height: 2.75rem;
  }
}

.notification-title {
  margin: 0;
  font-size: 1.875rem;
  font-weight: 700;
  color: #1f2937;
  text-align: center;
  letter-spacing: -0.025em;
}

@media (max-width: 640px) {
  .notification-title {
    font-size: 1.625rem;
  }
}

.notification-message {
  margin: 0;
  font-size: 1.125rem;
  font-weight: 500;
  color: #6b7280;
  text-align: center;
  line-height: 1.7;
  max-width: 90%;
}

@media (max-width: 640px) {
  .notification-message {
    font-size: 1rem;
  }
}

.notification-buttons {
  display: flex;
  gap: 0.75rem;
  margin-top: 0.5rem;
  width: 100%;
}

.notification-button {
  margin-top: 0.5rem;
  padding: 0.875rem 3rem;
  font-size: 1rem;
  font-weight: 600;
  color: white;
  border: none;
  border-radius: 0.75rem;
  cursor: pointer;
  transition: all 0.2s ease;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
  letter-spacing: 0.025em;
}

.notification-buttons .notification-button {
  flex: 1;
  margin-top: 0;
  padding: 0.875rem 1.5rem;
}

@media (max-width: 640px) {
  .notification-button {
    padding: 0.75rem 2.5rem;
    font-size: 0.9375rem;
  }
  
  .notification-buttons .notification-button {
    padding: 0.75rem 1.25rem;
  }
}

.notification-created .notification-button {
  background: linear-gradient(135deg, #10b981 0%, #059669 100%);
}

.notification-created .notification-button:hover {
  background: linear-gradient(135deg, #059669 0%, #047857 100%);
  box-shadow: 0 6px 16px rgba(16, 185, 129, 0.4);
  transform: translateY(-2px);
}

.notification-updated .notification-button {
  background: linear-gradient(135deg, #fbbf24 0%, #f59e0b 100%);
}

.notification-updated .notification-button:hover {
  background: linear-gradient(135deg, #f59e0b 0%, #d97706 100%);
  box-shadow: 0 6px 16px rgba(251, 191, 36, 0.4);
  transform: translateY(-2px);
}

.notification-deleted .notification-button {
  background: linear-gradient(135deg, #ef4444 0%, #dc2626 100%);
}

.notification-deleted .notification-button:hover {
  background: linear-gradient(135deg, #dc2626 0%, #b91c1c 100%);
  box-shadow: 0 6px 16px rgba(239, 68, 68, 0.4);
  transform: translateY(-2px);
}

.notification-success .notification-button {
  background: linear-gradient(135deg, #10b981 0%, #059669 100%);
}

.notification-success .notification-button:hover {
  background: linear-gradient(135deg, #059669 0%, #047857 100%);
  box-shadow: 0 6px 16px rgba(16, 185, 129, 0.4);
  transform: translateY(-2px);
}

.notification-error .notification-button {
  background: linear-gradient(135deg, #ef4444 0%, #dc2626 100%);
}

.notification-error .notification-button:hover {
  background: linear-gradient(135deg, #dc2626 0%, #b91c1c 100%);
  box-shadow: 0 6px 16px rgba(239, 68, 68, 0.4);
  transform: translateY(-2px);
}

.notification-warning .notification-button {
  background: linear-gradient(135deg, #fbbf24 0%, #f59e0b 100%);
}

.notification-warning .notification-button:hover {
  background: linear-gradient(135deg, #f59e0b 0%, #d97706 100%);
  box-shadow: 0 6px 16px rgba(251, 191, 36, 0.4);
  transform: translateY(-2px);
}

.notification-info .notification-button {
  background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%);
}

.notification-info .notification-button:hover {
  background: linear-gradient(135deg, #2563eb 0%, #1d4ed8 100%);
  box-shadow: 0 6px 16px rgba(59, 130, 246, 0.4);
  transform: translateY(-2px);
}

.button-cancel {
  background: linear-gradient(135deg, #6b7280 0%, #4b5563 100%);
}

.button-cancel:hover {
  background: linear-gradient(135deg, #4b5563 0%, #374151 100%);
  box-shadow: 0 6px 16px rgba(107, 114, 128, 0.4);
  transform: translateY(-2px);
}

.button-confirm {
  background: linear-gradient(135deg, #ef4444 0%, #dc2626 100%);
}

.button-confirm:hover {
  background: linear-gradient(135deg, #dc2626 0%, #b91c1c 100%);
  box-shadow: 0 6px 16px rgba(239, 68, 68, 0.4);
  transform: translateY(-2px);
}

.notification-button:active {
  transform: translateY(0);
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.15);
}

/* Modal Animations */
.modal-enter-active {
  animation: overlayFadeIn 0.3s ease-out;
}

.modal-leave-active {
  animation: overlayFadeOut 0.25s ease-in;
}

.modal-enter-from,
.modal-leave-to {
  opacity: 0;
}

.modal-enter-from .notification-modal {
  transform: scale(0.7);
  opacity: 0;
}

.modal-leave-to .notification-modal {
  transform: scale(0.85);
  opacity: 0;
}

@keyframes modalBounceIn {
  0% {
    opacity: 0;
    transform: scale(0.3) translateY(-50px);
  }
  50% {
    opacity: 1;
    transform: scale(1.05);
  }
  70% {
    transform: scale(0.95);
  }
  100% {
    transform: scale(1);
  }
}

@keyframes iconPulse {
  0% {
    transform: scale(0);
    opacity: 0;
  }
  50% {
    transform: scale(1.1);
  }
  100% {
    transform: scale(1);
    opacity: 1;
  }
}

@keyframes overlayFadeIn {
  from {
    opacity: 0;
  }
  to {
    opacity: 1;
  }
}

@keyframes overlayFadeOut {
  from {
    opacity: 1;
  }
  to {
    opacity: 0;
  }
}
</style>
