import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_all/webview_all.dart';

import 'rhwp_document.dart';
import 'rhwp_exception.dart';
import 'rhwp_web_editor.dart';

class RhwpFullEditorController extends ChangeNotifier {
  WebViewController? _webViewController;
  var _nextRequest = 0;
  final _pendingExports = <String, Completer<Uint8List>>{};

  bool get isAttached => _webViewController != null;

  Future<Uint8List> export(RhwpExportFormat format) async {
    final webViewController = _webViewController;
    if (webViewController == null) {
      throw const RhwpUnsupportedPlatformException(
        'The rhwp full editor is not attached to a mounted widget.',
      );
    }

    final requestId = 'export-${_nextRequest++}';
    final completer = Completer<Uint8List>();
    _pendingExports[requestId] = completer;
    await webViewController.runJavaScript(
      'window.__flutterRhwpFullEditorRequestExport'
      '(${jsonEncode(requestId)}, ${jsonEncode(format.name)});',
    );
    return completer.future.timeout(
      const Duration(seconds: 45),
      onTimeout: () {
        _pendingExports.remove(requestId);
        throw RhwpUnsupportedPlatformException(
          'Timed out while exporting ${format.name} from the rhwp full editor.',
        );
      },
    );
  }

  Future<RhwpExportedDocument> exportDocument(
    RhwpExportFormat format, {
    String? sourceFileName,
    int? page,
  }) async {
    final bytes = await export(format);
    return RhwpExportedDocument.fromBytes(
      format: format,
      bytes: bytes,
      sourceFileName: sourceFileName,
      page: page,
    );
  }

  Future<Uint8List> exportHwp() => export(RhwpExportFormat.hwp);

  Future<Uint8List> exportHwpx() => export(RhwpExportFormat.hwpx);

  Future<Uint8List> exportPdf() => export(RhwpExportFormat.pdf);

  Future<Uint8List> exportDocx() => export(RhwpExportFormat.docx);

  Future<Uint8List> exportText() => export(RhwpExportFormat.text);

  Future<Uint8List> exportMarkdown() => export(RhwpExportFormat.markdown);

  Future<Uint8List> exportPageSvg() => export(RhwpExportFormat.svg);

  void _attach(WebViewController webViewController) {
    _webViewController = webViewController;
    notifyListeners();
  }

  void _detach(WebViewController webViewController) {
    if (_webViewController == webViewController) {
      _webViewController = null;
      for (final completer in _pendingExports.values) {
        if (!completer.isCompleted) {
          completer.completeError(
            const RhwpUnsupportedPlatformException(
              'The rhwp full editor was detached before export completed.',
            ),
          );
        }
      }
      _pendingExports.clear();
      notifyListeners();
    }
  }

  void _handleMessage(String message) {
    final decoded = jsonDecode(message);
    if (decoded is! Map<String, Object?>) {
      return;
    }

    final id = decoded['id'];
    if (id is! String) {
      return;
    }

    final completer = _pendingExports.remove(id);
    if (completer == null || completer.isCompleted) {
      return;
    }

    if (decoded['ok'] == true) {
      final data = decoded['data'];
      if (data is String) {
        completer.complete(base64Decode(data));
      } else {
        completer.completeError(
          const RhwpException('The rhwp full editor returned no export bytes.'),
        );
      }
    } else {
      completer.completeError(
        RhwpUnsupportedPlatformException(
          decoded['error']?.toString() ?? 'The rhwp full editor export failed.',
        ),
      );
    }
  }
}

class RhwpFullEditor extends StatefulWidget {
  const RhwpFullEditor({
    super.key,
    this.moduleUrl = RhwpWebEditor.defaultModuleUrl,
    this.initialBytes,
    this.fileName,
    this.controller,
  });

  final String moduleUrl;
  final Uint8List? initialBytes;
  final String? fileName;
  final RhwpFullEditorController? controller;

  @override
  State<RhwpFullEditor> createState() => _RhwpFullEditorState();
}

class _RhwpFullEditorState extends State<RhwpFullEditor> {
  late RhwpFullEditorController _controller;
  late bool _ownsController;
  WebViewController? _webViewController;
  Object? _webViewError;
  var _pageReady = false;
  String? _hostMessage = 'Loading rhwp full editor...';

  bool get _supportsInlineWebView {
    return switch (defaultTargetPlatform) {
      TargetPlatform.android ||
      TargetPlatform.iOS ||
      TargetPlatform.linux ||
      TargetPlatform.macOS ||
      TargetPlatform.windows => true,
      TargetPlatform.fuchsia => false,
    };
  }

  bool get _hasRegisteredWebView => WebViewPlatform.instance != null;

  bool get _canHostInlineWebView =>
      _supportsInlineWebView && _hasRegisteredWebView;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? RhwpFullEditorController();
    _ownsController = widget.controller == null;
    if (_canHostInlineWebView) {
      _createWebViewController();
    }
  }

  @override
  void didUpdateWidget(covariant RhwpFullEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      final webViewController = _webViewController;
      if (webViewController != null) {
        _controller._detach(webViewController);
      }
      if (_ownsController) {
        _controller.dispose();
      }
      _controller = widget.controller ?? RhwpFullEditorController();
      _ownsController = widget.controller == null;
      if (webViewController != null) {
        _controller._attach(webViewController);
      }
    }

    if (oldWidget.moduleUrl != widget.moduleUrl ||
        oldWidget.fileName != widget.fileName ||
        !listEquals(oldWidget.initialBytes, widget.initialBytes)) {
      setState(() {
        _pageReady = false;
        _hostMessage = 'Loading rhwp full editor...';
      });
      _webViewController?.loadHtmlString(_html());
    }
  }

  @override
  void dispose() {
    final webViewController = _webViewController;
    if (webViewController != null) {
      _controller._detach(webViewController);
    }
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _createWebViewController() {
    final webViewController = WebViewController();
    _webViewError = null;
    _pageReady = false;
    _hostMessage = 'Loading rhwp full editor...';
    _webViewController = webViewController;
    _controller._attach(webViewController);
    unawaited(
      _prepareWebViewController(webViewController).catchError((
        Object error,
        StackTrace stackTrace,
      ) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'flutter_rhwp',
            context: ErrorDescription('while preparing RhwpFullEditor WebView'),
          ),
        );
        if (mounted && _webViewController == webViewController) {
          _controller._detach(webViewController);
          setState(() {
            _webViewController = null;
            _webViewError = error;
            _hostMessage =
                'Unable to prepare the rhwp full editor WebView: $error';
          });
        }
      }),
    );
  }

  Future<void> _prepareWebViewController(
    WebViewController webViewController,
  ) async {
    await webViewController.setJavaScriptMode(JavaScriptMode.unrestricted);
    if (defaultTargetPlatform != TargetPlatform.macOS) {
      await webViewController.setBackgroundColor(Colors.white);
    }
    await webViewController.addJavaScriptChannel(
      'RhwpFullEditorChannel',
      onMessageReceived: (message) {
        _handleWebViewMessage(message.message);
      },
    );
    if (!mounted || _webViewController != webViewController) {
      return;
    }
    await webViewController.loadHtmlString(_html());
  }

  void _handleWebViewMessage(String message) {
    try {
      final decoded = jsonDecode(message);
      if (decoded is Map<String, Object?>) {
        final event = decoded['event'];
        if (event == 'ready') {
          if (mounted) {
            setState(() {
              _pageReady = true;
              _hostMessage = null;
            });
          }
          return;
        }
        if (event == 'error') {
          if (mounted) {
            setState(() {
              _pageReady = false;
              _hostMessage =
                  'Unable to load rhwp full editor: ${decoded['error'] ?? 'Unknown error'}';
            });
          }
          return;
        }
      }
    } catch (_) {
      // Export responses are handled by the controller below.
    }

    _controller._handleMessage(message);
  }

  @override
  Widget build(BuildContext context) {
    final webViewController = _webViewController;
    if (!_supportsInlineWebView) {
      return const _RhwpFullEditorMessage(
        'The rhwp full editor requires Android, iOS, macOS, Windows, Linux, or Web.',
      );
    }
    if (!_hasRegisteredWebView) {
      return const _RhwpFullEditorMessage(
        'No WebView implementation is registered for this Flutter runtime.',
      );
    }
    final webViewError = _webViewError;
    if (webViewError != null) {
      return _RhwpFullEditorMessage(
        'Unable to prepare the rhwp full editor WebView: $webViewError',
      );
    }
    if (webViewController == null) {
      return const _RhwpFullEditorMessage('Loading rhwp full editor...');
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        WebViewWidget(controller: webViewController),
        if (!_pageReady)
          _RhwpFullEditorMessage(_hostMessage ?? 'Loading rhwp full editor...'),
      ],
    );
  }

  String _html() {
    final initialBase64 = widget.initialBytes == null
        ? null
        : base64Encode(widget.initialBytes!);

    return '''
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>
    html, body, #editor {
      width: 100%;
      height: 100%;
      margin: 0;
      overflow: hidden;
      background: #d9d9d9;
      font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    }
    #message {
      position: absolute;
      inset: 0;
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 24px;
      box-sizing: border-box;
      color: #101828;
      background: #f8fafc;
      text-align: center;
      z-index: 1;
    }
  </style>
</head>
<body>
  <div id="message">Loading rhwp full editor...</div>
  <div id="editor"></div>
  <script type="module">
${_bootstrapScript(initialBase64)}
  </script>
</body>
</html>
''';
  }

  String _bootstrapScript(String? initialBase64) {
    return '''
const moduleUrl = ${jsonEncode(widget.moduleUrl)};
const fileName = ${jsonEncode(widget.fileName)};
const initialBase64 = ${jsonEncode(initialBase64)};
let editor = null;

function post(payload) {
  RhwpFullEditorChannel.postMessage(JSON.stringify(payload));
}

function setMessage(message) {
  const node = document.getElementById('message');
  if (node) node.textContent = message;
}

function hideMessage() {
  document.getElementById('message')?.remove();
}

function decodeBase64(value) {
  if (!value) return null;
  const binary = atob(value);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i += 1) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

function exportCandidates(format) {
  const noArgs = [[]];
  const firstPageArgs = [[], [0], [{ page: 0 }]];
  const map = {
    hwp: [
      { name: 'exportHwp', args: noArgs },
      { name: 'saveHwp', args: noArgs },
    ],
    hwpx: [
      { name: 'exportHwpx', args: noArgs },
      { name: 'saveHwpx', args: noArgs },
    ],
    pdf: [
      { name: 'exportPdf', args: noArgs },
      { name: 'savePdf', args: noArgs },
    ],
    docx: [
      { name: 'exportDocx', args: noArgs },
      { name: 'saveDocx', args: noArgs },
    ],
    text: [
      { name: 'exportText', args: firstPageArgs },
      { name: 'extractText', args: firstPageArgs },
    ],
    markdown: [
      { name: 'exportMarkdown', args: firstPageArgs },
      { name: 'extractMarkdown', args: firstPageArgs },
    ],
      svg: [
        { name: 'exportSvg', args: firstPageArgs },
        { name: 'getPageSvg', args: firstPageArgs },
        { name: 'renderPageSvg', args: firstPageArgs },
        { name: 'renderSvg', args: firstPageArgs },
      ],
  };
  return map[format] || [];
}

async function normalizeExportBytes(value) {
  if (value == null) {
    throw new Error('Export returned no data.');
  }
  if (value instanceof Uint8Array) {
    return value;
  }
  if (value instanceof ArrayBuffer) {
    return new Uint8Array(value);
  }
  if (value instanceof Blob) {
    return normalizeExportBytes(await value.arrayBuffer());
  }
  if (Array.isArray(value)) {
    return new Uint8Array(value.map((byte) => Number(byte) & 255));
  }
  if (typeof value === 'string') {
    return new TextEncoder().encode(value);
  }
  if (value.bytes != null) {
    return normalizeExportBytes(value.bytes);
  }
  if (value.data != null) {
    return normalizeExportBytes(value.data);
  }
  throw new Error('Unsupported export return type: ' + Object.prototype.toString.call(value));
}

function bytesToBase64(bytes) {
  let binary = '';
  const chunkSize = 0x8000;
  for (let offset = 0; offset < bytes.length; offset += chunkSize) {
    const chunk = bytes.subarray(offset, offset + chunkSize);
    binary += String.fromCharCode(...chunk);
  }
  return btoa(binary);
}

async function exportEditorBytes(format) {
  if (!editor) {
    throw new Error('rhwp full editor is not mounted yet.');
  }

  const candidates = exportCandidates(format);
  let lastError = null;
  for (const candidate of candidates) {
    const method = editor?.[candidate.name];
    if (typeof method !== 'function') continue;
    for (const args of candidate.args) {
      try {
        const value = await method.apply(editor, args);
        return bytesToBase64(await normalizeExportBytes(value));
      } catch (error) {
        lastError = error;
      }
    }
  }

  const suffix = lastError ? ' Last error: ' + String(lastError?.message || lastError) : '';
  throw new Error('This @rhwp/editor build does not expose an export API for ' + format + '.' + suffix);
}

window.__flutterRhwpFullEditorRequestExport = async function requestExport(id, format) {
  try {
    post({ id, ok: true, data: await exportEditorBytes(format) });
  } catch (error) {
    post({ id, ok: false, error: String(error?.message || error) });
  }
};

async function tryOpenInitialBytes(bytes) {
  if (!bytes) return false;
  const candidates = ['loadFile', 'openBytes', 'loadBytes', 'openHwp', 'loadHwp', 'importHwp'];
  let lastError = null;
  for (const name of candidates) {
    if (typeof editor?.[name] !== 'function') continue;
    const attempts = [
      [bytes, { fileName }],
      [bytes, fileName],
      [{ bytes, fileName }],
      [bytes],
    ];
    for (const args of attempts) {
      try {
        await editor[name](...args);
        return true;
      } catch (error) {
        lastError = error;
        // Try the next likely iframe-wrapper signature.
      }
    }
  }
  if (lastError) {
    throw lastError;
  }
  return false;
}

async function start() {
  if (!moduleUrl) {
    setMessage('rhwp full editor module URL is missing.');
    post({ event: 'error', error: 'rhwp full editor module URL is missing.' });
    return;
  }

  try {
    const module = await import(moduleUrl);
    if (typeof module.createEditor !== 'function') {
      throw new Error('The module does not export createEditor(selector).');
    }

    editor = await module.createEditor('#editor');
    hideMessage();

    const bytes = decodeBase64(initialBase64);
    const didOpen = await tryOpenInitialBytes(bytes);
    if (bytes && !didOpen) {
      throw new Error(
        'rhwp full editor was mounted, but this @rhwp/editor build did not expose a known byte-loading API.',
      );
    }
    post({ event: 'ready' });
  } catch (error) {
    console.error(error);
    const message = String(error?.message || error);
    setMessage('Unable to load rhwp full editor: ' + message);
    post({ event: 'error', error: message });
  }
}

start();
''';
  }
}

class _RhwpFullEditorMessage extends StatelessWidget {
  const _RhwpFullEditorMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xfff8fafc),
      child: Center(child: Text(message, textAlign: TextAlign.center)),
    );
  }
}
