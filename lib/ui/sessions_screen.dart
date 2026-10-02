import 'package:flutter/material.dart';

import '../data/repository.dart';
import '../l10n/app_localizations.dart';
import 'dialogs.dart';
import 'format.dart';
import 'module_header.dart';
import 'session_detail_screen.dart';
import 'start_capture.dart';

class SessionsScreen extends StatefulWidget {
  const SessionsScreen({
    super.key,
    required this.repository,
    this.capturingSession = capturingSessionId,
  });

  final Repository repository;
  final Future<int?> Function() capturingSession;

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> with WidgetsBindingObserver {
  List<SessionSummary>? _sessions;
  int? _capturing;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _reload();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _reload();
  }

  Future<void> _reload() async {
    final sessions = await widget.repository.listSessions();
    final capturing = await widget.capturingSession();
    if (mounted) {
      setState(() {
        _sessions = sessions;
        _capturing = capturing;
      });
    }
  }

  Future<void> _create() async {
    final l = AppLocalizations.of(context);
    final name = await promptText(
      context,
      title: l.newSession,
      hint: l.newSessionHint,
      action: l.create,
    );
    if (name == null) return;
    final id = await widget.repository.createSession(name);
    if (!mounted) return;
    await _open(id);
  }

  Future<void> _open(int id) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => SessionDetailScreen(repository: widget.repository, sessionId: id),
    ));
    await _reload();
  }

  Future<void> _rename(SessionSummary s) async {
    final l = AppLocalizations.of(context);
    final name = await promptText(context, title: l.renameSession, initial: s.name, action: l.rename);
    if (name == null) return;
    await widget.repository.renameSession(s.id, name);
    await _reload();
  }

  Future<void> _delete(SessionSummary s) async {
    final l = AppLocalizations.of(context);
    final ok = await confirm(
      context,
      title: l.deleteSessionTitle(s.name),
      message: l.deleteSessionMessage(s.runCount),
      action: l.delete,
    );
    if (!ok) return;
    if (await isCapturingInto(s.id)) await stopCapture();
    await widget.repository.deleteSession(s.id);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final sessions = _sessions;
    return Scaffold(
      appBar: AppBar(title: Text(l.appTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: Text(l.newSession),
      ),
      body: switch (sessions) {
        null => const Center(child: CircularProgressIndicator()),
        [] => Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(l.sessionsEmpty, textAlign: TextAlign.center),
            ),
          ),
        final list => ListView(
            padding: const EdgeInsets.only(bottom: 88),
            children: [
              for (final s in list)
                _SessionRow(
                  key: ValueKey('session-${s.id}'),
                  session: s,
                  capturing: s.id == _capturing,
                  onTap: () => _open(s.id),
                  onRename: () => _rename(s),
                  onDelete: () => _delete(s),
                ),
            ],
          ),
      },
    );
  }
}

/// A hairline-ruled row: name over run count and last capture time,
/// with a red tab while the bubble saves into this session.
class _SessionRow extends StatelessWidget {
  const _SessionRow({
    super.key,
    required this.session,
    required this.capturing,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  final SessionSummary session;
  final bool capturing;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final last = session.lastCapturedAt;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(child: Text(session.name, style: text.titleMedium)),
                          if (capturing) ...[
                            const SizedBox(width: 8),
                            ModuleTab(l.capturing),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l.sessionSubtitle(
                          l.runCount(session.runCount),
                          last == null ? '—' : formatTime(last),
                        ),
                        style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) => v == 'rename' ? onRename() : onDelete(),
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'rename', child: Text(l.rename)),
                    PopupMenuItem(value: 'delete', child: Text(l.delete)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
