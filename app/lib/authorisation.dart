// ============================================================
// authorisation.dart — Login & Registration Page
//
// Provides a single page that toggles between two modes:
//   • Login   — email + password → calls AuthService.login()
//   • Register — name (optional) + email + password + repeat
//               → calls AuthService.register(), then auto-logs in
//
// On successful auth the login flag is persisted in
// SharedPreferences so the app remembers the session across
// restarts (see main.dart where this flag is read).
// ============================================================

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/authorisation.dart';

/// The login / registration screen shown to unauthenticated users.
///
/// Uses a [StatefulWidget] because the form toggles between login
/// and register modes and tracks loading state for the submit button.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  /// When true the form renders in login mode; false = register mode.
  bool isLogin = true;

  /// Controls the submit button's loading spinner while an async call
  /// to the backend is in progress — prevents double-submission.
  bool isLoading = false;

  /// Toggle password visibility for the main password field.
  bool _obscurePassword = true;

  /// Toggle password visibility for the "Repeat Password" field
  /// (only shown in register mode).
  bool _obscureRepeat = true;

  // ── Text controllers ──────────────────────────────────────────────
  // Each controller is bound to a TextField and disposed in dispose()
  // to prevent memory leaks.
  final _nameController           = TextEditingController();
  final _emailController          = TextEditingController();
  final _passwordController       = TextEditingController();
  final _repeatPasswordController = TextEditingController();

  /// Service that wraps all HTTP calls to the auth API endpoints.
  final AuthService _authService = AuthService();

  @override
  void dispose() {
    // Must dispose every controller to free up resources when the
    // widget is removed from the tree.
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _repeatPasswordController.dispose();
    super.dispose();
  }

  /// Convenience helper — shows a red SnackBar with [message].
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  // ── Core authentication handler ──────────────────────────────────
  // Called by the "Continue" button. Validates inputs, calls the
  // appropriate AuthService method, persists the login flag on
  // success, and navigates to the dashboard removing all prior routes.
  Future<void> _handleAuth() async {
    final email    = _emailController.text.trim();
    final password = _passwordController.text;

    // Basic guard — both fields must be filled before hitting the API.
    if (email.isEmpty || password.isEmpty) {
      _showErrorSnackBar('Please enter both email and password.');
      return;
    }

    // Show loading spinner on the button while the request is in flight.
    setState(() { isLoading = true; });

    try {
      if (isLogin) {
        // ── Login branch ─────────────────────────────────────────
        // AuthService.login() returns null on success or an error
        // string on failure.
        final error = await _authService.login(email, password);
        if (error == null) {
          // Persist login flag so future launches skip the login screen.
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isLoggedIn', true);

          // Navigate to '/' and remove ALL prior routes from the stack
          // so the back button cannot return to the login page.
          if (mounted) {
            Navigator.of(context).pushNamedAndRemoveUntil(
              '/',
              (Route<dynamic> route) => false,
            );
          }
        } else {
          _showErrorSnackBar(error);
        }
      } else {
        // ── Register branch ──────────────────────────────────────
        final name           = _nameController.text.trim();
        final repeatPassword = _repeatPasswordController.text;

        // Client-side password match check before sending to server.
        if (password != repeatPassword) {
          _showErrorSnackBar('Passwords do not match.');
          setState(() { isLoading = false; });
          return;
        }

        // AuthService.register() creates the account.
        final error = await _authService.register(
          email,
          password,
          name: name.isEmpty ? null : name,
        );

        if (error == null) {
          // Auto-login immediately after a successful registration so
          // the user does not have to re-enter credentials.
          final loginError = await _authService.login(email, password);
          if (loginError == null) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('isLoggedIn', true);
            if (mounted) {
              Navigator.of(context).pushNamedAndRemoveUntil(
                '/',
                (Route<dynamic> route) => false,
              );
            }
          } else {
            _showErrorSnackBar(
                'Registration successful, but auto-login failed: $loginError');
          }
        } else {
          _showErrorSnackBar(error);
        }
      }
    } catch (e) {
      // Catches network errors, timeouts, and unexpected exceptions.
      _showErrorSnackBar('An unexpected error occurred.');
    } finally {
      // Always reset the loading state, even if mounted check is needed.
      if (mounted) {
        setState(() { isLoading = false; });
      }
    }
  }

  // ── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F6FB),
      body: Column(
        children: [
          Expanded(
            child: Center(
              // Scrollable so the layout works on small screens / when
              // the keyboard pushes the form upward.
              child: SingleChildScrollView(
                child: Container(
                  width: 420,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 36, vertical: 48),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        // ignore: deprecated_member_use
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Logo ───────────────────────────────────────
                      Center(
                        child: Image.asset(
                          'assets/images/image.png',
                          width: 200,
                          height: 200,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Center(
                        child: Text(
                          'SimplyServe',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      const SizedBox(height: 1),

                      // ── Mode title — changes with isLogin ──────────
                      Text(
                        isLogin ? 'Sign in' : 'Create Account',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Enter your details to continue',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 32),

                      // ── Name field (register mode only) ────────────
                      // The spread operator with a conditional allows the
                      // field to be inserted into the Column only when in
                      // register mode, keeping the widget tree clean.
                      if (!isLogin) ...[
                        TextField(
                          controller: _nameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Name (optional)',
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(12)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(12)),
                              borderSide: BorderSide(color: Color(0xFF1C2A45)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // ── Email field ────────────────────────────────
                      TextField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email address',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide(color: Color(0xFF1C2A45)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── Password field with visibility toggle ──────
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          border: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide(color: Color(0xFF1C2A45)),
                          ),
                          // Eye icon toggles obscureText via setState
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined),
                            onPressed: () =>
                                setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                      ),

                      // ── Repeat password (register mode only) ───────
                      if (!isLogin) ...[
                        const SizedBox(height: 20),
                        TextField(
                          controller: _repeatPasswordController,
                          obscureText: _obscureRepeat,
                          decoration: InputDecoration(
                            labelText: 'Repeat Password',
                            border: const OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(12)),
                            ),
                            focusedBorder: const OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(12)),
                              borderSide: BorderSide(color: Color(0xFF1C2A45)),
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(_obscureRepeat
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined),
                              onPressed: () =>
                                  setState(() => _obscureRepeat = !_obscureRepeat),
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // ── Submit button ──────────────────────────────
                      // While isLoading is true the button is disabled
                      // (onPressed: null) and shows a spinner instead of
                      // text — prevents double-submission.
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF74BC42),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: isLoading ? null : _handleAuth,
                          child: isLoading
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Continue',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color.fromARGB(255, 0, 0, 0),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // ── Divider row ────────────────────────────────
                      // Two Expanded Dividers with centred text in between
                      // — a common "or" separator pattern.
                      Row(
                        children: [
                          Expanded(
                            child: Divider(
                              // ignore: deprecated_member_use
                              color: Colors.grey.withOpacity(0.4),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              isLogin
                                  ? 'Need an account?'
                                  : 'Already have an account?',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              // ignore: deprecated_member_use
                              color: Colors.grey.withOpacity(0.4),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ── Mode-toggle button ─────────────────────────
                      // Flips isLogin via setState, which causes the
                      // conditional fields and button labels above to
                      // update reactively without a page navigation.
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF74BC42)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () {
                            setState(() {
                              isLogin = !isLogin;
                            });
                          },
                          child: Text(
                            isLogin ? 'Create an account' : 'Log in instead',
                            style: const TextStyle(
                              color: Color.fromARGB(255, 0, 0, 0),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
