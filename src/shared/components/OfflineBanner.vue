<script setup lang="ts">
import { computed, onMounted } from 'vue';
import { useConnectivity } from '@/core/connectivity';

const { online, startListening } = useConnectivity();

const visible = computed(() => !online.value);

onMounted(() => {
  startListening();
});
</script>

<template>
  <view v-if="visible" class="offline-banner" role="alert">
    <wd-icon name="warn" size="16px" color="#fff" />
    <text class="offline-banner-text">当前无网络连接，部分功能可能不可用</text>
  </view>
</template>

<style scoped>
.offline-banner {
  padding: 10px 16px;
  display: flex;
  align-items: center;
  gap: 8px;
  color: #fff;
  font-size: 13px;
  background: #c94444;
}

.offline-banner-text {
  flex: 1;
  min-width: 0;
  color: #fff;
  font-size: 13px;
  line-height: 1.4;
}
</style>