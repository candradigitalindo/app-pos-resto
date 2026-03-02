import { createApp } from 'vue'
import { createPinia } from 'pinia'
import { ElDialog, ElSelect, ElOption } from 'element-plus'
// Only import CSS for components actually used (dialog, select, message)
import 'element-plus/es/components/dialog/style/css'
import 'element-plus/es/components/select/style/css'
import 'element-plus/es/components/option/style/css'
import 'element-plus/es/components/message/style/css'
import 'element-plus/es/components/message-box/style/css'
import 'element-plus/es/components/overlay/style/css'
import './style.css'
import App from './App.vue'
import router from './router'

const app = createApp(App)
const pinia = createPinia()

app.use(pinia)
app.use(router)
// Register only the Element Plus components used in templates
app.component('ElDialog', ElDialog)
app.component('ElSelect', ElSelect)
app.component('ElOption', ElOption)
app.mount('#app')
