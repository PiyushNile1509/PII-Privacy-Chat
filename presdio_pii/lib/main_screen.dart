import 'package:flutter/material.dart';
import '../models/chat_session.dart';
import '../services/api_service.dart';
import '../services/local_storage_service.dart';
import 'chat_screen.dart';
import 'pii_test_screen.dart';
import 'presidio_test_screen.dart';
import 'log_viewer_screen.dart';
import 'constants/app_strings.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  List<ChatSession> _sessions = [];
  String? _currentSessionId;
  bool _backendConnected = false;

  bool _isEditMode = false;
  final Set<String> _selectedSessions = {};

  // For floating menu
  String? _longPressedSessionId;
  Offset? _longPressedPosition;

  @override
  void initState() {
    super.initState();
    _checkBackendConnection();
    _loadSessions();
    _createNewChatAutomatically();
  }

  Future<void> _checkBackendConnection() async {
    final connected = await ApiService.checkBackendHealth();
    if (mounted) {
      setState(() => _backendConnected = connected);
    }
  }

  Future<void> _loadSessions() async {
    final sessions = await LocalStorageService.getSessions();
    final nonEmptySessions = <ChatSession>[];
    
    for (final session in sessions) {
      final messages = await LocalStorageService.getSessionMessages(session.id);
      if (messages.isNotEmpty) {
        nonEmptySessions.add(session);
      }
    }
    
    if (mounted) setState(() => _sessions = nonEmptySessions);
  }

  Future<void> _createNewChatAutomatically() async {
    try {
      final session = await ApiService.createSession();
      if (mounted) setState(() => _currentSessionId = session.id);
    } catch (_) {}
  }

  Future<void> _createNewChat() async {
    try {
      final session = await ApiService.createSession();
      if (mounted) {
        setState(() {
          _currentSessionId = session.id;
          _isEditMode = false;
          _selectedSessions.clear();
        });
      }
      _loadSessions();
    } catch (e) {
      _showSnack('${AppStrings.errorPrefix}${e.toString()}');
    }
  }

  Future<void> _deleteSession(String sessionId) async {
    try {
      await ApiService.deleteSession(sessionId);
      if (_currentSessionId == sessionId) {
        _currentSessionId = null;
        await _createNewChatAutomatically();
      }
      _loadSessions();
    } catch (e) {
      _showSnack('${AppStrings.errorPrefix}${e.toString()}');
    }
  }

  Future<void> _deleteSelectedSessions() async {
    try {
      for (final id in _selectedSessions) {
        await ApiService.deleteSession(id);
        if (_currentSessionId == id) {
          _currentSessionId = null;
        }
      }
      if (_currentSessionId == null) {
        await _createNewChatAutomatically();
      }
      if (mounted) {
        setState(() {
          _selectedSessions.clear();
          _isEditMode = false;
        });
      }
      _loadSessions();
    } catch (e) {
      _showSnack('${AppStrings.errorPrefix}${e.toString()}');
    }
  }

  void _showSnack(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  double _sidebarOffset = -280;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onHorizontalDragUpdate: (details) {
          setState(() {
            _sidebarOffset = (_sidebarOffset + details.delta.dx * 1.2).clamp(-280.0, 0.0);
          });
        },
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity! > 500) {
            _sidebarOffset = 0;
          } else if (details.primaryVelocity! < -500) {
            _sidebarOffset = -280;
            _longPressedSessionId = null;
          } else if (_sidebarOffset > -140) {
            _sidebarOffset = 0;
          } else {
            _sidebarOffset = -280;
            _longPressedSessionId = null;
          }
          setState(() {});
        },
        child: Stack(
          children: [
            Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: _currentSessionId == null
                      ? const Center(child: CircularProgressIndicator())
                      : ChatScreen(
                          key: ValueKey(_currentSessionId),
                          sessionId: _currentSessionId!,
                          onSessionUpdate: _loadSessions,
                        ),
                ),
              ],
            ),
            // Sidebar
            Positioned(
              left: _sidebarOffset,
              top: 0,
              bottom: 0,
              width: 280,
              child: _buildSidebar(),
            ),
            // Tap to close overlay
            if (_sidebarOffset > -280)
              Positioned(
                left: 280 + _sidebarOffset,
                top: 0,
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () => setState(() {
                    _sidebarOffset = -280;
                    _longPressedSessionId = null;
                  }),
                  child: Container(color: Colors.transparent),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF171717),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(2, 0)),
        ],
      ),
      child: Column(
        children: [
          // Sidebar Header
          Container(
            padding: const EdgeInsets.only(top: 35, left: 16, right: 16),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => setState(() {
                    _sidebarOffset = -280;
                    _isEditMode = false;
                    _selectedSessions.clear();
                    _longPressedSessionId = null;
                  }),
                ),
                const Spacer(),
                if (_isEditMode) ...[
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: _selectedSessions.isEmpty ? null : _deleteSelectedSessions,
                  ),
                  IconButton(
                    icon: const Icon(Icons.check, color: Colors.white),
                    onPressed: () => setState(() {
                      _isEditMode = false;
                      _selectedSessions.clear();
                    }),
                  ),
                ] else
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.white),
                    onPressed: () => setState(() => _isEditMode = true),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Chat History with floating menu
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (_longPressedSessionId != null) {
                  setState(() => _longPressedSessionId = null);
                }
              },
              child: Stack(
                children: [
                  NotificationListener<ScrollNotification>(
                    onNotification: (scrollNotification) {
                      if (_longPressedSessionId != null) {
                        setState(() => _longPressedSessionId = null);
                      }
                      return false;
                    },
                    child: ListView.builder(
                      itemCount: _sessions.length,
                      itemBuilder: (context, index) {
                      final session = _sessions[index];
                      final isSelected = session.id == _currentSessionId;

                      return Builder(
                        builder: (tileContext) => GestureDetector(
                          onLongPress: () {
                            final box = tileContext.findRenderObject() as RenderBox?;
                            if (box != null) {
                              final pos = box.localToGlobal(Offset.zero, ancestor: context.findRenderObject());
                              setState(() {
                                _longPressedSessionId = session.id;
                                _longPressedPosition = pos;
                              });
                            }
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF2F2F2F) : null,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ListTile(
                              dense: true,
                              leading: _isEditMode
                                  ? Checkbox(
                                      value: _selectedSessions.contains(session.id),
                                      onChanged: (selected) {
                                        setState(() {
                                          if (selected == true) {
                                            _selectedSessions.add(session.id);
                                          } else {
                                            _selectedSessions.remove(session.id);
                                          }
                                        });
                                      },
                                    )
                                  : const Icon(Icons.chat_bubble_outline, size: 16, color: Colors.grey),
                              title: Text(session.title,
                                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white)),
                              subtitle: Text(_formatDate(session.updatedAt),
                                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              onTap: () {
                                if (_isEditMode) {
                                  setState(() {
                                    if (_selectedSessions.contains(session.id)) {
                                      _selectedSessions.remove(session.id);
                                    } else {
                                      _selectedSessions.add(session.id);
                                    }
                                  });
                                } else {
                                  setState(() {
                                    _currentSessionId = session.id;
                                    _sidebarOffset = -280;
                                    _isEditMode = false;
                                    _selectedSessions.clear();
                                    _longPressedSessionId = null;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                      );
                      },
                    ),
                  ),
                  // Floating menu over long-pressed chat
                  if (_longPressedSessionId != null && _longPressedPosition != null)
                    Positioned(
                      left: _longPressedPosition!.dx + 150, // adjust horizontal
                      top: _longPressedPosition!.dy + 110,
                      child: Material(
                        color: Colors.transparent,
                        child: Container(
                          width: 110,
                          height: 100,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2F2F2F),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton.icon(
                                onPressed: () {
                                  _showRenameDialog(
                                      _sessions.firstWhere((s) => s.id == _longPressedSessionId));
                                  setState(() => _longPressedSessionId = null);
                                },
                                icon: const Icon(Icons.edit, color: Colors.white, size: 16),
                                label: const Text('Rename', style: TextStyle(color: Colors.white)),
                              ),
                              TextButton.icon(
                                onPressed: () {
                                  _deleteSession(_longPressedSessionId!);
                                  setState(() => _longPressedSessionId = null);
                                },
                                icon: const Icon(Icons.delete, color: Colors.red, size: 16),
                                label: const Text('Delete', style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 90,
      padding: const EdgeInsets.only(top: 35, left: 16, right: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF2F2F2F),
        border: Border(bottom: BorderSide(color: Color(0xFF404040), width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () {
              _loadSessions();
              setState(() => _sidebarOffset = 0);
            },
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  AppStrings.appName,
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                ),

              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            color: const Color(0xFF2F2F2F),
            onSelected: (value) {
              switch (value) {
                case 'new_chat':
                  _createNewChat();
                  break;
                case 'pii_test':
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const PIITestScreen()),
                  );
                  break;
                case 'presidio_test':
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const PresidioTestScreen()),
                  );
                  break;
                case 'view_logs':
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LogViewerScreen()),
                  );
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'new_chat',
                child: Row(
                  children: [
                    Icon(Icons.add, color: Colors.white),
                    SizedBox(width: 8),
                    Text('New Chat', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'pii_test',
                child: Row(
                  children: [
                    Icon(Icons.security, color: Colors.white),
                    SizedBox(width: 8),
                    Text('PII Test', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'presidio_test',
                child: Row(
                  children: [
                    Icon(Icons.verified_user, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Presidio Test', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'view_logs',
                child: Row(
                  children: [
                    Icon(Icons.description, color: Colors.white),
                    SizedBox(width: 8),
                    Text('View Logs', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(ChatSession session) {
    final controller = TextEditingController(text: session.title);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2F2F2F),
        title: const Text(AppStrings.renameChat, style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: AppStrings.enterNewName,
            hintStyle: TextStyle(color: Colors.grey),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blue)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blue)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text(AppStrings.buttonCancel, style: TextStyle(color: Colors.grey))),
          TextButton(
              onPressed: () {
                final newTitle = controller.text.trim();
                if (newTitle.isNotEmpty) {
                  Navigator.pop(context);
                  _renameSession(session.id, newTitle);
                }
              },
              child: const Text(AppStrings.buttonRename, style: TextStyle(color: Colors.blue))),
        ],
      ),
    );
  }

  Future<void> _renameSession(String sessionId, String newTitle) async {
    try {
      final index = _sessions.indexWhere((s) => s.id == sessionId);
      if (index != -1) {
        final updatedSession = ChatSession(
          id: _sessions[index].id,
          title: newTitle,
          createdAt: _sessions[index].createdAt,
          updatedAt: DateTime.now(),
        );
        setState(() => _sessions[index] = updatedSession);
        await LocalStorageService.updateSession(updatedSession);
      }
      _showSnack(AppStrings.chatRenamedSuccess);
    } catch (e) {
      _showSnack('${AppStrings.errorRenamingChat}${e.toString()}');
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return AppStrings.today;
    }
    if (diff.inDays == 1) {
      return AppStrings.yesterday;
    }
    if (diff.inDays < 7) {
      return AppStrings.daysAgo(diff.inDays);
    }
    return AppStrings.dateFormat(date.day, date.month);
  }
}
