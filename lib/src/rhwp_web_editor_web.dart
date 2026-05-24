import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

class RhwpWebEditor extends StatefulWidget {
  const RhwpWebEditor({
    super.key,
    this.moduleUrl = defaultModuleUrl,
    this.initialBytes,
    this.fileName,
  });

  static const defaultModuleUrl = 'https://esm.sh/@rhwp/editor';

  final String moduleUrl;
  final Uint8List? initialBytes;
  final String? fileName;

  @override
  State<RhwpWebEditor> createState() => _RhwpWebEditorState();
}

class _RhwpWebEditorState extends State<RhwpWebEditor> {
  static var _nextViewId = 0;

  late final String _viewType;

  @override
  void initState() {
    super.initState();
    final viewId = _nextViewId++;
    _viewType = 'flutter-rhwp-web-editor-$viewId';
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (_) => _createEditorHost(viewId),
    );
  }

  web.HTMLElement _createEditorHost(int viewId) {
    final hostId = 'flutter-rhwp-web-editor-host-$viewId';
    final host = web.HTMLDivElement()
      ..id = hostId
      ..style.setProperty('width', '100%')
      ..style.setProperty('height', '100%')
      ..style.setProperty('min-height', '480px')
      ..style.setProperty('background', '#ffffff')
      ..style.setProperty('overflow', 'hidden');

    _appendBootstrapScript(hostId);
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
