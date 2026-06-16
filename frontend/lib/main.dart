import 'package:campus/local_chatbot_service.dart';
import 'package:campus/chat_storage_service.dart';
import 'package:campus/theme_config.dart';
import 'package:campus/splash_screen.dart';
import 'package:campus/campus_map_screen.dart';
import 'package:campus/campus_locations.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:share_plus/share_plus.dart';
import 'package:animated_text_kit/animated_text_kit.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KampusDanismaniApp());
}

class KampusDanismaniApp extends StatefulWidget {
  const KampusDanismaniApp({Key? key}) : super(key: key);

  @override
  State<KampusDanismaniApp> createState() => _KampusDanismaniAppState();
}

class _KampusDanismaniAppState extends State<KampusDanismaniApp> {
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final isDark = await ChatStorageService.loadThemePreference();
    if (mounted) setState(() => _isDarkMode = isDark);
  }

  void _toggleTheme() {
    setState(() => _isDarkMode = !_isDarkMode);
    ChatStorageService.saveThemePreference(_isDarkMode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'YYÜ Kampüs Danışmanı',
      theme: AppThemes.lightTheme,
      darkTheme: AppThemes.darkTheme,
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: SplashScreen(
        nextScreen: DanismanScreen(
          onToggleTheme: _toggleTheme,
          isDarkMode: _isDarkMode,
        ),
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}

class DanismanScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDarkMode;

  const DanismanScreen({
    Key? key,
    required this.onToggleTheme,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  State<DanismanScreen> createState() => _DanismanScreenState();
}

class _DanismanScreenState extends State<DanismanScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FlutterTts _flutterTts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();

  final List<ChatMessage> _messages = [];
  bool _loading = false;
  bool _isConnected = false;
  bool _isListening = false;
  bool _speechAvailable = false;
  int _requestCount = 0; // Request tracker
  bool _showQuickReplies = true;

  late final LocalChatbotService _localChatbot = LocalChatbotService(
    timeoutSeconds: 300,
  );

  // Hızlı soru butonları
  static const List<Map<String, dynamic>> _quickReplies = [
    {
      'icon': Icons.restaurant,
      'label': 'Yemekhane',
      'query': 'Yemekhanede hangi yemekler çıkıyor?',
    },
    {
      'icon': Icons.directions_bus,
      'label': 'Ulaşım',
      'query': 'Üniversiteye nasıl ulaşabilirim?',
    },
    {
      'icon': Icons.local_library,
      'label': 'Kütüphane',
      'query': 'Kütüphanede hangi hizmetler var?',
    },
    {
      'icon': Icons.attach_money,
      'label': 'Burs',
      'query': 'Burs imkanları nelerdir?',
    },
    {'icon': Icons.hotel, 'label': 'Yurt', 'query': 'YYÜ\'de yurt var mı?'},
    {
      'icon': Icons.computer,
      'label': 'OBS',
      'query': 'OBS\'ye nasıl giriş yapabilirim?',
    },
    {
      'icon': Icons.event,
      'label': 'Etkinlikler',
      'query': 'YYÜ\'de hangi etkinlikler düzenleniyor?',
    },
    {
      'icon': Icons.school,
      'label': 'Fakülteler',
      'query': 'YYÜ\'de hangi fakülteler var?',
    },
    {
      'icon': Icons.swap_horiz,
      'label': 'Erasmus',
      'query': 'Erasmus programı hakkında bilgi verir misin?',
    },
    {
      'icon': Icons.sports_soccer,
      'label': 'Spor',
      'query': 'Kampüste hangi spor imkanları var?',
    },
  ];

  @override
  void initState() {
    super.initState();
    _initTts();
    _initSpeech();
    _checkConnection();
    _loadChatHistory();
  }

  Future<void> _loadChatHistory() async {
    final savedMessages = await ChatStorageService.loadMessages();
    if (savedMessages.isNotEmpty) {
      setState(() {
        _messages.addAll(savedMessages.map((m) => ChatMessage.fromJson(m)));
        _showQuickReplies = false;
      });
      _scrollToBottom();
    } else {
      // Başlangıç mesajı
      _messages.add(
        ChatMessage(
          text:
              'Merhaba! Ben YYÜ Kampüs Danışmanı 🎓\n\nSize üniversitemiz, ulaşım, yemekhane veya akademik konular hakkında nasıl yardımcı olabilirim?',
          isUser: false,
        ),
      );
    }
  }

  Future<void> _saveMessages() async {
    await ChatStorageService.saveMessages(
      _messages.map((m) => m.toJson()).toList(),
    );
  }

  Future<void> _clearChat() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sohbeti Temizle'),
        content: const Text('Tüm sohbet geçmişi silinecek. Emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Temizle', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ChatStorageService.clearMessages();
      setState(() {
        _messages.clear();
        _showQuickReplies = true;
        _messages.add(
          ChatMessage(
            text:
                'Merhaba! Ben YYÜ Kampüs Danışmanı 🎓\n\nSize üniversitemiz, ulaşım, yemekhane veya akademik konular hakkında nasıl yardımcı olabilirim?',
            isUser: false,
          ),
        );
      });
    }
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage('tr-TR');
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.6);
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onStatus: (status) {
        if (status == 'notListening' || status == 'done') {
          setState(() => _isListening = false);
        }
      },
      onError: (error) {
        setState(() => _isListening = false);
      },
    );
    setState(() {});
  }

  Future<void> _startListening() async {
    if (!_speechAvailable) return;
    setState(() => _isListening = true);
    await _speech.listen(
      onResult: (result) {
        setState(() {
          _controller.text = result.recognizedWords;
        });
        if (result.finalResult) {
          _stopListening();
          if (_controller.text.trim().isNotEmpty) {
            _sendMessage();
          }
        }
      },
      localeId: 'tr_TR',
      listenMode: stt.ListenMode.confirmation,
    );
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    setState(() => _isListening = false);
  }

  Future<void> _checkConnection() async {
    final isHealthy = await _localChatbot.isHealthy();
    setState(() => _isConnected = isHealthy);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage([String? quickReply]) async {
    final text = quickReply ?? _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _loading = true;
      _showQuickReplies = false;
      _controller.clear();
    });
    _scrollToBottom();

    final currentRequestId = ++_requestCount;

    // API'ye gönderilecek geçmişi hazırla (son eklenen kullanıcı sorusu hariç)
    final historyData = _messages
        .where((m) => m != _messages.last)
        .map(
          (m) => {'role': m.isUser ? 'user' : 'assistant', 'content': m.text},
        )
        .toList();

    // Belleği yormamak için sadece son 4 mesajı gönderelim
    final recentHistory = historyData.length > 4
        ? historyData.sublist(historyData.length - 4)
        : historyData;

    try {
      final result = await _localChatbot.sendMessage(
        text,
        history: recentHistory,
      );
      if (currentRequestId != _requestCount)
        return; // Ignore if stopped or new request sent

      setState(() {
        // Determine data type
        final rawData = result.data;
        dynamic mealPayload;
        Map<String, dynamic>? busPayload;
        Map<String, dynamic>? announcementPayload;
        Map<String, dynamic>? eventPayload;
        if (rawData is Map) {
          final type = rawData['type']?.toString() ?? '';
          if (type.startsWith('bus')) {
            busPayload = Map<String, dynamic>.from(rawData);
          } else if (type == 'announcements') {
            announcementPayload = Map<String, dynamic>.from(rawData);
          } else if (type.startsWith('event')) {
            eventPayload = Map<String, dynamic>.from(rawData);
          } else {
            mealPayload = rawData;
          }
        } else {
          mealPayload = rawData;
        }

        _messages.add(
          ChatMessage(
            text: result.response,
            isUser: false,
            confidence: result.confidence,
            isAnimating: true,
            location: result.location,
            mealData: mealPayload,
            busData: busPayload,
            announcementData: announcementPayload,
            eventData: eventPayload,
          ),
        );
        _loading = false;
        _showQuickReplies = true;

        // Haritaya Otomatik Yönlendirme Katmanı (Premium UX)
        final queryLower = text.toLowerCase();
        final isMapQuery =
            queryLower.contains('harita') ||
            queryLower.contains('haritayı') ||
            queryLower.contains('haritayi') ||
            queryLower.contains('haritaya') ||
            queryLower.contains('nerededir') ||
            queryLower.contains('nerede') ||
            queryLower.contains('konumu') ||
            queryLower.contains('konumunu') ||
            queryLower.contains('yeri') ||
            queryLower.contains('yerini');

        if (isMapQuery && result.location != null) {
          final loc = result.location!;
          Future.delayed(const Duration(milliseconds: 1800), () {
            if (!mounted) return;
            final focusLoc = CampusLocation(
              name: loc['name'] ?? 'Bilinmeyen',
              description: loc['category'] ?? '',
              coordinates: LatLng(
                (loc['lat'] as num).toDouble(),
                (loc['lng'] as num).toDouble(),
              ),
              category: loc['category'] ?? '',
              icon: Icons.place,
              color: Colors.blue,
            );
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CampusMapScreen(focusLocation: focusLoc),
              ),
            );
          });
        } else if (queryLower.contains('harita') ||
            queryLower.contains('haritayı') ||
            queryLower.contains('haritayi') ||
            queryLower.contains('haritaya') ||
            queryLower.contains('haritayi ac') ||
            queryLower.contains('haritayı aç')) {
          // Genel harita açma sorgusu
          Future.delayed(const Duration(milliseconds: 1800), () {
            if (!mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CampusMapScreen()),
            );
          });
        }
      });
    } catch (e) {
      setState(() {
        _messages.add(
          ChatMessage(
            text:
                'Üzgünüm, bir bağlantı hatası oluştu. Lütfen API servisinin açık olduğundan emin olun.',
            isUser: false,
            isAnimating: true,
          ),
        );
        _loading = false;
        _showQuickReplies = true;
      });
    }
    _scrollToBottom();
    _saveMessages();
  }

  bool get _isAnimating => _messages.any((m) => m.isAnimating);

  void _stopResponse() {
    setState(() {
      _loading = false;
      _requestCount++; // Invalidate previous request
      _showQuickReplies = true;
      // Stop all animating messages instantly
      for (final m in _messages) {
        if (m.isAnimating) m.isAnimating = false;
      }
    });
    _saveMessages();
  }

  void _showMessageOptions(ChatMessage message) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: const Text('Kopyala'),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: message.text));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Mesaj kopyalandı'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
              ),
              if (!message.isUser)
                ListTile(
                  leading: const Icon(Icons.volume_up_rounded),
                  title: const Text('Sesli Oku'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _flutterTts.speak(message.text);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.share_rounded),
                title: const Text('Paylaş'),
                onTap: () {
                  Navigator.pop(ctx);
                  Share.share(message.text);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/images/yyu_logo.png',
                  width: 32,
                  height: 32,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kampüs Danışmanı',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isConnected ? Colors.green : Colors.red,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isConnected ? 'API Bağlı' : 'Bağlantı Yok',
                      style: TextStyle(
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Kampüs Haritası
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CampusMapScreen()),
              );
            },
            tooltip: 'Kampüs Haritası',
            icon: Icon(
              Icons.map_outlined,
              color: isDark ? Colors.cyan : const Color(0xFF003366),
            ),
          ),
          // Karanlık Mod Toggle
          IconButton(
            onPressed: widget.onToggleTheme,
            tooltip: widget.isDarkMode ? 'Açık Mod' : 'Karanlık Mod',
            icon: Icon(
              widget.isDarkMode
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
              color: isDark ? Colors.amber : const Color(0xFF64748B),
            ),
          ),
          // Sohbeti Temizle
          IconButton(
            onPressed: _clearChat,
            tooltip: 'Sohbeti Temizle',
            icon: Icon(
              Icons.delete_outline_rounded,
              color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
            ),
          ),
          // Bağlantı Yenile
          IconButton(
            onPressed: _checkConnection,
            tooltip: 'Bağlantıyı Yenile',
            icon: Icon(
              Icons.refresh,
              color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return MessageBubble(
                  message: message,
                  flutterTts: _flutterTts,
                  onLongPress: () => _showMessageOptions(message),
                  onAnimationComplete: () {
                    if (message.isAnimating) {
                      setState(() => message.isAnimating = false);
                      _saveMessages();
                    }
                  },
                );
              },
            ),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: TypingIndicator(),
            ),
          // Hızlı Soru Butonları
          if (_showQuickReplies && !_loading) _buildQuickReplies(),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildQuickReplies() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: _quickReplies.length,
        itemBuilder: (context, index) {
          final item = _quickReplies[index];
          return ActionChip(
            avatar: Icon(
              item['icon'] as IconData,
              size: 16,
              color: isDark ? const Color(0xFF00CCCC) : const Color(0xFF003366),
            ),
            label: Text(
              item['label'] as String,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white70 : const Color(0xFF334155),
              ),
            ),
            backgroundColor: isDark
                ? const Color(0xFF2A2A3E)
                : const Color(0xFFF1F5F9),
            side: BorderSide(
              color: isDark ? const Color(0xFF3A3A4E) : const Color(0xFFE2E8F0),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            onPressed: () => _sendMessage(item['query'] as String),
          );
        },
      ),
    );
  }

  Widget _buildInputArea() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF2A2A3E)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _controller,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  hintText: 'Bir şey sorun...',
                  hintStyle: TextStyle(
                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (_loading || _isAnimating)
            IconButton(
              onPressed: _stopResponse,
              icon: const Icon(
                Icons.stop_circle_outlined,
                color: Colors.orange,
              ),
              tooltip: 'Durdur',
            ),
          GestureDetector(
            onTap: _isListening ? _stopListening : _startListening,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isListening ? Colors.red : const Color(0xFF00CCCC),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isListening ? Icons.mic_off : Icons.mic,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _sendMessage(),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final double? confidence;
  bool isAnimating;
  final Map<String, dynamic>? location;
  final dynamic mealData; // Added meal data field
  final Map<String, dynamic>? busData; // Bus schedule data
  final Map<String, dynamic>? announcementData; // Announcements data
  final Map<String, dynamic>? eventData; // Events data

  ChatMessage({
    required this.text,
    required this.isUser,
    this.confidence,
    this.isAnimating = false,
    this.location,
    this.mealData,
    this.busData,
    this.announcementData,
    this.eventData,
  });

  bool get hasLocation => location != null;
  bool get hasMealData => mealData != null;
  bool get hasBusData => busData != null && busData!['type'] != null;
  bool get hasAnnouncementData =>
      announcementData != null && announcementData!['type'] == 'announcements';
  bool get hasEventData => eventData != null && eventData!['type'] != null;

  Map<String, dynamic> toJson() => {
    'text': text,
    'isUser': isUser,
    'confidence': confidence,
    'location': location,
    'mealData': mealData,
    'busData': busData,
    'announcementData': announcementData,
    'eventData': eventData,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    text: json['text'] ?? '',
    isUser: json['isUser'] ?? false,
    confidence: json['confidence']?.toDouble(),
    location: json['location'] != null
        ? Map<String, dynamic>.from(json['location'])
        : null,
    mealData: json['mealData'],
    busData: json['busData'] != null
        ? Map<String, dynamic>.from(json['busData'])
        : null,
    announcementData: json['announcementData'] != null
        ? Map<String, dynamic>.from(json['announcementData'])
        : null,
    eventData: json['eventData'] != null
        ? Map<String, dynamic>.from(json['eventData'])
        : null,
  );
}

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final FlutterTts flutterTts;
  final VoidCallback? onLongPress;
  final VoidCallback? onAnimationComplete;

  const MessageBubble({
    Key? key,
    required this.message,
    required this.flutterTts,
    this.onLongPress,
    this.onAnimationComplete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: message.isUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: message.isUser
                  ? MainAxisAlignment.end
                  : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!message.isUser)
                  CircleAvatar(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.1),
                    child: Icon(
                      Icons.auto_awesome,
                      color: Theme.of(context).colorScheme.primary,
                      size: 18,
                    ),
                  ),
                if (!message.isUser) const SizedBox(width: 8),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: message.isUser
                          ? Theme.of(context).colorScheme.primary
                          : (isDark ? const Color(0xFF2A2A3E) : Colors.white),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: Radius.circular(message.isUser ? 20 : 4),
                        bottomRight: Radius.circular(message.isUser ? 4 : 20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.15 : 0.03,
                          ),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: _buildMessageText(context, isDark),
                  ),
                ),
                if (!message.isUser && message.text.isNotEmpty)
                  IconButton(
                    onPressed: () => flutterTts.speak(message.text),
                    icon: Icon(
                      Icons.volume_up,
                      size: 18,
                      color: isDark ? Colors.grey.shade500 : Colors.grey,
                    ),
                  ),
              ],
            ),
            if (!message.isUser && message.hasMealData)
              Padding(
                padding: const EdgeInsets.only(left: 48, top: 12),
                child: _MealList(mealData: message.mealData),
              ),
            if (!message.isUser && message.hasBusData)
              Padding(
                padding: const EdgeInsets.only(left: 48, top: 12),
                child: _BusScheduleCard(busData: message.busData!),
              ),
            if (!message.isUser && message.hasAnnouncementData)
              Padding(
                padding: const EdgeInsets.only(left: 48, top: 12),
                child: _DuyuruCard(data: message.announcementData!),
              ),
            if (!message.isUser && message.hasEventData)
              Padding(
                padding: const EdgeInsets.only(left: 48, top: 12),
                child: _EtkinlikCard(data: message.eventData!),
              ),
            if (!message.isUser && message.hasLocation)
              Padding(
                padding: const EdgeInsets.only(left: 48, top: 8),
                child: ElevatedButton.icon(
                  onPressed: () {
                    final loc = message.location!;
                    final focusLoc = CampusLocation(
                      name: loc['name'] ?? 'Bilinmeyen',
                      description: loc['category'] ?? '',
                      coordinates: LatLng(
                        (loc['lat'] as num).toDouble(),
                        (loc['lng'] as num).toDouble(),
                      ),
                      category: loc['category'] ?? '',
                      icon: Icons.place,
                      color: Colors.blue,
                    );
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            CampusMapScreen(focusLocation: focusLoc),
                      ),
                    );
                  },
                  icon: const Icon(Icons.map, size: 18),
                  label: const Text('Haritada Göster ve Rota Çiz'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF003366),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageText(BuildContext context, bool isDark) {
    final textColor = message.isUser
        ? Colors.white
        : (isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B));

    if (!message.isUser && message.isAnimating) {
      return AnimatedTextKit(
        animatedTexts: [
          TypewriterAnimatedText(
            message.text,
            textStyle: TextStyle(color: textColor, fontSize: 15),
            speed: const Duration(milliseconds: 20),
          ),
        ],
        isRepeatingAnimation: false,
        totalRepeatCount: 1,
        onFinished: onAnimationComplete,
      );
    }

    return Text(message.text, style: TextStyle(color: textColor, fontSize: 15));
  }
}

class _MealList extends StatelessWidget {
  final dynamic mealData;

  const _MealList({Key? key, required this.mealData}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (mealData == null || mealData is! List) return const SizedBox.shrink();

    final List<dynamic> menus = mealData;
    if (menus.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 250, // Increased height for the new card design
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: menus.length,
        itemBuilder: (context, index) {
          return _MealCard(menu: Map<String, dynamic>.from(menus[index]));
        },
      ),
    );
  }
}

class _MealCard extends StatelessWidget {
  final Map<String, dynamic> menu;

  const _MealCard({Key? key, required this.menu}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final meals = (menu['meals'] as List?) ?? [];

    // Bugün kontrolü
    final now = DateTime.now();
    final trMonths = [
      "Ocak",
      "Şubat",
      "Mart",
      "Nisan",
      "Mayıs",
      "Haziran",
      "Temmuz",
      "Ağustos",
      "Eylül",
      "Ekim",
      "Kasım",
      "Aralık",
    ];
    final currentDay = now.day.toString();
    final currentMonth = trMonths[now.month - 1];

    // Gelen tarih formatı "24 Şubat 2026" veya "24 subat 2026" olabilir
    final menuDate = menu['date'].toString().toLowerCase();
    final isToday =
        menuDate.contains(currentDay) &&
        menuDate.contains(currentMonth.toLowerCase());

    return Container(
      width: 320,
      margin: const EdgeInsets.only(right: 16, bottom: 10, top: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sol Kısım: İkon ve Tarih
          Container(
            width: 100,
            decoration: BoxDecoration(
              color: isToday
                  ? (isDark
                        ? Colors.blue.withOpacity(0.1)
                        : Colors.blue.shade50)
                  : (isDark
                        ? Colors.white.withOpacity(0.03)
                        : Colors.grey.shade50),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
              border: Border(
                right: BorderSide(
                  color: isDark ? Colors.white10 : Colors.grey.shade200,
                ),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.restaurant_menu,
                  size: 36,
                  color: Colors.brown.shade300,
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    menu['date'] ?? '',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ),
                if (isToday)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      "Bugün",
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Sağ Kısım: Menü Listesi
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: meals.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      indent: 12,
                      endIndent: 12,
                      color: isDark ? Colors.white10 : Colors.grey.shade200,
                    ),
                    itemBuilder: (context, index) {
                      final meal = meals[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                meal['name'] ?? '',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: isDark
                                      ? Colors.white.withOpacity(0.9)
                                      : Colors.black87,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF333333),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                "${meal['calories']}",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TypingIndicator extends StatelessWidget {
  const TypingIndicator({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        const SizedBox(width: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2A2A3E) : Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: SizedBox(
            width: 30,
            child: LinearProgressIndicator(
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
              minHeight: 2,
            ),
          ),
        ),
      ],
    );
  }
}

// ============ OTOBÜS SEFER SAATLERİ KARTI ============

class _BusScheduleCard extends StatelessWidget {
  final Map<String, dynamic> busData;

  const _BusScheduleCard({Key? key, required this.busData}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final type = busData['type'] as String?;
    if (type == 'bus_schedule') {
      return _buildFullSchedule(context);
    } else if (type == 'bus_next') {
      return _buildNextBuses(context);
    }
    return const SizedBox.shrink();
  }

  /// Belirli bir hattın tam sefer saatleri — iki sütunlu kart
  Widget _buildFullSchedule(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final schedule = busData['schedule'] as Map<String, dynamic>? ?? {};
    final sections =
        (schedule['sections'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final shortName = schedule['short_name'] ?? '';
    final fullName = schedule['full_name'] ?? '';
    final now = TimeOfDay.now();
    final nowStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    return Container(
      constraints: const BoxConstraints(maxWidth: 500),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Başlık
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF003366),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(15),
                topRight: Radius.circular(15),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shortName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (fullName.isNotEmpty)
                  Text(
                    fullName,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),

          // İki sütunlu sefer saatleri
          if (sections.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8),
              child: _buildTwoColumnLayout(sections, nowStr, isDark),
            ),

          // Alt bilgi — toplam sefer sayısı
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.03)
                  : Colors.grey.shade50,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(15),
                bottomRight: Radius.circular(15),
              ),
            ),
            child: Column(
              children: [
                Text(
                  _buildTotalInfo(sections),
                  style: TextStyle(
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                Text(
                  '📋 van.bel.tr · Canlı veri · Listenin tamamı',
                  style: TextStyle(
                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _buildTotalInfo(List<Map<String, dynamic>> sections) {
    final parts = <String>[];
    for (final s in sections) {
      final name = (s['name'] ?? '') as String;
      final times = (s['times'] as List?)?.length ?? 0;
      final oos = (s['out_of_service'] as List?)?.length ?? 0;
      final total = times + oos;
      String label = 'Sefer';
      if (name.toUpperCase().contains('MERKEZ')) {
        label = 'Merkez';
      } else if (name.toUpperCase().contains('YYÜ') ||
          name.toUpperCase().contains('KAMPÜS')) {
        label = 'YYÜ';
      }
      parts.add('$label: $total sefer');
    }
    return parts.join(' · ');
  }

  Widget _buildTwoColumnLayout(
    List<Map<String, dynamic>> sections,
    String nowStr,
    bool isDark,
  ) {
    // İki bölüm varsa yan yana göster
    if (sections.length >= 2) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildTimeColumn(sections[0], nowStr, isDark)),
            Container(
              width: 1,
              color: isDark ? Colors.white12 : Colors.grey.shade300,
            ),
            Expanded(child: _buildTimeColumn(sections[1], nowStr, isDark)),
          ],
        ),
      );
    }
    // Tek bölüm
    if (sections.length == 1) {
      return _buildTimeColumn(sections[0], nowStr, isDark);
    }
    return const SizedBox.shrink();
  }

  Widget _buildTimeColumn(
    Map<String, dynamic> section,
    String nowStr,
    bool isDark,
  ) {
    final name = (section['name'] ?? 'Hareket Saatleri') as String;
    final times = (section['times'] as List?)?.cast<String>() ?? [];
    final outOfService =
        (section['out_of_service'] as List?)?.cast<String>() ?? [];
    final allTimes = <_TimeEntry>[];

    for (final t in times) {
      allTimes.add(_TimeEntry(time: t, isActive: true));
    }
    for (final t in outOfService) {
      allTimes.add(_TimeEntry(time: t, isActive: false));
    }
    allTimes.sort((a, b) => a.time.compareTo(b.time));

    // Bir sonraki sefer
    String? nextTime;
    for (final entry in allTimes) {
      if (entry.isActive && entry.time.compareTo(nowStr) >= 0) {
        nextTime = entry.time;
        break;
      }
    }

    // Kısa başlık
    String shortTitle = name;
    if (name.toUpperCase().contains('MERKEZ')) {
      shortTitle = 'MERKEZ SEFER SAATLERİ';
    } else if (name.toUpperCase().contains('YYÜ') ||
        name.toUpperCase().contains('KAMPÜS') ||
        name.toUpperCase().contains('ÜNİVERSİTE')) {
      shortTitle = 'YYÜ SEFER SAATLERİ';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Sütun başlığı
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : const Color(0xFFFCE4EC),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            shortTitle,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 11,
              color: isDark ? Colors.white70 : const Color(0xFF880E4F),
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 4),
        // Saatler
        ...allTimes.map((entry) {
          final isNext = entry.time == nextTime && entry.isActive;
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
            margin: const EdgeInsets.symmetric(vertical: 1),
            decoration: BoxDecoration(
              color: isNext
                  ? (isDark
                        ? Colors.green.withOpacity(0.15)
                        : Colors.green.shade50)
                  : null,
              borderRadius: BorderRadius.circular(6),
              border: isNext
                  ? Border.all(color: Colors.green.shade300, width: 1)
                  : null,
            ),
            child: Row(
              children: [
                if (isNext)
                  const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Icon(
                      Icons.arrow_right,
                      size: 14,
                      color: Colors.green,
                    ),
                  ),
                Text(
                  entry.time,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isNext ? FontWeight.bold : FontWeight.w500,
                    color: !entry.isActive
                        ? Colors.grey
                        : isNext
                        ? Colors.green.shade700
                        : (isDark ? Colors.white : Colors.black87),
                    decoration: !entry.isActive
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                if (!entry.isActive)
                  Text(
                    '  ARIZALI',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if (isNext)
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Text(
                      '← sonraki',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }

  /// Yaklaşan otobüsler — kompakt kart listesi
  Widget _buildNextBuses(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final direction = busData['direction'] ?? 'YYÜ\'ye giden';
    final buses =
        (busData['buses'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    if (buses.isEmpty) return const SizedBox.shrink();

    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Başlık
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF003366),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(15),
                topRight: Radius.circular(15),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.directions_bus, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Yaklaşan $direction otobüsler',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          // Otobüs listesi
          ...buses.asMap().entries.map((entry) {
            final i = entry.key;
            final bus = entry.value;
            final isFirst = i == 0;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isFirst
                    ? (isDark
                          ? Colors.green.withOpacity(0.1)
                          : Colors.green.shade50)
                    : null,
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? Colors.white10 : Colors.grey.shade100,
                  ),
                ),
              ),
              child: Row(
                children: [
                  // Saat
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isFirst ? Colors.green : const Color(0xFF003366),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      bus['time'] ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Hat adı
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bus['short_name'] ?? bus['code'] ?? '',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isFirst)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'EN YAKIN',
                        style: TextStyle(
                          color: Colors.green.shade800,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            );
          }),
          // Alt bilgi
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.03)
                  : Colors.grey.shade50,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(15),
                bottomRight: Radius.circular(15),
              ),
            ),
            child: Text(
              '📋 van.bel.tr · Canlı veri',
              style: TextStyle(
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

/// Yeni Eklenen: Duyurular Kartı Oluşturma Widget'ı
class _DuyuruCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _DuyuruCard({Key? key, required this.data}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final items = data['items'] as List<dynamic>? ?? [];

    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, 4),
            blurRadius: 10,
          ),
        ],
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Başlık
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(15),
                topRight: Radius.circular(15),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.campaign_outlined,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Son Duyurular',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),

          // Duyuru Listesi
          ...items.take(10).map((item) {
            final idx = items.indexOf(item);
            final isLast = idx == (items.length - 1 < 9 ? items.length - 1 : 9);

            return Container(
              decoration: BoxDecoration(
                border: isLast
                    ? null
                    : Border(
                        bottom: BorderSide(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.grey.shade100,
                        ),
                      ),
              ),
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tarih rozeti
                  Container(
                    width: 50,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.blueGrey.shade800
                          : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Text(
                          item['date']?.toString().split('.').first ?? '',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        Text(
                          item['date']?.toString().substring(3) ?? '',
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Detaylar
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['title'] ?? '',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: isDark ? Colors.white : Colors.black87,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.account_balance_outlined,
                              size: 12,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                item['unit'] ?? '',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),

          // Alt bilgi (Tüm Duyurular Link Yönlendirme)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.03)
                  : Colors.grey.shade50,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(15),
                bottomRight: Radius.circular(15),
              ),
            ),
            child: SelectionArea(
              child: Text(
                'Dahası ve içerik detayları için yyu.edu.tr/tum-duyurular web sitemizi ziyaret edebilirsiniz.',
                style: TextStyle(
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EtkinlikCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _EtkinlikCard({Key? key, required this.data}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final String category = data['category'] ?? 'all';

    List<dynamic> items = [];
    if (category == 'club') {
      items = data['items'] ?? [];
    } else {
      items = [...(data['university'] ?? []), ...(data['club'] ?? [])];
    }

    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.indigo.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF3B1E4A), const Color(0xFF2E1B38)]
                    : [Colors.purple.shade600, Colors.deepPurple.shade700],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(15),
                topRight: Radius.circular(15),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  category == 'club' ? Icons.groups : Icons.celebration,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  category == 'club'
                      ? 'Öğrenci Topluluğu Etkinlikleri'
                      : 'Güncel Kampüs Etkinlikleri',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),

          // Events List
          ...items.take(10).map((item) {
            String title = item['title']?.toString() ?? 'Başlıksız';
            String date = item['date']?.toString() ?? '-';
            String unit = item['unit']?.toString() ?? '-';
            bool isClubEvent =
                unit.toLowerCase().contains('topluluğu') ||
                unit.toLowerCase().contains('kulübü');

            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? Colors.white10 : Colors.grey.shade200,
                  ),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isClubEvent
                          ? (isDark
                                ? Colors.orange.withValues(alpha: 0.2)
                                : Colors.orange.shade50)
                          : (isDark
                                ? Colors.purple.withValues(alpha: 0.2)
                                : Colors.purple.shade50),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isClubEvent ? Icons.groups : Icons.event,
                      color: isClubEvent
                          ? (isDark
                                ? Colors.orange.shade300
                                : Colors.orange.shade700)
                          : (isDark
                                ? Colors.purple.shade300
                                : Colors.purple.shade700),
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.grey.shade200
                                : const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 12,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              date,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Icon(
                              Icons.location_city,
                              size: 12,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                unit,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),

          // Footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.03)
                  : Colors.grey.shade50,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(15),
                bottomRight: Radius.circular(15),
              ),
            ),
            child: SelectionArea(
              child: Text(
                'Daha fazla etkinlik için yyu.edu.tr/tum-etkinlikler adresini ziyaret edebilirsiniz.',
                style: TextStyle(
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeEntry {
  final String time;
  final bool isActive;
  _TimeEntry({required this.time, required this.isActive});
}
