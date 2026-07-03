import 'dart:convert';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';

import 'layout/app_shell.dart';
import 'l10n/generated/app_localizations.dart';
import 'domain/models/note.dart';
import 'pages/editor_page.dart';
import 'pages/note_window_page.dart';
import 'pages/notes_page.dart';
import 'pages/reminder_page.dart';
import 'pages/repo_page.dart';
import 'pages/settings_page.dart';
import 'pages/token_help_page.dart';
import 'providers/git_provider.dart';
import 'providers/notes_provider.dart';
import 'providers/reminder_provider.dart';
import 'services/window_service.dart';
import 'theme/app_theme.dart';
import 'theme/constants.dart';
import 'ui/core/extensions/build_context_l10n.dart';
import 'widgets/window_close_handler.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // desktop_multi_window 子窗口入口（仅 Windows 桌面）：
  // 子引擎以固定参数 ['multi_window', windowId, jsonArgs] 重新执行 main。
  // 必须在主窗口专属初始化（托盘、关闭按钮接管）之前分流，
  // 子窗口只运行轻量笔记编辑器，见 pages/note_window_page.dart。
  if (!kIsWeb &&
      Platform.isWindows &&
      args.isNotEmpty &&
      args.first == 'multi_window') {
    final windowId = int.parse(args[1]);
    final arguments = args.length > 2 && args[2].isNotEmpty
        ? Map<String, dynamic>.from(jsonDecode(args[2]) as Map)
        : <String, dynamic>{};
    runApp(NoteWindowApp(
      windowController: WindowController.fromWindowId(windowId),
      arguments: arguments,
    ));
    return;
  }

  // Windows 桌面端：接管关闭按钮并初始化系统托盘，其他平台为空操作。
  await WindowService.instance.init();
  usePathUrlStrategy();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const ProviderScope(child: GitNoteApp()));
}

final GoRouter _router = GoRouter(
  initialLocation: '/notes',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        final currentPage = _pageForUri(state.uri);
        return WindowCloseHandler(
          child: AppBootstrapGate(
            child: AppShell(
              currentPage: currentPage,
              onNavigate: (page) => _goToBranch(page, navigationShell),
              child: navigationShell,
            ),
          ),
        );
      },
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/notes',
              builder: (context, state) => const NotesRoutePage(),
              routes: [
                GoRoute(
                  path: ':noteId',
                  builder: (context, state) {
                    final isNew = state.uri.queryParameters['isNew'] == 'true';
                    return NotesRoutePage(
                        noteId: state.pathParameters['noteId'],
                        isNewNote: isNew);
                  },
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/reminder',
              builder: (context, state) => const ReminderPage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/repo',
              builder: (context, state) => const RepoPage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              builder: (context, state) => const SettingsPage(),
              routes: [
                GoRoute(
                  path: 'token-help',
                  builder: (context, state) => const TokenHelpPage(),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);

AppPage _pageForUri(Uri uri) {
  if (uri.path.startsWith('/notes/') && uri.pathSegments.length > 1) {
    return AppPage.editor;
  }
  if (uri.path.startsWith('/settings')) {
    return AppPage.settings;
  }
  switch (uri.path) {
    case '/reminder':
      return AppPage.reminder;
    case '/repo':
      return AppPage.repo;
    case '/settings':
      return AppPage.settings;
    case '/notes':
    default:
      return AppPage.notes;
  }
}

void _goToBranch(AppPage page, StatefulNavigationShell navigationShell) {
  final index = switch (page) {
    AppPage.notes || AppPage.editor => 0,
    AppPage.reminder => 1,
    AppPage.repo => 2,
    AppPage.settings => 3,
  };
  navigationShell.goBranch(
    index,
    initialLocation: index == navigationShell.currentIndex,
  );
}

class GitNoteApp extends ConsumerWidget {
  const GitNoteApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'casual',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.light,
      routerConfig: _router,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('zh'),
      ],
    );
  }
}

class AppBootstrapGate extends ConsumerStatefulWidget {
  const AppBootstrapGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppBootstrapGate> createState() => _AppBootstrapGateState();
}

class _AppBootstrapGateState extends ConsumerState<AppBootstrapGate> {
  bool _isReady = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await _bootstrap();
        if (mounted) {
          setState(() {
            _isReady = true;
          });
        }
      } catch (error) {
        if (mounted) {
          setState(() {
            _error = error;
          });
        }
      }
    });
  }

  Future<void> _bootstrap() async {
    await Future.wait([
      ref.read(notesProvider.notifier).loadFromCache(),
      ref.read(gitProvider.notifier).loadConfig(),
    ]);
    ref.read(reminderProvider);
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        body: Center(child: Text(_error.toString())),
      );
    }

    if (!_isReady) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: AppSpacing.md),
              Text(context.l10n.loading),
            ],
          ),
        ),
      );
    }

    return widget.child;
  }
}

class _MobileNotesWithFab extends ConsumerStatefulWidget {
  const _MobileNotesWithFab({
    required this.onOpenNote,
    required this.onCreateNote,
  });

  final void Function(String noteId) onOpenNote;
  final void Function(NoteFormat format) onCreateNote;

  @override
  ConsumerState<_MobileNotesWithFab> createState() =>
      _MobileNotesWithFabState();
}

class _MobileNotesWithFabState extends ConsumerState<_MobileNotesWithFab>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;
  NoteFormat _selectedFormat = NoteFormat.txt;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  void _createNote() {
    widget.onCreateNote(_selectedFormat);
    if (_isExpanded) {
      _toggleExpand();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        NotesPage(onOpenNote: widget.onOpenNote),
        // 遮罩层
        if (_isExpanded)
          Positioned.fill(
            child: GestureDetector(
              onTap: _toggleExpand,
              child: Container(
                color: Colors.black.withValues(alpha: 0.3),
              ),
            ),
          ),
        // 格式选择器
        Positioned(
          right: AppSpacing.xl,
          bottom: AppSpacing.xl + MediaQuery.of(context).padding.bottom + 70,
          child: IgnorePointer(
            ignoring: !_isExpanded,
            child: AnimatedBuilder(
            animation: _expandAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _expandAnimation.value,
                alignment: Alignment.bottomRight,
                child: Opacity(
                  opacity: _expandAnimation.value,
                  child: child,
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _FormatOption(
                    label: 'TXT',
                    icon: Icons.description_outlined,
                    isSelected: _selectedFormat == NoteFormat.txt,
                    onTap: () => setState(() => _selectedFormat = NoteFormat.txt),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _FormatOption(
                    label: 'Markdown',
                    icon: Icons.code,
                    isSelected: _selectedFormat == NoteFormat.markdown,
                    onTap: () =>
                        setState(() => _selectedFormat = NoteFormat.markdown),
                  ),
                ],
              ),
            ),
            ),
          ),
        ),
        // 主按钮
        Positioned(
          right: AppSpacing.xl,
          bottom: AppSpacing.xl + MediaQuery.of(context).padding.bottom,
          child: FloatingActionButton(
            heroTag: 'fab_create',
            onPressed: _isExpanded ? _createNote : _toggleExpand,
            backgroundColor: AppColors.primary,
            child: AnimatedRotation(
              turns: _isExpanded ? 0.125 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                _isExpanded ? Icons.check : Icons.add,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FormatOption extends StatelessWidget {
  const _FormatOption({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? AppColors.primary
          : AppColors.primary.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(AppRadius.round),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.round),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                label,
                style: TextStyle(
                  fontSize: AppFontSize.sm,
                  color: isSelected ? Colors.white : AppColors.primary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NotesRoutePage extends ConsumerWidget {
  const NotesRoutePage({super.key, this.noteId, this.isNewNote = false});

  final String? noteId;
  final bool isNewNote;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = getScreenType(context) == ScreenType.desktop;

    // 桌面顶栏按钮与移动端悬浮按钮共用的创建流程：建笔记后跳转编辑器。
    void createNote(NoteFormat format) {
      final note = ref.read(notesProvider.notifier).createNote(
            title: context.l10n.untitledNote,
            category: context.l10n.uncategorized,
            format: format,
          );
      context.go('/notes/${note.id}?isNew=true');
    }

    if (isDesktop) {
      if (noteId == null) {
        return NotesPage(
          onOpenNote: (selectedId) => context.go('/notes/$selectedId'),
          onCreateNote: createNote,
        );
      }

      return Row(
        children: [
          Expanded(
            child: NotesPage(
              onOpenNote: (selectedId) => context.go('/notes/$selectedId'),
              onCreateNote: createNote,
            ),
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(
            flex: 2,
            child: EditorPage(
              // 按 noteId 设 key，切换笔记时强制重建 State，触发 dispose 清理空笔记。
              key: ValueKey(noteId),
              noteId: noteId,
              isNewNote: isNewNote,
              onBack: () => context.go('/notes'),
            ),
          ),
        ],
      );
    }

    if (noteId != null) {
      return EditorPage(
        key: ValueKey(noteId),
        noteId: noteId,
        isNewNote: isNewNote,
        onBack: () => context.go('/notes'),
      );
    }

    return _MobileNotesWithFab(
      onOpenNote: (selectedId) => context.go('/notes/$selectedId'),
      onCreateNote: createNote,
    );
  }
}
