<script setup lang="ts">
import { onLoad } from '@dcloudio/uni-app';
onLoad(() => {
  uni.showToast({ title: '请从入库列表重新选择实际入库单', icon: 'none' });
  uni.redirectTo({ url: '/apps/production-inbound/index' });
});
</script>
<template><view>正在打开成品入库列表…</view></template>
