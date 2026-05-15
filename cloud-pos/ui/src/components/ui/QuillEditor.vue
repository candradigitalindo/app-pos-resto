<!--
  QuillEditor.vue — Minimal Rich Text Editor wrapper for Quill
-->
<template>
  <div class="quill-editor-root">
    <div ref="editorEl"></div>
  </div>
</template>

<script setup>
import { ref, onMounted, watch, onBeforeUnmount } from 'vue'
import Quill from 'quill'
import 'quill/dist/quill.snow.css'

const props = defineProps({
  modelValue: { type: String, default: '' },
  placeholder: { type: String, default: 'Tulis langkah...' }
})

const emit = defineEmits(['update:modelValue'])

const editorEl = ref(null)
let quill = null

onMounted(() => {
  quill = new Quill(editorEl.value, {
    theme: 'snow',
    placeholder: props.placeholder,
    modules: {
      toolbar: [
        ['bold', 'italic', 'underline'],
        [{ 'list': 'ordered'}, { 'list': 'bullet' }],
        ['clean']
      ]
    }
  })

  quill.root.innerHTML = props.modelValue

  quill.on('text-change', () => {
    const html = quill.root.innerHTML
    if (html === '<p><br></p>') {
      emit('update:modelValue', '')
    } else {
      emit('update:modelValue', html)
    }
  })
})

watch(() => props.modelValue, (newVal) => {
  if (quill && newVal !== quill.root.innerHTML) {
    quill.root.innerHTML = newVal || ''
  }
})

onBeforeUnmount(() => {
  quill = null
})
</script>

<style>
.quill-editor-root .ql-toolbar.ql-snow {
  border-top-left-radius: 0.75rem;
  border-top-right-radius: 0.75rem;
  border-color: #e5e7eb;
  background: #f9fafb;
  padding: 4px 8px;
}
.quill-editor-root .ql-container.ql-snow {
  border-bottom-left-radius: 0.75rem;
  border-bottom-right-radius: 0.75rem;
  border-color: #e5e7eb;
  font-family: inherit;
  font-size: 0.875rem;
}
.quill-editor-root .ql-editor {
  min-height: 100px;
  max-height: 300px;
}
.quill-editor-root .ql-editor.ql-blank::before {
  font-style: normal;
  color: #9ca3af;
}
</style>
