<script setup lang="ts">
import { computed, ref } from 'vue';
import { onShow } from '@dcloudio/uni-app';
import OfflineBanner from '@/shared/components/OfflineBanner.vue';
import { useUserStore } from '@/stores/user';
import { PERMISSION_CODES } from '@/core/auth/permission-registry';
import {
  SERVICE_CATALOG,
  SERVICE_CATEGORIES,
  type ServiceCatalogItem,
} from '@/constants/service-catalog';

const userStore = useUserStore();
const keyword = ref('');
const syncingPermissions = ref(false);
const permissionError = ref('');

const isPermissionLoading = computed(
  () =>
    syncingPermissions.value ||
    userStore.permissionsStatus === 'idle' ||
    userStore.permissionsStatus === 'loading',
);

const authorizedServices = computed(() => {
  if (userStore.permissionsStatus !== 'ready') return [];
  return SERVICE_CATALOG.filter((service) => userStore.hasAnyPermission([...service.permissions]));
});

const filteredSections = computed(() => {
  const query = keyword.value.trim().toLocaleLowerCase();
  return SERVICE_CATEGORIES.map((category) => ({
    ...category,
    items: authorizedServices.value.filter((service) => {
      if (service.categoryCode !== category.code) return false;
      if (!query) return true;
      return `${service.title} ${service.description}`.toLocaleLowerCase().includes(query);
    }),
  })).filter((section) => section.items.length > 0);
});

const serviceSummary = computed(() => {
  const available = authorizedServices.value.filter((item) => item.available).length;
  const planned = authorizedServices.value.length - available;
  if (!planned) return `已开放 ${available} 项服务`;
  return `已开放 ${available} 项 · 建设中 ${planned} 项`;
});

async function refreshPermissions() {
  if (syncingPermissions.value) return;
  userStore.restoreSession();
  if (!userStore.hasToken) {
    uni.reLaunch({ url: '/pages/login/login' });
    return;
  }

  syncingPermissions.value = true;
  permissionError.value = '';
  try {
    const authenticated = await userStore.validateSession(true);
    if (!authenticated) {
      uni.reLaunch({ url: '/pages/login/login' });
      return;
    }
    if (userStore.permissionsStatus === 'error') {
      permissionError.value = userStore.contextError || '权限信息加载失败，请重试';
    }
  } catch (error) {
    permissionError.value = error instanceof Error ? error.message : '服务目录加载失败，请重试';
  } finally {
    syncingPermissions.value = false;
  }
}

function clearSearch() {
  keyword.value = '';
}

function scanMaterial() {
  uni.scanCode({
    scanType: ['barCode', 'qrCode'],
    success: ({ result }) => {
      if (userStore.hasAnyPermission([PERMISSION_CODES.inventoryList])) {
        uni.navigateTo({
          url: `/apps/inventory/index?keyword=${encodeURIComponent(result)}`,
        });
        return;
      }
      uni.navigateTo({
        url: `/pages/feature/index?title=${encodeURIComponent('扫码结果')}&value=${encodeURIComponent(result)}`,
      });
    },
    fail: (error) => {
      if (!/cancel/i.test(error.errMsg || '')) {
        uni.showToast({ title: '扫码失败，请重试', icon: 'none' });
      }
    },
  });
}

function openService(service: ServiceCatalogItem) {
  if (!service.available) {
    uni.showToast({ title: `${service.title}正在建设中`, icon: 'none' });
    return;
  }
  if (service.code === 'scan') {
    scanMaterial();
    return;
  }
  if (service.route) uni.navigateTo({ url: service.route });
}

onShow(() => {
  userStore.restoreSession();
  if (!userStore.hasToken) {
    uni.reLaunch({ url: '/pages/login/login' });
    return;
  }
  if (userStore.permissionsStatus === 'idle') refreshPermissions();
  else if (userStore.permissionsStatus === 'error') {
    permissionError.value = userStore.contextError || '权限信息加载失败，请重试';
  } else permissionError.value = '';
});
</script>

<template>
  <view class="services-page">
    <OfflineBanner />

    <view class="hero">
      <text class="eyebrow">SERVICE DIRECTORY</text>
      <text class="hero-title">全部服务</text>
      <text class="hero-copy">按业务分类查找你有权限使用的移动端能力</text>
      <text v-if="userStore.permissionsStatus === 'ready'" class="hero-meta">{{
        serviceSummary
      }}</text>
    </view>

    <view class="content">
      <view class="search-box">
        <wd-icon name="search" size="18px" color="#71818b" aria-hidden="true" />
        <input
          v-model="keyword"
          class="search-input"
          type="text"
          confirm-type="search"
          placeholder="搜索服务，例如库存、订单"
          placeholder-class="search-placeholder"
          aria-label="搜索服务"
        />
        <view
          v-if="keyword"
          class="clear-button"
          role="button"
          aria-label="清除服务搜索"
          hover-class="control-pressed"
          @click="clearSearch"
        >
          <wd-icon name="close" size="16px" color="#71818b" />
        </view>
      </view>

      <view v-if="isPermissionLoading" class="skeleton-list" aria-label="正在加载服务目录">
        <view v-for="index in 6" :key="index" class="skeleton-card" />
      </view>

      <view
        v-else-if="userStore.permissionsStatus === 'error' || permissionError"
        class="state-card state-card-warning"
        role="alert"
      >
        <wd-icon name="warn" size="28px" color="#9a6612" aria-hidden="true" />
        <text class="state-title">暂时无法读取服务权限</text>
        <text class="state-copy">{{ permissionError || '请检查网络后重新加载' }}</text>
        <wd-button
          type="primary"
          size="small"
          aria-label="重新加载服务权限"
          @click="refreshPermissions"
        >
          重新加载
        </wd-button>
      </view>

      <view v-else-if="filteredSections.length === 0" class="state-card">
        <wd-icon name="search" size="28px" color="#98a4ac" aria-hidden="true" />
        <text class="state-title">{{ keyword ? '没有匹配的服务' : '暂无可用服务' }}</text>
        <text class="state-copy">
          {{ keyword ? '换一个名称试试，或清除搜索条件' : '如需更多权限，请联系系统管理员' }}
        </text>
        <wd-button v-if="keyword" plain size="small" aria-label="清除搜索条件" @click="clearSearch">
          清除搜索
        </wd-button>
      </view>

      <view v-else class="section-list">
        <view v-for="section in filteredSections" :key="section.code" class="service-section">
          <view class="section-heading">
            <text class="section-title">{{ section.title }}</text>
            <text class="section-count">{{ section.items.length }} 项</text>
          </view>
          <view class="service-grid">
            <view
              v-for="service in section.items"
              :key="service.code"
              class="service-card"
              :class="{ 'service-card-planned': !service.available }"
              role="button"
              :aria-label="`${service.title}，${service.description}${service.available ? '' : '，建设中'}`"
              :aria-disabled="!service.available"
              hover-class="service-card-pressed"
              @click="openService(service)"
            >
              <view class="card-topline">
                <view class="service-icon" :class="`tone-${service.tone}`">
                  <wd-icon :name="service.icon" size="22px" aria-hidden="true" />
                </view>
                <text v-if="!service.available" class="planned-badge">建设中</text>
                <wd-icon
                  v-else
                  name="chevron-right"
                  size="16px"
                  color="#a5b1b8"
                  aria-hidden="true"
                />
              </view>
              <text class="service-title">{{ service.title }}</text>
              <text class="service-description">{{ service.description }}</text>
            </view>
          </view>
        </view>
      </view>
    </view>
  </view>
</template>

<style scoped>
.services-page {
  min-height: 100dvh;
  padding-bottom: calc(env(safe-area-inset-bottom) + 28px);
  color: #162631;
  background: #eef3f5;
  box-sizing: border-box;
}

.hero {
  padding: 22px 20px 24px;
  color: #fff;
  background: linear-gradient(145deg, #18384b 0%, #2a6279 100%);
}

.eyebrow,
.hero-title,
.hero-copy,
.hero-meta,
.section-title,
.section-count,
.service-title,
.service-description,
.state-title,
.state-copy {
  display: block;
}

.eyebrow {
  color: #b9cbd4;
  font-size: 10px;
  font-weight: 600;
  letter-spacing: 1.4px;
}

.hero-title {
  margin-top: 9px;
  font-size: 25px;
  font-weight: 750;
  line-height: 1.25;
}

.hero-copy {
  margin-top: 8px;
  color: #d6e1e6;
  font-size: 14px;
  line-height: 1.55;
}

.hero-meta {
  margin-top: 14px;
  color: #f2c16a;
  font-size: 12px;
  font-weight: 600;
}

.content {
  padding: 16px;
}

.search-box {
  min-height: 48px;
  padding-left: 14px;
  display: flex;
  align-items: center;
  border: 1px solid #d6e0e6;
  border-radius: 12px;
  background: #fff;
}

.search-input {
  min-width: 0;
  height: 48px;
  margin-left: 9px;
  flex: 1;
  color: #162631;
  font-size: 15px;
}

.search-placeholder {
  color: #98a4ac;
}

.clear-button {
  width: 48px;
  height: 48px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.control-pressed,
.service-card-pressed {
  opacity: 0.72;
}

.section-list {
  margin-top: 20px;
}

.service-section + .service-section {
  margin-top: 24px;
}

.section-heading {
  margin-bottom: 10px;
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 12px;
}

.section-title {
  font-size: 17px;
  font-weight: 700;
}

.section-count {
  color: #82919a;
  font-size: 12px;
}

.service-grid,
.skeleton-list {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 10px;
}

.service-card,
.skeleton-card {
  min-width: 0;
  min-height: 128px;
  border-radius: 12px;
  box-sizing: border-box;
}

.service-card {
  padding: 14px;
  border: 1px solid #d6e0e6;
  background: #fff;
}

.service-card-planned {
  background: #f8fafb;
}

.card-topline {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
}

.service-icon {
  width: 40px;
  height: 40px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 11px;
}

.tone-navy {
  color: #25475b;
  background: #e4edf2;
}
.tone-blue {
  color: #246b8d;
  background: #e4f1f7;
}
.tone-amber {
  color: #9a6612;
  background: #fff3dc;
}
.tone-green {
  color: #287a58;
  background: #e5f3ec;
}
.tone-cyan {
  color: #237887;
  background: #e2f2f4;
}
.tone-orange {
  color: #a95d22;
  background: #fff0e3;
}
.tone-violet {
  color: #67558e;
  background: #eee9f7;
}
.tone-red {
  color: #a54848;
  background: #f8e9e9;
}

.planned-badge {
  padding: 3px 6px;
  border: 1px solid #d6e0e6;
  border-radius: 999px;
  color: #71818b;
  background: #fff;
  font-size: 10px;
  line-height: 1.2;
}

.service-title {
  margin-top: 12px;
  font-size: 15px;
  font-weight: 700;
  line-height: 1.35;
}

.service-description {
  margin-top: 5px;
  color: #71818b;
  font-size: 12px;
  line-height: 1.45;
}

.skeleton-list {
  margin-top: 20px;
}

.skeleton-card {
  background: linear-gradient(90deg, #e5ebee 25%, #f5f7f8 50%, #e5ebee 75%);
  background-size: 200% 100%;
  animation: skeleton-loading 1.4s ease-in-out infinite;
}

.state-card {
  min-height: 220px;
  margin-top: 20px;
  padding: 28px 20px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 10px;
  border: 1px solid #d6e0e6;
  border-radius: 12px;
  text-align: center;
  background: #fff;
}

.state-card-warning {
  border-color: #ead4ad;
  background: #fffaf0;
}

.state-title {
  font-size: 16px;
  font-weight: 700;
}

.state-copy {
  max-width: 280px;
  margin-bottom: 4px;
  color: #71818b;
  font-size: 13px;
  line-height: 1.55;
}

@keyframes skeleton-loading {
  from {
    background-position: 100% 0;
  }
  to {
    background-position: -100% 0;
  }
}

@media (prefers-reduced-motion: reduce) {
  .skeleton-card {
    animation: none;
  }
}

@media (min-width: 600px) {
  .content {
    max-width: 760px;
    margin: 0 auto;
  }
  .service-grid,
  .skeleton-list {
    grid-template-columns: repeat(3, minmax(0, 1fr));
  }
}
</style>
