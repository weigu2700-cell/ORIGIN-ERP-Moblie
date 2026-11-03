<script setup lang="ts">
import { onMounted } from 'vue';
import { useUserStore } from '@/stores/user';
import { useOrganizationStore } from '@/stores/organization';
import { captureSession, isSessionCurrent } from '@/utils/auth';
const user = useUserStore();
const organizations = useOrganizationStore();
onMounted(() => { if (!organizations.configuration) void organizations.initialize(); });
function open() {
  if (organizations.configuration?.mode === 'single') { uni.showToast({ title: '当前部署仅支持此组织', icon: 'none' }); return; }
  const snapshot = captureSession();
  const choices = [...organizations.recent, { code: '', name: '使用其他组织编码' }];
  uni.showActionSheet({ itemList: choices.map(item => `${item.name}${item.code === user.organization?.code ? '（当前）' : ''}`), success: ({ tapIndex }) => {
    const organization = choices[tapIndex];
    if (!organization || organization.code === user.organization?.code || !isSessionCurrent(snapshot)) return;
    uni.showModal({ title: '切换组织', content: '切换后需要重新登录，当前页面未提交的内容不会保留。', confirmText: '退出并切换', success: ({ confirm }) => {
      if (confirm && isSessionCurrent(snapshot)) { organizations.choose(organization.code); user.logout(); }
    } });
  } });
}
</script>
<template><button class="organization-bar" :aria-label="`当前组织 ${user.organization?.name || '加载中'}，选择或切换组织`" @click="open"><view class="organization-icon"><wd-icon name="shop" size="20px" /></view><view class="organization-copy"><text class="organization-label">当前组织</text><text class="organization-name">{{ user.organization?.name || '正在加载组织' }}</text></view><text class="switch-label">{{ organizations.configuration?.mode === 'single' ? '当前' : '切换' }}</text><wd-icon v-if="organizations.configuration?.mode !== 'single'" name="chevron-right" size="16px" /></button></template>
<style scoped>
.organization-bar { display: flex; align-items: center; text-align: left; width: 100%; min-height: 68px; padding: 12px 14px; margin: 0 0 16px; gap: 10px; border: 1px solid #d6e0e6; border-radius: 12px; background: #fff; line-height: 1.4; color: #203f54; }
.organization-bar::after { border: 0; }
.organization-icon { display: grid; place-items: center; width: 36px; height: 36px; border-radius: 9px; background: #eaf1f5; flex: 0 0 auto; }
.organization-copy { display: flex; flex-direction: column; gap: 4px; flex: 1; min-width: 0; }
.organization-label { font-size: 11px; color: #71818b; }
.organization-name { font-size: 15px; font-weight: 600; overflow-wrap: anywhere; }
.switch-label { font-size: 12px; color: #245b78; flex: 0 0 auto; }
</style>
