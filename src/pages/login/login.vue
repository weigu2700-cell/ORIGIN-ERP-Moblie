<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useUserStore } from '@/stores/user';

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
const username = ref('');
const password = ref('');
const loading = ref(false);
const sessionChecking = ref(false);
const errorMessage = ref('');

const usernameError = computed(() => errorMessage.value === '请输入账号');
const passwordError = computed(() => errorMessage.value === '请输入密码');
const requestError = computed(() =>
  usernameError.value || passwordError.value ? '' : errorMessage.value,
);

onMounted(async () => {
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
    await userStore.login({ username: username.value.trim(), password: password.value });
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
              <text class="subtitle">使用企业 ERP 账号进入移动工作台</text>
            </view>

            <view class="form-area">
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
                  custom-style="min-height: 56px; padding: 0 16px; border: 1px solid #d6e0e6; border-radius: 12px; background: #ffffff;"
                  @input="clearError"
                />
                <text v-if="usernameError" class="field-error">请输入账号后继续</text>
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
                  custom-style="min-height: 56px; padding: 0 16px; border: 1px solid #d6e0e6; border-radius: 12px; background: #ffffff;"
                  @input="clearError"
                  @confirm="submitLogin"
                />
                <text v-if="passwordError" class="field-error">请输入密码后继续</text>
              </view>

              <wd-notice-bar
                v-if="requestError"
                type="danger"
                prefix="warning"
                wrapable
                :scrollable="false"
                :text="requestError"
                custom-style="margin-top: 16px; border-radius: 8px;"
              />

              <wd-button
                type="primary"
                size="large"
                block
                :round="false"
                :loading="loading || sessionChecking"
                :disabled="loading || sessionChecking"
                aria-label="登录并进入移动工作台"
                custom-style="margin-top: 28px;"
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
  --page-gutter: 28px;

  min-height: 100dvh;
  background: #18384b;
}

.login-layout {
  width: 100%;
  min-height: 100dvh;
  display: flex;
  flex-direction: column;
}

.login-visual {
  position: relative;
  min-height: 218px;
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
  bottom: 24px;
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
  margin-top: 9px;
  font-size: 27px;
  font-weight: 700;
  line-height: 1.2;
}

.visual-accent {
  color: #f2c16a;
}

.visual-description {
  max-width: 310px;
  margin-top: 8px;
  color: #d5e1e6;
  font-size: 13px;
  line-height: 1.5;
}

.login-form-panel {
  flex: 1;
  background: var(--color-canvas);
}

.login-shell {
  width: 100%;
  max-width: 440px;
  min-height: 0;
  margin: 0 auto;
  padding: 24px var(--page-gutter) calc(env(safe-area-inset-bottom) + 24px);
  box-sizing: border-box;
}

.brand {
  display: flex;
  align-items: center;
}

.brand-logo {
  width: 48px;
  height: 48px;
}

.brand-copy {
  margin-left: 14px;
}

.brand-name,
.brand-product,
.title,
.subtitle,
.field-label,
.field-error,
.help,
.footer {
  display: block;
}

.brand-name {
  color: var(--color-brand);
  font-size: 20px;
  font-weight: 650;
  line-height: 1.2;
}

.brand-product {
  margin-top: 5px;
  color: var(--color-text-secondary);
  font-size: 12px;
  letter-spacing: 1px;
}

.heading {
  position: relative;
  margin-top: 34px;
  padding-left: 16px;
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
  font-size: 32px;
  font-weight: 650;
  line-height: 1.2;
}

.subtitle {
  margin-top: 10px;
  color: var(--color-text-secondary);
  font-size: 15px;
  line-height: 1.5;
}

.form-area {
  margin-top: 34px;
}

.field + .field {
  margin-top: 22px;
}

.field-label {
  margin-bottom: 9px;
  color: var(--color-text);
  font-size: 14px;
  font-weight: 550;
}

.field-error {
  margin: 7px 4px 0;
  color: var(--color-danger);
  font-size: 12px;
  line-height: 1.4;
}

.help {
  margin-top: 24px;
  color: var(--color-text-secondary);
  font-size: 13px;
  text-align: center;
}

.footer {
  margin-top: 38px;
  color: var(--color-text-muted);
  font-size: 11px;
  letter-spacing: 1.4px;
  text-align: center;
}

@media screen and (max-height: 650px) {
  .login-visual {
    min-height: 176px;
  }
  .heading {
    margin-top: 28px;
  }
  .form-area {
    margin-top: 32px;
  }
  .footer {
    margin-top: 36px;
  }
}

@media screen and (min-width: 760px) {
  .login-layout {
    max-width: 1040px;
    min-height: 680px;
    margin: 0 auto;
    flex-direction: row;
    background: var(--color-canvas);
    box-shadow: 0 24px 70px rgba(12, 39, 54, 0.2);
  }

  .login-page {
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 28px;
  }

  .login-visual,
  .login-form-panel {
    flex: 1;
  }

  .login-visual {
    min-height: 680px;
  }
  .visual-copy {
    right: 38px;
    bottom: 40px;
    left: 38px;
  }
  .visual-title {
    font-size: 34px;
  }
  .login-form-panel {
    display: flex;
    align-items: center;
  }
  .login-shell {
    padding: 46px 54px;
  }
  .heading {
    margin-top: 58px;
  }
  .form-area {
    margin-top: 42px;
  }
  .footer {
    margin-top: 52px;
  }
}
</style>
