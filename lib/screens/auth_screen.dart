import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/api_exceptions.dart';
import '../state/auth_notifier.dart';
import '../validation/validators.dart';

class AuthScreen extends StatefulWidget {
  final bool register;
  final String? from;
  const AuthScreen({super.key, this.register = false, this.from});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _fields = {
    for (final key in ['fullName', 'username', 'email', 'password', 'confirm'])
      key: TextEditingController(),
  };
  final _errors = <String, String>{};
  bool _busy = false;
  bool _visible = false;
  bool _submitted = false;
  String? _problem;
  Future<void> _submit() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _submitted = true;
      _errors.clear();
      _problem = null;
    });
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final auth = context.read<AuthNotifier>();
    try {
      if (widget.register) {
        await auth.register({
          'fullName': _fields['fullName']!.text.trim(),
          'username': _fields['username']!.text.trim(),
          'email': _fields['email']!.text.trim().toLowerCase(),
          'password': _fields['password']!.text,
        });
      } else {
        await auth.login(_fields['username']!.text, _fields['password']!.text);
      }
    } on ValidationException catch (e) {
      if (mounted) {
        setState(() {
          _errors.addAll(e.errors);
          _problem = e.message;
        });
      }
      _form.currentState?.validate();
    } on ApiException catch (e) {
      if (mounted) setState(() => _problem = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _problem = 'Не удалось выполнить вход. Повторите попытку.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _validate(String key, String? value) {
    if (_errors.containsKey(key)) return _errors[key];
    return switch (key) {
      'email' => Validators.email(value),
      'fullName' => Validators.text(value, min: 2, max: 200),
      'username' => Validators.text(
        value,
        min: widget.register ? 3 : 1,
        max: 80,
      ),
      'password' =>
        widget.register
            ? Validators.password(value)
            : Validators.text(value, max: 200),
      'confirm' =>
        value != _fields['password']!.text || (value ?? '').isEmpty
            ? 'Пароли должны совпадать'
            : null,
      _ => null,
    };
  }

  Widget _field(String key, String label, {bool password = false}) => Padding(
    padding: const EdgeInsets.only(top: 14),
    child: TextFormField(
      key: ValueKey(key),
      controller: _fields[key],
      enabled: !_busy,
      obscureText: password && !_visible,
      keyboardType: key == 'email'
          ? TextInputType.emailAddress
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: password && key == 'password'
            ? IconButton(
                onPressed: () => setState(() => _visible = !_visible),
                tooltip: _visible ? 'Скрыть пароль' : 'Показать пароль',
                icon: Icon(
                  _visible
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              )
            : null,
      ),
      validator: (v) => _validate(key, v),
      onChanged: (_) {
        setState(() {
          _errors.remove(key);
          _problem = null;
        });
        if (_submitted) _form.currentState?.validate();
      },
      onFieldSubmitted: (_) {
        if (key == 'confirm' || key == 'password' && !widget.register) {
          _submit();
        }
      },
    ),
  );
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: 440,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Form(
                    key: _form,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(Icons.local_library_outlined, size: 34),
                        const SizedBox(height: 14),
                        Text(
                          widget.register ? 'Регистрация' : 'Вход в библиотеку',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.register
                              ? 'Создайте учётную запись читателя'
                              : 'Введите логин и пароль',
                          textAlign: TextAlign.center,
                        ),
                        if (auth.notice != null && !widget.register)
                          Padding(
                            padding: const EdgeInsets.only(top: 18),
                            child: Text(
                              auth.notice!,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        if (widget.register)
                          _field('fullName', 'Имя и фамилия'),
                        _field('username', 'Логин'),
                        if (widget.register)
                          _field('email', 'Электронная почта'),
                        _field('password', 'Пароль', password: true),
                        if (widget.register) ...[
                          const SizedBox(height: 10),
                          for (final rule in Validators.passwordRules(
                            _fields['password']!.text,
                          ).entries)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                children: [
                                  Icon(
                                    rule.value
                                        ? Icons.check_circle_outline
                                        : Icons.radio_button_unchecked,
                                    size: 17,
                                    color: rule.value
                                        ? Colors.green.shade700
                                        : Colors.grey,
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      rule.key,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          _field('confirm', 'Повторите пароль', password: true),
                        ],
                        if (_problem != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Text(
                              _problem!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        const SizedBox(height: 22),
                        FilledButton(
                          onPressed: _busy ? null : _submit,
                          child: Text(
                            _busy
                                ? 'Подождите…'
                                : widget.register
                                ? 'Зарегистрироваться'
                                : 'Войти',
                          ),
                        ),
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => context.go(
                                  Uri(
                                    path: widget.register
                                        ? '/login'
                                        : '/register',
                                    queryParameters: {
                                      if (widget.from != null)
                                        'from': widget.from!,
                                    },
                                  ).toString(),
                                ),
                          child: Text(
                            widget.register
                                ? 'Уже есть аккаунт? Войти'
                                : 'Создать аккаунт',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }
}
