<script setup lang="ts">
import { onMounted } from "vue";

onMounted(() => {
  uni.switchTab({ url: "/pages/workbench/index" });
});
</script>

<template>
  <view />
</template>
