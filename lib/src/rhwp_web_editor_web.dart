import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import 'rhwp_document.dart';
import 'rhwp_exception.dart';

@JS('__flutterRhwpWebEditorExport')
external JSPromise<JSString> _exportEditorBytes(String hostId, String format);

class RhwpWebEditorController extends ChangeNotifier {
  String? _hostId;

  bool get isAttached => _hostId != null;

  Future<Uint8List> export(RhwpExportFormat format) async {
    final hostId = _hostId;
    if (hostId == null) {
      throw const RhwpUnsupportedPlatformException(
        'The rhwp Web editor is not attached to a mounted widget.',
      );
    }

    try {
      final result = await _exportEditorBytes(hostId, format.name).toDart;
      return base64Decode(result.toDart);
    } catch (error) {
      throw RhwpUnsupportedPlatformException(error.toString());
    }
  }

  Future<Uint8List> exportHwp() => export(RhwpExportFormat.hwp);

  Future<Uint8List> exportHwpx() => export(RhwpExportFormat.hwpx);

  Future<Uint8List> exportPdf() => export(RhwpExportFormat.pdf);

  Future<Uint8List> exportDocx() => export(RhwpExportFormat.docx);

  Future<Uint8List> exportText() => export(RhwpExportFormat.text);

  Future<Uint8List> exportMarkdown() => export(RhwpExportFormat.markdown);

  Future<Uint8List> exportPageSvg() => export(RhwpExportFormat.svg);

  void _attach(String hostId) {
    _hostId = hostId;
    notifyListeners();
  }

  void _detach(String hostId) {
    if (_hostId == hostId) {
      _hostId = null;
      notifyListeners();
    }
  }
}

class RhwpWebEditor extends StatefulWidget {
  const RhwpWebEditor({
    super.key,
    this.moduleUrl = defaultModuleUrl,
    this.initialBytes,
    this.fileName,
    this.controller,
  });

  static const defaultModuleUrl = 'https://esm.sh/@rhwp/editor';

  final String moduleUrl;
  final Uint8List? initialBytes;
  final String? fileName;
  final RhwpWebEditorController? controller;

  @override
  State<RhwpWebEditor> createState() => _RhwpWebEditorState();
}

class _RhwpWebEditorState extends State<RhwpWebEditor> {
  static var _nextViewId = 0;

  late final String _viewType;
  late final String _hostId;
  late RhwpWebEditorController _controller;
  late bool _ownsController;

  @override
  void initState() {
    super.initState();
    final viewId = _nextViewId++;
    _viewType = 'flutter-rhwp-web-editor-$viewId';
    _hostId = 'flutter-rhwp-web-editor-host-$viewId';
    _controller = widget.controller ?? RhwpWebEditorController();
    _ownsController = widget.controller == null;
    _controller._attach(_hostId);
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (_) => _createEditorHost(),
    );
  }

  @override
  void didUpdateWidget(covariant RhwpWebEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) {
      return;
    }
    _controller._detach(_hostId);
    if (_ownsController) {
      _controller.dispose();
    }
    _controller = widget.controller ?? RhwpWebEditorController();
    _ownsController = widget.controller == null;
    _controller._attach(_hostId);
  }

  @override
  void dispose() {
    _controller._detach(_hostId);
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  web.HTMLElement _createEditorHost() {
    final host = web.HTMLDivElement()
      ..id = _hostId
      ..style.setProperty('width', '100%')
      ..style.setProperty('height', '100%')
      ..style.setProperty('min-height', '480px')
      ..style.setProperty('background', '#ffffff')
      ..style.setProperty('overflow', 'hidden');

    _appendBootstrapScript(_hostId);
    return host;
  }

  void _appendBootstrapScript(String hostId) {
    final script = web.HTMLScriptElement()
      ..type = 'module'
      ..text = _bootstrapScript(hostId);
    web.document.head!.append(script);
  }

  String _bootstrapScript(String hostId) {
    final initialBytes = widget.initialBytes;
    final initialBase64 = initialBytes == null
        ? null
        : base64Encode(initialBytes);

    return '''
(() => {
  const hostId = ${jsonEncode(hostId)};
  const moduleUrl = ${jsonEncode(widget.moduleUrl)};
  const fileName = ${jsonEncode(widget.fileName)};
  const initialBase64 = ${jsonEncode(initialBase64)};

  window.__flutterRhwpWebEditors = window.__flutterRhwpWebEditors || new Map();

  function installExportBridge() {
    if (typeof window.__flutterRhwpWebEditorExport === 'function') {
      return;
    }

    window.__flutterRhwpWebEditorExport = async function exportEditorBytes(hostId, format) {
      const editor = window.__flutterRhwpWebEditors?.get(hostId);
      if (!editor) {
        throw new Error('rhwp Web editor is not mounted yet.');
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
    };
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

  installExportBridge();

  function setMessage(host, title, detail) {
    host.replaceChildren();
    const box = document.createElement('div');
    box.style.cssText = 'height:100%;box-sizing:border-box;padding:24px;display:flex;flex-direction:column;justify-content:center;align-items:center;gap:8px;background:#f8fafc;color:#101828;font:14px system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;text-align:center;';
    const heading = document.createElement('strong');
    heading.textContent = title;
    const body = document.createElement('span');
    body.textContent = detail;
    body.style.cssText = 'max-width:640px;color:#475467;';
    box.append(heading, body);
    host.append(box);
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

  async function tryOpenInitialBytes(editor, bytes) {
    if (!bytes) return false;
    const candidates = ['openBytes', 'loadBytes', 'openHwp', 'loadHwp', 'importHwp'];
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
        } catch (_) {
          // Try the next likely iframe-wrapper signature.
        }
      }
    }
    return false;
  }

  async function waitForHost() {
    for (let i = 0; i < 120; i += 1) {
      const host = document.getElementById(hostId);
      if (host) return host;
      await new Promise((resolve) => requestAnimationFrame(resolve));
    }
    throw new Error('rhwp Web editor mount element was not inserted.');
  }

  async function start() {
    const host = await waitForHost();
    setMessage(host, 'Loading rhwp Web editor...', moduleUrl);

    if (!moduleUrl) {
      setMessage(
        host,
        'rhwp Web editor module URL is missing.',
        'Pass RhwpWebEditor(moduleUrl: ...) or set RHWP_EDITOR_MODULE_URL in the example app.',
      );
      return;
    }

    try {
      const module = await import(moduleUrl);
      if (typeof module.createEditor !== 'function') {
        throw new Error('The module does not export createEditor(selector).');
      }

      host.replaceChildren();
      const editor = await module.createEditor('#' + hostId);
      window.__flutterRhwpWebEditors.set(hostId, editor);

      const bytes = decodeBase64(initialBase64);
      const didOpen = await tryOpenInitialBytes(editor, bytes);
      if (bytes && !didOpen) {
        console.warn(
          'rhwp Web editor was mounted, but this @rhwp/editor build did not expose a known byte-loading API.',
        );
      }
    } catch (error) {
      console.error(error);
      setMessage(
        host,
        'Unable to load rhwp Web editor.',
        String(error?.message || error),
      );
    }
  }

  start();
})();
''';
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
