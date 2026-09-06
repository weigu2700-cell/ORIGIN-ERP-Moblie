<script setup lang="ts">
import { computed, onMounted, ref } from "vue";
import { useUserStore } from "@/stores/user";

const themeVars = {
  colorTheme: "#245b78",
  colorDanger: "#c94444",
  buttonLargeHeight: "56px",
  buttonLargeRadius: "12px",
  inputCellHeight: "56px",
  inputInnerHeight: "56px",
  inputInnerHeightNoBorder: "56px",
};

const userStore = useUserStore();
const username = ref("");
const password = ref("");
const loading = ref(false);
const errorMessage = ref("");

const usernameError = computed(() => errorMessage.value === "请输入账号");
const passwordError = computed(() => errorMessage.value === "请输入密码");
const requestError = computed(() =>
  usernameError.value || passwordError.value ? "" : errorMessage.value,
);

onMounted(() => {
  userStore.restoreSession();
  if (userStore.isLoggedIn) uni.switchTab({ url: "/pages/workbench/index" });
});

function clearError() {
  errorMessage.value = "";
}

async function submitLogin() {
  if (loading.value) return;
  if (!username.value.trim()) {
    errorMessage.value = "请输入账号";
    return;
  }
  if (!password.value) {
    errorMessage.value = "请输入密码";
    return;
  }

  loading.value = true;
  try {
    await userStore.login({ username: username.value.trim(), password: password.value });
    uni.switchTab({ url: "/pages/workbench/index" });
  } catch (error) {
    const message = error instanceof Error ? error.message : "登录失败";
    errorMessage.value = message.includes("重试") ? message : `${message}，请检查后重试`;
  } finally {
    loading.value = false;
  }
}
</script>

<template>
  <wd-config-provider :theme-vars="themeVars">
    <view class="login-page">
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
              :disabled="loading"
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
              :disabled="loading"
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
            :loading="loading"
            :disabled="loading"
            aria-label="登录并进入移动工作台"
            custom-style="margin-top: 28px;"
            @click="submitLogin"
          >
            {{ loading ? "正在登录" : "登录" }}
          </wd-button>

          <text class="help">无法登录？请联系系统管理员</text>
        </view>

        <text class="footer">ORIGIN MANUFACTURING · MOBILE</text>
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

  min-height: 100vh;
  background: var(--color-canvas);
}

.login-shell {
  width: 100%;
  max-width: 440px;
  min-height: 100vh;
  margin: 0 auto;
  padding: calc(env(safe-area-inset-top) + 28px) var(--page-gutter) calc(env(safe-area-inset-bottom) + 24px);
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
  margin-top: 64px;
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
  margin-top: 44px;
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
  margin-top: 54px;
  color: var(--color-text-muted);
  font-size: 11px;
  letter-spacing: 1.4px;
  text-align: center;
}

@media screen and (max-height: 650px) {
  .heading { margin-top: 40px; }
  .form-area { margin-top: 32px; }
  .footer { margin-top: 36px; }
}
</style>
