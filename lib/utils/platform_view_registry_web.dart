import 'dart:html' as html;
import 'dart:ui_web' as ui;

final Map<String, html.IFrameElement> _pdfIframes = {};

void registerPdfViewFactory(String viewType, String url) {
  // ignore: undefined_prefixed_name
  ui.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
    final element = html.IFrameElement()
      ..src = url
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%';
    _pdfIframes[viewType] = element;
    return element;
  });
}

void setPdfViewPointerEvents(String viewType, bool enabled) {
  final iframe = _pdfIframes[viewType];
  if (iframe == null) return;
  iframe.style.pointerEvents = enabled ? 'auto' : 'none';
}

void postPdfViewMessage(String viewType, Object message) {
  final iframe = _pdfIframes[viewType];
  if (iframe == null) return;
  iframe.contentWindow?.postMessage(message, '*');
}
