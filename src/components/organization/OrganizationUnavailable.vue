<script setup lang="ts">
import { ref } from 'vue';
import { useUserStore } from '@/stores/user';
const user = useUserStore();
const loading = ref(false), error = ref('');
async function retry() { if (loading.value) return; loading.value = true; error.value = ''; try { await user.validateSession(true); } catch { error.value = '暂时无法检查组织状态，请稍后重试'; } finally { loading.value = false; } }
</script>
<template><view class="organization-unavailable"><view class="symbol"><wd-icon name="shop" size="28px" /></view><text class="welcome">欢迎回来，{{ user.displayName }}</text><text class="title">当前组织暂未开放业务</text><text class="description">组织开放后，你可以在这里处理日常工作。也可以从顶部切换组织，重新登录。</text><text v-if="error" class="error" role="alert">{{ error }}</text><wd-button :loading="loading" :disabled="loading" @click="retry">重新检查</wd-button></view></template>
<style scoped>
.organization-unavailable { margin-top: 24px; padding: 30px 22px; background: #fff; border: 1px solid #d6e0e6; border-radius: 16px; display: flex; flex-direction: column; align-items: flex-start; gap: 16px; }
.symbol { color: #245b78; background: #eaf1f5; border-radius: 12px; padding: 14px; }
.welcome { color: #71818b; font-size: 13px; }
.title { font-size: 21px; font-weight: 600; color: #18384b; }
.description { color: #71818b; font-size: 14px; line-height: 1.8; }
.error { color: #b63737; font-size: 13px; }
</style>
