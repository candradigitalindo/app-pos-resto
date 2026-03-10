<template>
  <!--
    App.vue — Root component
    Simply renders the current route component.
    RouterView is swapped by vue-router based on the URL.

    AI NOTE: Global overlays (toasts, modals) can be added just before
    </RouterView> so they're always available regardless of the current page.
  -->
  <RouterView />
</template>

<script setup>
/**
 * App.vue <script setup>
 * No logic needed here — layouts and pages handle everything.
 */
</script>
