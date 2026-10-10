import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

const kBg = Color(0xFF0F172A);
const kPrimary = Color(0xFF3B82F6);
const kHome = 'https://gopq.lovable.app';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: kBg,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: kBg,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const GopqApp());
}

class GopqApp extends StatelessWidget {
  const GopqApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Gopq',
        theme: ThemeData(brightness: Brightness.dark, scaffoldBackgroundColor: kBg),
        home: const WebViewScreen(),
      );
}

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});
  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController controller;
  int progress = 0;
  bool hasError = false;
  bool firstLoad = true;

  bool _isInternal(Uri u) =>
      u.host == 'gopq.lovable.app' || u.host.endsWith('.supabase.co') || u.host.endsWith('lovable.app');

  bool _isFile(String url) {
    final l = url.toLowerCase().split('?').first;
    return ['.mp4', '.mp3', '.m4a', '.webm', '.jpg', '.jpeg', '.png', '.gif', '.zip', '.apk']
        .any((e) => l.endsWith(e)) || url.contains('proxy-media');
  }

  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(kBg)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) => mounted ? setState(() => progress = p) : null,
        onPageStarted: (_) => mounted ? setState(() => hasError = false) : null,
        onPageFinished: (_) => mounted ? setState(() { progress = 100; firstLoad = false; }) : null,
        onWebResourceError: (e) {
          if (e.isForMainFrame ?? true) {
            if (mounted) setState(() => hasError = true);
          }
        },
        onNavigationRequest: (req) {
          final uri = Uri.parse(req.url);
          if (req.url.startsWith('blob:') || req.url.startsWith('data:')) {
            return NavigationDecision.navigate;
          }
          if (_isFile(req.url) || !_isInternal(uri)) {
            launchUrl(uri, mode: LaunchMode.externalApplication);
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ));
    _loadFresh();
  }

  Future<void> _loadFresh() async {
    await controller.clearCache();
    final v = DateTime.now().millisecondsSinceEpoch;
    await controller.loadRequest(Uri.parse('$kHome/?app=1&v=$v'), headers: const {
      'Cache-Control': 'no-cache, no-store, must-revalidate',
      'Pragma': 'no-cache',
    });
  }

  Future<void> _refresh() async {
    setState(() { hasError = false; progress = 0; });
    await _loadFresh();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await controller.canGoBack()) {
          controller.goBack();
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: kBg,
        body: SafeArea(
          child: hasError
              ? _error()
              : Stack(children: [
                  WebViewWidget(controller: controller),
                  if (progress < 100 && !firstLoad)
                    const SizedBox.shrink(),
                  if (progress < 100)
                    LinearProgressIndicator(
                      value: progress / 100,
                      backgroundColor: Colors.transparent,
                      valueColor: const AlwaysStoppedAnimation(kPrimary),
                      minHeight: 2.5,
                    ),
                  if (firstLoad)
                    Container(
                      color: kBg,
                      alignment: Alignment.center,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Image.asset('assets/icon.png', width: 96, height: 96),
                        ),
                        const SizedBox(height: 20),
                        const CircularProgressIndicator(color: kPrimary, strokeWidth: 2.5),
                      ]),
                    ),
                  Positioned(
                    right: 16,
                    bottom: 90,
                    child: FloatingActionButton.small(
                      backgroundColor: kPrimary.withOpacity(0.85),
                      onPressed: _refresh,
                      child: const Icon(Icons.refresh_rounded, color: Colors.white),
                    ),
                  ),
                ]),
        ),
      ),
    );
  }

  Widget _error() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.wifi_off_rounded, size: 64, color: Color(0xFF94A3B8)),
          const SizedBox(height: 16),
          const Text('لا يوجد اتصال بالإنترنت',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _refresh,
            style: ElevatedButton.styleFrom(backgroundColor: kPrimary),
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            label: const Text('إعادة المحاولة', style: TextStyle(color: Colors.white)),
          ),
        ]),
      );
}
