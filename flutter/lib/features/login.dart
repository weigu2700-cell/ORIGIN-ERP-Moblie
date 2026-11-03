import 'package:flutter/material.dart';

import '../core/session.dart';
import '../ui/common.dart';
import '../ui/theme.dart';

class LoginPage extends StatefulWidget {
  final Session session;
  const LoginPage(this.session, {super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final form = GlobalKey<FormState>();
  final tenant = TextEditingController(),
      username = TextEditingController(),
      password = TextEditingController();
  Json? configuration;
  String? error;
  bool loading = true, busy = false, obscure = true;
  @override
  void initState() {
    super.initState();
    initialize();
  }

  Future<void> initialize() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final config =
          await widget.session.api.call('/auth/tenant/context', auth: false)
              as Json;
      if (!mounted) return;
      setState(() {
        configuration = config;
        if (config['mode'] == 'single') {
          tenant.text = config['organization']?['code']?.toString() ?? '';
        }
      });
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> submit() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.session.api.call(
        '/auth/tenant/resolve',
        method: 'POST',
        body: {'tenantCode': tenant.text.trim()},
        auth: false,
      );
      if (!mounted) return;
      await widget.session.login(
        tenant.text.trim(),
        username.text.trim(),
        password.text,
      );
      password.clear();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    tenant.dispose();
    username.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: AutofillGroup(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.all(28),
              children: [
                const SizedBox(height: 40),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: CircleAvatar(
                    radius: 26,
                    backgroundColor: AppTokens.brand,
                    child: Text(
                      '原',
                      style: TextStyle(color: Colors.white, fontSize: 24),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  '登录原点智造',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '连接团队，专注现场作业',
                  style: TextStyle(color: AppTokens.muted),
                ),
                const SizedBox(height: 32),
                if (loading) const LinearProgressIndicator(),
                Form(
                  key: form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      GroupCard(
                        margin: EdgeInsets.zero,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: tenant,
                              readOnly:
                                  configuration?['mode'] == 'single' || busy,
                              decoration: InputDecoration(
                                filled: false,
                                contentPadding: const EdgeInsets.fromLTRB(
                                  16,
                                  22,
                                  16,
                                  12,
                                ),
                                hintText: '组织编码',
                                suffixText:
                                    configuration?['organization']?['name']
                                        ?.toString(),
                              ),
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? '请输入组织编码'
                                  : null,
                            ),
                            const Divider(indent: 16),
                            TextFormField(
                              controller: username,
                              enabled: !busy,
                              autofillHints: const [AutofillHints.username],
                              decoration: const InputDecoration(
                                filled: false,
                                contentPadding: const EdgeInsets.fromLTRB(
                                  16,
                                  22,
                                  16,
                                  12,
                                ),
                                hintText: '账号',
                              ),
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? '请输入账号'
                                  : null,
                            ),
                            const Divider(indent: 16),
                            TextFormField(
                              controller: password,
                              enabled: !busy,
                              obscureText: obscure,
                              autofillHints: const [AutofillHints.password],
                              decoration: InputDecoration(
                                filled: false,
                                contentPadding: const EdgeInsets.fromLTRB(
                                  16,
                                  22,
                                  16,
                                  12,
                                ),
                                hintText: '密码',
                                suffixIcon: IconButton(
                                  tooltip: obscure ? '显示密码' : '隐藏密码',
                                  onPressed: () =>
                                      setState(() => obscure = !obscure),
                                  icon: Icon(
                                    obscure
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                              ),
                              validator: (v) =>
                                  v == null || v.isEmpty ? '请输入密码' : null,
                              onFieldSubmitted: (_) => submit(),
                            ),
                          ],
                        ),
                      ),
                      if (widget.session.error != null) ...[
                        Text(
                          widget.session.error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        TextButton(
                          onPressed: widget.session.logout,
                          child: const Text('重试清除本机凭据'),
                        ),
                      ],
                      if (error != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Semantics(
                            liveRegion: true,
                            child: Text(
                              error!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        ),
                      if (configuration == null && !loading)
                        TextButton(
                          onPressed: initialize,
                          child: const Text('重新加载组织配置'),
                        ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: busy || loading || configuration == null
                            ? null
                            : submit,
                        child: Text(busy ? '正在登录…' : '登录'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
