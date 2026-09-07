<script setup lang="ts">
import { onShow } from "@dcloudio/uni-app";
import { useUserStore } from "@/stores/user";

const userStore = useUserStore();

onShow(async () => {
  if (!userStore.profile && userStore.isLoggedIn) {
    try {
      await userStore.loadUserContext();
    } catch {
      // 登录失效由请求层统一处理。
    }
  }
});
</script>

<template>
  <view class="profile-page">
    <view class="profile-card">
      <view class="profile-avatar">{{ userStore.displayName.slice(0, 1) }}</view>
      <text class="profile-name">{{ userStore.displayName }}</text>
      <text class="profile-role">{{ userStore.profile?.deptName || "未设置部门" }} · {{ userStore.primaryRole }}</text>
    </view>
    <wd-cell-group border>
      <wd-cell title="登录账号" :value="userStore.profile?.username || '—'" />
      <wd-cell title="手机号码" :value="userStore.profile?.phone || '未设置'" />
    </wd-cell-group>
    <wd-button type="error" plain block size="large" custom-style="margin-top: 28px;" @click="userStore.logout">
      退出登录
    </wd-button>
  </view>
</template>

<style scoped>
.profile-page { min-height: 100vh; padding: 24px 16px; background: #f3f6f8; box-sizing: border-box; }
.profile-card { margin-bottom: 18px; padding: 30px 20px; border-radius: 14px; text-align: center; color: #fff; background: #203f54; }
.profile-avatar { width: 58px; height: 58px; margin: 0 auto; display: flex; align-items: center; justify-content: center; border-radius: 18px; color: #203f54; background: #e8b354; font-size: 22px; font-weight: 700; }
.profile-name { display: block; margin-top: 14px; font-size: 20px; font-weight: 650; }
.profile-role { display: block; margin-top: 7px; color: #cfdae0; font-size: 13px; }
</style>
