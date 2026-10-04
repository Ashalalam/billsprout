import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../config/app_theme.dart';

/// AuthGuard widget ensures only authenticated users with specific roles can access protected routes.
/// 
/// Usage:
/// ```dart
/// AuthGuard(
///   allowedRoles: [UserRole.superAdmin],
///   child: const SuperAdminDashboard(),
/// )
/// ```
/// 
/// This widget:
/// 1. Checks if user is authenticated
/// 2. Verifies user has one of the allowed roles
/// 3. Revalidates role from database on each navigation
/// 4. Shows loading state during validation
/// 5. Shows access denied screen if unauthorized
class AuthGuard extends StatelessWidget {
  final List<UserRole> allowedRoles;
  final Widget child;
  final Widget? fallback;
  final bool revalidate;

  const AuthGuard({
    super.key,
    required this.allowedRoles,
    required this.child,
    this.fallback,
    this.revalidate = true,
  });

  Future<AuthorizationResult> _checkAuthorization(BuildContext context) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);

    // Check if logged in
    if (!auth.isLoggedIn) {
      return AuthorizationResult.notAuthenticated;
    }

    // Check if role is allowed
    if (!allowedRoles.contains(auth.currentUser!.role)) {
      return AuthorizationResult.forbidden;
    }

    // Revalidate role from database if requested
    if (revalidate) {
      final valid = await auth.revalidateRole();
      if (!valid) {
        return AuthorizationResult.invalidSession;
      }

      // Check again after revalidation (role might have changed)
      if (!allowedRoles.contains(auth.currentUser!.role)) {
        return AuthorizationResult.forbidden;
      }
    }

    return AuthorizationResult.authorized;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AuthorizationResult>(
      future: _checkAuthorization(context),
      builder: (context, snapshot) {
        // Show loading while checking authorization
        if (!snapshot.hasData) {
          return const _LoadingScreen();
        }

        final result = snapshot.data!;

        switch (result) {
          case AuthorizationResult.authorized:
            return child;

          case AuthorizationResult.notAuthenticated:
            // User not logged in - logout and show login screen
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Provider.of<AuthProvider>(context, listen: false).logout();
            });
            return const _LoadingScreen();

          case AuthorizationResult.invalidSession:
            // Session invalid - logout and show login screen
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Provider.of<AuthProvider>(context, listen: false).logout();
            });
            return const _LoadingScreen();

          case AuthorizationResult.forbidden:
            // User is authenticated but doesn't have permission
            return fallback ?? const _AccessDeniedScreen();
        }
      },
    );
  }
}

enum AuthorizationResult {
  authorized,
  notAuthenticated,
  invalidSession,
  forbidden,
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Verifying authorization...',
              style: TextStyle(color: AppTheme.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccessDeniedScreen extends StatelessWidget {
  const _AccessDeniedScreen();

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Access Denied'),
        backgroundColor: AppTheme.errorRed,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.block,
                size: 80,
                color: AppTheme.errorRed,
              ),
              const SizedBox(height: 24),
              const Text(
                'Access Denied',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'You do not have permission to access this area.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.textMuted,
                ),
              ),
              const SizedBox(height: 8),
              if (auth.currentUser != null)
                Text(
                  'Current role: ${auth.currentUser!.roleDisplay}',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textMuted,
                  ),
                ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  auth.logout();
                },
                icon: const Icon(Icons.logout),
                label: const Text('Sign Out'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
