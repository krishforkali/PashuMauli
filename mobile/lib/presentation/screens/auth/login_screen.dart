import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pashumauli/routing/app_router.dart';
import 'package:pashumauli/services/auth_notifier.dart';
import 'package:pashumauli/data/remote/api_client.dart';

/// API client provider — baseUrl from environment/config.
/// In development: set to local backend URL.
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient(
      baseUrl: const String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'http://10.0.2.2:8000', // Android emulator → host localhost
      ),
    ));

/// Screen 3 — Login / Registration
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();

  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _regPhoneController = TextEditingController();
  final _regPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _loading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _regPhoneController.dispose();
    _regPasswordController.dispose();
    super.dispose();
  }

  String? _validatePhone(String? v) {
    if (v == null || v.isEmpty) return 'Phone number is required';
    if (v.length < 10) return 'Enter a valid 10-digit phone number';
    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Password is required';
    if (v.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  String? _validateName(String? v) {
    if (v == null || v.trim().isEmpty) return 'Name cannot be empty';
    return null;
  }

  Future<void> _login() async {
    if (!_loginFormKey.currentState!.validate()) return;
    setState(() { _loading = true; _errorMessage = null; });

    final api = ref.read(apiClientProvider);
    final response = await api.login(
      phone: _phoneController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;

    if (response.isSuccess && response.data != null) {
      final data = response.data!;
      await ref.read(authNotifierProvider.notifier).login(
        accessToken: data['access_token'] as String? ?? '',
        refreshToken: data['refresh_token'] as String? ?? '',
        userId: (data['user'] as Map<String, dynamic>?)?['id'] as String? ?? '',
        role: (data['user'] as Map<String, dynamic>?)?['role'] as String? ?? 'FARMER',
        name: (data['user'] as Map<String, dynamic>?)?['name'] as String? ?? '',
        phone: _phoneController.text.trim(),
      );
      if (mounted) context.go(AppRoutes.home);
    } else {
      setState(() {
        _errorMessage = response.isNetworkError
            ? 'Network error — check connection'
            : response.errorMessage ?? 'Login failed';
        _loading = false;
      });
    }
  }

  Future<void> _register() async {
    if (!_registerFormKey.currentState!.validate()) return;
    setState(() { _loading = true; _errorMessage = null; });

    final api = ref.read(apiClientProvider);
    final response = await api.register(
      name: _nameController.text.trim(),
      phone: _regPhoneController.text.trim(),
      password: _regPasswordController.text,
      role: 'FARMER',
    );

    if (!mounted) return;

    if (response.isSuccess && response.data != null) {
      // After register, log in automatically
      final loginResp = await api.login(
        phone: _regPhoneController.text.trim(),
        password: _regPasswordController.text,
      );
      if (loginResp.isSuccess && loginResp.data != null) {
        final data = loginResp.data!;
        await ref.read(authNotifierProvider.notifier).login(
          accessToken: data['access_token'] as String? ?? '',
          refreshToken: data['refresh_token'] as String? ?? '',
          userId: (data['user'] as Map<String, dynamic>?)?['id'] as String? ?? '',
          role: (data['user'] as Map<String, dynamic>?)?['role'] as String? ?? 'FARMER',
          name: _nameController.text.trim(),
          phone: _regPhoneController.text.trim(),
        );
        if (mounted) context.go(AppRoutes.home);
        return;
      }
      // Registration succeeded but auto-login failed — go to login tab
      if (mounted) {
        _tabController.animateTo(0);
        setState(() { _loading = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registered! Please log in.')),
        );
      }
    } else {
      setState(() {
        _errorMessage = response.isNetworkError
            ? 'Network error — check connection'
            : response.errorMessage ?? 'Registration failed';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F8E9),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              const Text(
                'PashuMauli',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B5E20),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Livestock Health Surveillance',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 32),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Column(
                  children: [
                    TabBar(
                      controller: _tabController,
                      labelColor: const Color(0xFF2E7D32),
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: const Color(0xFF2E7D32),
                      tabs: const [
                        Tab(text: 'Login'),
                        Tab(text: 'Register'),
                      ],
                    ),
                    if (_errorMessage != null)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),
                    SizedBox(
                      height: 340,
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _LoginForm(
                            formKey: _loginFormKey,
                            phoneController: _phoneController,
                            passwordController: _passwordController,
                            obscurePassword: _obscurePassword,
                            loading: _loading,
                            onToggleObscure: () =>
                                setState(() => _obscurePassword = !_obscurePassword),
                            onValidatePhone: _validatePhone,
                            onValidatePassword: _validatePassword,
                            onSubmit: _login,
                          ),
                          _RegisterForm(
                            formKey: _registerFormKey,
                            nameController: _nameController,
                            phoneController: _regPhoneController,
                            passwordController: _regPasswordController,
                            loading: _loading,
                            onValidateName: _validateName,
                            onValidatePhone: _validatePhone,
                            onValidatePassword: _validatePassword,
                            onSubmit: _register,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoginForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController phoneController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final bool loading;
  final VoidCallback onToggleObscure;
  final String? Function(String?) onValidatePhone;
  final String? Function(String?) onValidatePassword;
  final VoidCallback onSubmit;

  const _LoginForm({
    required this.formKey,
    required this.phoneController,
    required this.passwordController,
    required this.obscurePassword,
    required this.loading,
    required this.onToggleObscure,
    required this.onValidatePhone,
    required this.onValidatePassword,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextFormField(
              controller: phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
              validator: onValidatePhone,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: passwordController,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    obscurePassword ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: onToggleObscure,
                ),
              ),
              obscureText: obscurePassword,
              validator: onValidatePassword,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => onSubmit(),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: loading ? null : onSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Login',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RegisterForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController passwordController;
  final bool loading;
  final String? Function(String?) onValidateName;
  final String? Function(String?) onValidatePhone;
  final String? Function(String?) onValidatePassword;
  final VoidCallback onSubmit;

  const _RegisterForm({
    required this.formKey,
    required this.nameController,
    required this.phoneController,
    required this.passwordController,
    required this.loading,
    required this.onValidateName,
    required this.onValidatePhone,
    required this.onValidatePassword,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextFormField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
              validator: onValidateName,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
              validator: onValidatePhone,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock_outline),
                border: OutlineInputBorder(),
              ),
              obscureText: true,
              validator: onValidatePassword,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => onSubmit(),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: loading ? null : onSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Register',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
