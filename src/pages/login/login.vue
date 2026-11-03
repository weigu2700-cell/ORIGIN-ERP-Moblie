<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useUserStore } from '@/stores/user';
import { useOrganizationStore } from '@/stores/organization';
import OrganizationPicker from '@/components/organization/OrganizationPicker.vue';

const themeVars = {
  colorTheme: '#245b78',
  colorDanger: '#c94444',
  buttonLargeHeight: '56px',
  buttonLargeRadius: '12px',
  inputCellHeight: '56px',
  inputInnerHeight: '56px',
  inputInnerHeightNoBorder: '56px',
};

const userStore = useUserStore();
const organizations = useOrganizationStore();
const username = ref('');
const password = ref('');
const loading = ref(false);
const sessionChecking = ref(false);
const errorMessage = ref('');

const usernameError = computed(() => errorMessage.value === '请输入账号');
const passwordError = computed(() => errorMessage.value === '请输入密码');

onMounted(async () => {
  await organizations.initialize();
  userStore.restoreSession();
  if (!userStore.hasToken) return;

  sessionChecking.value = true;
  try {
    const authenticated = await userStore.validateSession(true);
    if (authenticated) await uni.switchTab({ url: '/pages/workbench/index' });
  } catch {
    errorMessage.value = '暂时无法验证已有会话，可检查网络后重试或重新登录';
  } finally {
    sessionChecking.value = false;
  }
});

function clearError() {
  errorMessage.value = '';
}

async function submitLogin() {
  if (loading.value || sessionChecking.value) return;
  if (!username.value.trim()) {
    errorMessage.value = '请输入账号';
    return;
  }
  if (!password.value) {
    errorMessage.value = '请输入密码';
    return;
  }

  loading.value = true;
  try {
    if (!organizations.configuration) throw new Error('请先重试加载组织信息');
    const organization = await organizations.verify();
    await userStore.login({
      tenantCode: organization.code,
      username: username.value.trim(),
      password: password.value,
    });
    uni.switchTab({ url: '/pages/workbench/index' });
  } catch (error) {
    const message = error instanceof Error ? error.message : '登录失败';
    errorMessage.value = message.includes('重试') ? message : `${message}，请检查后重试`;
  } finally {
    loading.value = false;
  }
}
</script>

<template>
  <wd-config-provider :theme-vars="themeVars">
    <view class="login-page">
      <view class="login-layout">
        <view class="login-visual">
          <image
            class="visual-image"
            src="/static/manufacturing-login-bg.jpg"
            mode="aspectFill"
            aria-hidden="true"
          />
          <view class="visual-overlay" />
          <view class="visual-copy">
            <text class="visual-kicker">ORIGIN MANUFACTURING</text>
            <text class="visual-title">让现场作业，<text class="visual-accent">更清楚</text></text>
            <text class="visual-description">从入库到生产，每一笔业务都在同一个工作台里流动。</text>
          </view>
        </view>

        <view class="login-form-panel">
          <view class="login-shell">
            <view class="brand">
              <image
                class="brand-logo"
                src="/static/origin-manufacturing-logo.svg"
                mode="aspectFit"
                aria-hidden="true"
              />
              <view class="brand-copy">
                <text class="brand-name">原点智造</text>
                <text class="brand-product">移动 ERP · PDA</text>
              </view>
            </view>

            <view class="heading">
              <view class="heading-mark" />
              <text class="title">欢迎登录</text>
              <text class="subtitle">选择组织，使用该组织的账号登录</text>
            </view>

            <view class="form-area">
              <OrganizationPicker
                :disabled="loading || sessionChecking"
                @change="
                  password = '';
                  clearError();
                "
              />
              <view class="field">
                <text class="field-label">账号</text>
                <wd-input
                  v-model="username"
                  prefix-icon="user"
                  placeholder="请输入账号"
                  confirm-type="next"
                  size="large"
                  clearable
                  no-border
                  aria-label="账号"
                  :maxlength="50"
                  :error="usernameError"
                  :disabled="loading || sessionChecking"
                  custom-style="min-height: var(--login-control-height, 52px); padding: 0 16px; border: 1px solid #d6e0e6; border-radius: 12px; background: #ffffff;"
                  @input="clearError"
                />
              </view>

              <view class="field">
                <text class="field-label">密码</text>
                <wd-input
                  v-model="password"
                  prefix-icon="lock-on"
                  placeholder="请输入密码"
                  confirm-type="done"
                  size="large"
                  show-password
                  no-border
                  aria-label="密码"
                  :maxlength="64"
                  :error="passwordError"
                  :disabled="loading || sessionChecking"
                  custom-style="min-height: var(--login-control-height, 52px); padding: 0 16px; border: 1px solid #d6e0e6; border-radius: 12px; background: #ffffff;"
                  @input="clearError"
                  @confirm="submitLogin"
                />
              </view>

              <view class="login-feedback" aria-live="polite"
                ><text v-if="errorMessage" role="alert">{{ errorMessage }}</text></view
              >

              <wd-button
                type="primary"
                size="large"
                block
                :round="false"
                role="button"
                :loading="loading || sessionChecking"
                :disabled="
                  loading ||
                  sessionChecking ||
                  organizations.initializing ||
                  !organizations.configuration ||
                  organizations.loading
                "
                aria-label="登录并进入移动工作台"
                custom-style="margin-top: 6px;"
                @click="submitLogin"
              >
                {{ sessionChecking ? '正在验证会话' : loading ? '正在登录' : '登录' }}
              </wd-button>

              <text class="help">无法登录？请联系系统管理员</text>
            </view>

            <text class="footer">ORIGIN MANUFACTURING · MOBILE</text>
          </view>
        </view>
      </view>
    </view>
  </wd-config-provider>
</template>

<style scoped>
.login-page {
  --color-brand: #203f54;
  --color-accent: #d99a2b;
  --color-canvas: #f4f7f9;
  --color-text: #162631;
  --color-text-secondary: #6f7f89;
  --color-text-muted: #98a4ac;
  --color-danger: #c94444;
  --page-gutter: 24px;
  --login-control-height: 52px;
  --login-field-gap: 16px;
  --wot-input-cell-height: var(--login-control-height);
  --wot-input-inner-height: var(--login-control-height);
  --wot-input-inner-height-no-border: var(--login-control-height);
  --wot-button-large-height: var(--login-control-height);
  height: 100dvh;
  overflow: hidden;
  background: #18384b;
}
.login-layout {
  width: 100%;
  height: 100%;
  min-height: 0;
  display: flex;
  flex-direction: column;
}
.login-visual {
  position: relative;
  flex: 0 0 clamp(96px, 16dvh, 150px);
  min-height: 0;
  overflow: hidden;
  background: #203f54;
}
.visual-image,
.visual-overlay {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
}
.visual-image {
  opacity: 0.72;
}
.visual-overlay {
  background: linear-gradient(180deg, rgba(18, 47, 64, 0.18), rgba(18, 47, 64, 0.92));
}
.visual-copy {
  position: absolute;
  right: 24px;
  bottom: 18px;
  left: 24px;
  color: #fff;
}
.visual-kicker,
.visual-title,
.visual-description {
  display: block;
}
.visual-kicker {
  color: #d2e0e6;
  font-size: 10px;
  letter-spacing: 1.4px;
}
.visual-title {
  margin-top: 7px;
  font-size: 25px;
  font-weight: 700;
  line-height: 1.2;
}
.visual-accent {
  color: #f2c16a;
}
.visual-description {
  display: none;
}
.login-form-panel {
  flex: 1;
  display: flex;
  align-items: center;
  min-height: 0;
  background: var(--color-canvas);
}
.login-shell {
  width: 100%;
  max-width: 440px;
  margin: 0 auto;
  padding: 18px var(--page-gutter) max(16px, env(safe-area-inset-bottom));
  box-sizing: border-box;
}
.brand {
  display: flex;
  align-items: center;
}
.brand-logo {
  width: 38px;
  height: 38px;
}
.brand-copy {
  margin-left: 12px;
}
.brand-name,
.brand-product,
.title,
.subtitle,
.field-label,
.help {
  display: block;
}
.brand-name {
  color: var(--color-brand);
  font-size: 18px;
  font-weight: 650;
  line-height: 1.2;
}
.brand-product {
  margin-top: 4px;
  color: var(--color-text-secondary);
  font-size: 11px;
  letter-spacing: 1px;
}
.heading {
  position: relative;
  margin-top: 18px;
  padding-left: 14px;
}
.heading-mark {
  position: absolute;
  top: 3px;
  bottom: 3px;
  left: 0;
  width: 4px;
  border-radius: 2px;
  background: var(--color-accent);
}
.title {
  color: var(--color-text);
  font-size: 27px;
  font-weight: 650;
  line-height: 1.2;
}
.subtitle {
  margin-top: 6px;
  color: var(--color-text-secondary);
  font-size: 12px;
  line-height: 1.5;
}
.form-area {
  margin-top: 20px;
}
.field + .field {
  margin-top: var(--login-field-gap);
}
.field-label {
  margin-bottom: 6px;
  color: var(--color-text);
  font-size: 13px;
  font-weight: 550;
}
.login-feedback {
  min-height: 32px;
  margin-top: 7px;
  color: var(--color-danger);
  font-size: 12px;
  line-height: 16px;
}
.help {
  margin-top: 14px;
  color: var(--color-text-secondary);
  font-size: 12px;
  text-align: center;
}
.footer {
  display: none;
}
@media (max-height: 740px) and (max-width: 759px) {
  .login-visual {
    display: none;
  }
  .login-page {
    --login-control-height: 48px;
    --login-field-gap: 12px;
  }
  .heading {
    margin-top: 14px;
  }
  .form-area {
    margin-top: 18px;
  }
}
@media (max-height: 620px) {
  .login-page {
    --page-gutter: 20px;
  }
  .login-shell {
    padding-top: 12px;
    padding-bottom: max(12px, env(safe-area-inset-bottom));
  }
  .brand-logo {
    width: 32px;
    height: 32px;
  }
  .brand-product,
  .subtitle,
  .help {
    display: none;
  }
  .title {
    font-size: 25px;
  }
  .heading {
    margin-top: 12px;
  }
  .form-area {
    margin-top: 14px;
  }
}
@media (min-width: 760px) {
  .login-page {
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 24px;
    box-sizing: border-box;
  }
  .login-layout {
    max-width: 1040px;
    height: min(720px, 100%);
    flex-direction: row;
    box-shadow: 0 24px 70px rgba(12, 39, 54, 0.2);
  }
  .login-visual {
    flex: 1;
  }
  .visual-copy {
    right: 32px;
    left: 32px;
    bottom: 36px;
  }
  .visual-title {
    font-size: 32px;
  }
  .visual-description {
    display: block;
    margin-top: 12px;
    font-size: 13px;
    color: #d5e1e6;
    line-height: 1.6;
  }
  .login-form-panel {
    flex: 1;
  }
  .login-shell {
    padding-left: 36px;
    padding-right: 36px;
  }
}
</style>
