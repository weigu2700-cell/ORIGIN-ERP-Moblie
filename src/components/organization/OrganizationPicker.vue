<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useOrganizationStore } from '@/stores/organization';
defineProps<{ disabled?: boolean }>();
const emit = defineEmits<{ (event: 'change'): void }>();
const organizations = useOrganizationStore();
const code = ref(organizations.selectedCode);
watch(
  () => organizations.selectedCode,
  (value) => {
    code.value = value;
  },
);
const choices = computed(() => [
  ...organizations.recent.map((item) => ({
    code: item.code,
    label: `${item.name} · ${item.code}`,
  })),
  { code: '', label: '使用其他组织编码' },
]);
async function verify(value = code.value) {
  emit('change');
  try {
    if (!organizations.configuration) await organizations.initialize();
    if (organizations.configuration) await organizations.verify(value);
  } catch {
    /* 字段内提供重试。 */
  }
}
function edit() {
  organizations.choose(code.value);
  emit('change');
}
function select(event: { detail: { value: string } }) {
  const option = choices.value[Number(event.detail.value)];
  if (!option) return;
  code.value = option.code;
  organizations.choose(option.code);
  emit('change');
  if (option.code) void verify(option.code);
}
</script>
<template>
  <view class="organization-field">
    <text class="label">登录组织</text>
    <view v-if="organizations.configuration?.mode === 'single'" class="single-organization"
      ><wd-icon name="shop" size="20px" /><text>{{
        organizations.resolved?.name || '当前组织'
      }}</text></view
    >
    <template v-else>
      <view class="code-row">
        <wd-input
          v-model="code"
          placeholder="组织编码"
          aria-label="组织编码"
          no-border
          clearable
          :maxlength="64"
          :disabled="disabled || organizations.initializing"
          custom-style="flex: 1; min-width: 0; padding: 0 12px;"
          @input="edit"
          @confirm="verify()"
        />
        <picker
          v-if="organizations.recent.length"
          :range="choices"
          range-key="label"
          :disabled="disabled || organizations.initializing"
          aria-label="选择最近使用的组织"
          class="recent-trigger"
          @change="select"
          ><view class="recent-arrow"
            ><wd-icon name="chevron-down" size="16px" aria-hidden="true" /></view
        ></picker>
        <button
          class="verify"
          role="button"
          :disabled="disabled || organizations.loading || organizations.initializing"
          @click="verify()"
        >
          {{ organizations.loading ? '核验中' : !organizations.configuration ? '重试' : '核验' }}
        </button>
      </view>
    </template>
    <text v-if="organizations.initializing || organizations.loading" class="hint" role="status"
      >正在核验组织…</text
    >
    <text v-else-if="organizations.error" class="error" role="alert"
      >{{ organizations.error }}，可重新核验</text
    >
    <text v-else-if="organizations.resolved" class="hint" :aria-label="organizations.resolved.name"
      >{{ organizations.resolved.name }} · {{ organizations.resolved.code }}</text
    >
    <text v-else class="hint">首次使用请向管理员获取组织编码</text>
  </view>
</template>
<style scoped>
.organization-field {
  margin-bottom: var(--login-field-gap, 16px);
}
.label {
  display: block;
  color: var(--color-text, #162631);
  margin-bottom: 6px;
  font-size: 13px;
  font-weight: 600;
}
.single-organization,
.recent-picker,
.code-row {
  min-height: var(--login-control-height, 52px);
  display: flex;
  align-items: center;
  gap: 10px;
  border: 1px solid #d6e0e6;
  border-radius: 12px;
  background: #fff;
}
.single-organization,
.recent-picker {
  padding: 12px 16px;
  font-size: 14px;
  color: #203f54;
}
.recent-picker {
  justify-content: space-between;
  margin-bottom: 10px;
}
.recent-picker text {
  min-width: 0;
  overflow-wrap: anywhere;
}
.code-row {
  overflow: hidden;
}
.verify {
  min-width: 52px;
  min-height: var(--login-control-height, 52px);
  margin: 0;
  padding: 0 12px;
  font-size: 14px;
  background: #eaf1f5;
  color: #245b78;
  border-radius: 0;
  border: 0;
}
.verify::after,
.retry::after {
  border: 0;
}
.recent-trigger {
  flex: 0 0 40px;
  align-self: stretch;
}
.recent-arrow {
  display: flex;
  align-items: center;
  justify-content: center;
  height: 100%;
  min-height: var(--login-control-height, 52px);
  color: #245b78;
}
.hint {
  display: block;
  margin-top: 5px;
  color: #6f7f89;
  font-size: 11px;
  line-height: 1.4;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.error {
  display: block;
  align-items: center;
  margin-top: 6px;
  gap: 8px;
  color: #b63737;
  font-size: 11px;
  line-height: 1.4;
}
.retry {
  flex: 0 0 auto;
  margin: 0;
  min-height: 44px;
  padding: 0 10px;
  font-size: 13px;
  color: #245b78;
  background: transparent;
}
</style>
