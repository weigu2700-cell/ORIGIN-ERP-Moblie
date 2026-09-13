<script setup lang="ts">
import { ref } from 'vue';
import { onShow } from '@dcloudio/uni-app';
import { useUserStore } from '@/stores/user';

const userStore = useUserStore();
const loading = ref(false);
const errorMessage = ref('');

async function loadProfile() {
  loading.value = true;
  errorMessage.value = '';
  userStore.restoreSession();
  if (!userStore.hasToken) {
    loading.value = false;
    uni.reLaunch({ url: '/pages/login/login' });
    return;
  }
  try {
    const authenticated = await userStore.validateSession(true);
    if (!authenticated) uni.reLaunch({ url: '/pages/login/login' });
  } catch (error) {
    errorMessage.value = error instanceof Error ? error.message : '账号信息加载失败';
  } finally {
    loading.value = false;
  }
}

function confirmLogout() {
  uni.showModal({
    title: '退出登录',
    content: '退出后需要重新输入企业 ERP 账号，确定退出吗？',
    confirmText: '退出',
    confirmColor: '#c94444',
    success: ({ confirm }) => {
      if (confirm) userStore.logout();
    },
  });
}

onShow(() => {
  loadProfile();
});
</script>

<template>
  <view class="profile-page">
    <view v-if="loading && !userStore.profile" class="profile-state">正在加载账号信息...</view>
    <view v-else-if="errorMessage && !userStore.profile" class="profile-state profile-state-error">
      <text>{{ errorMessage }}</text>
      <wd-button size="small" plain aria-label="重新加载账号信息" @click="loadProfile"
        >重新加载</wd-button
      >
    </view>
    <template v-else>
      <view class="profile-card">
        <view class="profile-topline">
          <text class="profile-kicker">ACCOUNT</text>
          <view class="account-status"><view class="status-dot" />已登录</view>
        </view>
        <view class="profile-main">
          <view class="profile-avatar">{{ userStore.displayName.slice(0, 1) }}</view>
          <view class="profile-copy">
            <text class="profile-name">{{ userStore.displayName }}</text>
            <text class="profile-role"
              >{{ userStore.profile?.deptName || '未设置部门' }} · {{ userStore.primaryRole }}</text
            >
          </view>
        </view>
      </view>
      <view class="info-card">
        <view class="info-row">
          <text class="info-label">登录账号</text>
          <text class="info-value">{{ userStore.profile?.username || '暂无' }}</text>
        </view>
        <view class="info-row">
          <text class="info-label">手机号码</text>
          <text class="info-value">{{ userStore.profile?.phone || '未设置' }}</text>
        </view>
      </view>
      <wd-button
        type="error"
        plain
        block
        size="large"
        aria-label="退出当前账号"
        custom-style="margin-top: 28px;"
        @click="confirmLogout"
      >
        退出登录
      </wd-button>
    </template>
  </view>
</template>

<style scoped>
.profile-page {
  min-height: 100dvh;
  padding: 24px 16px calc(env(safe-area-inset-bottom) + 28px);
  background: #eef3f5;
  box-sizing: border-box;
}
.profile-state {
  min-height: 240px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 16px;
  color: #71818b;
  font-size: 14px;
  text-align: center;
}
.profile-state-error {
  color: #9a6612;
}
.profile-card {
  margin-bottom: 18px;
  padding: 18px;
  border-radius: 16px;
  color: #fff;
  background: linear-gradient(145deg, #18384b 0%, #2a6279 100%);
  box-shadow: 0 10px 22px rgba(20, 57, 76, 0.12);
}
.profile-topline {
  display: flex;
  align-items: center;
  justify-content: space-between;
}
.profile-kicker {
  color: #b7c8d1;
  font-size: 10px;
  letter-spacing: 1.4px;
}
.account-status {
  display: flex;
  align-items: center;
  gap: 5px;
  color: #d8e8e2;
  font-size: 11px;
}
.status-dot {
  width: 5px;
  height: 5px;
  border-radius: 50%;
  background: #70c89b;
}
.profile-main {
  margin-top: 26px;
  display: flex;
  align-items: center;
}
.profile-avatar {
  width: 58px;
  height: 58px;
  margin: 0 auto;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 18px;
  color: #203f54;
  background: #e8b354;
  font-size: 22px;
  font-weight: 700;
}
.profile-copy {
  min-width: 0;
  margin-left: 14px;
}
.profile-name {
  display: block;
  font-size: 20px;
  font-weight: 700;
}
.profile-role {
  display: block;
  margin-top: 7px;
  color: #cfdae0;
  font-size: 13px;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.info-card {
  overflow: hidden;
  border: 1px solid #e1e8ec;
  border-radius: 16px;
  background: #fff;
  box-shadow: 0 6px 16px rgba(31, 75, 95, 0.035);
}
.info-row {
  min-height: 60px;
  padding: 0 16px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  border-bottom: 1px solid #edf1f3;
}
.info-row:last-child {
  border-bottom: 0;
}
.info-label {
  color: #71818b;
  font-size: 13px;
}
.info-value {
  min-width: 0;
  overflow: hidden;
  color: #203f54;
  font-size: 14px;
  text-overflow: ellipsis;
  white-space: nowrap;
}
</style>
