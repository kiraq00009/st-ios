import SwiftUI
import WebKit

/// أداة من لوحة الموقع تنفتح داخل التطبيق — تدخل بجلسة المدير تلقائيًّا (بلا ما تكتب كلمة السرّ)
struct WebTool: View {
    let path: String; let title: String
    @State private var loading = true
    @State private var reload = 0
    var body: some View {
        ZStack {
            WebBox(path: path, loading: $loading, reload: reload).ignoresSafeArea(edges: .bottom)
            if loading { ProgressView().tint(ST.am).padding(14).background(.ultraThinMaterial, in: Circle()) }
        }
        .background(ST.bg.ignoresSafeArea())
        .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { reload += 1 } label: { Image(systemName: "arrow.clockwise").font(.system(size: 14, weight: .semibold)) }
            }
        }
    }
}

struct WebBox: UIViewRepresentable {
    let path: String
    @Binding var loading: Bool
    var reload: Int

    func makeCoordinator() -> Co { Co(self) }

    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.allowsInlineMediaPlayback = true
        cfg.websiteDataStore = .nonPersistent()          // الجلسة بالذاكرة فقط — ما ينحفظ شي على الجهاز
        let w = WKWebView(frame: .zero, configuration: cfg)
        w.navigationDelegate = context.coordinator
        w.uiDelegate = context.coordinator
        w.isOpaque = false
        w.backgroundColor = UIColor(ST.bg); w.scrollView.backgroundColor = UIColor(ST.bg)
        w.allowsBackForwardNavigationGestures = true
        context.coordinator.seen = reload
        boot(w)
        return w
    }

    func updateUIView(_ w: WKWebView, context: Context) {
        if context.coordinator.seen != reload { context.coordinator.seen = reload; w.reload() }
    }

    /// صفحة تمهيد بنفس أصل الموقع: تفتح جلسة المدير ثمّ تنتقل للأداة
    private func boot(_ w: WKWebView) {
        let target = DW.base + (path.hasPrefix("/") ? path : "/" + path)
        let obj: [String: String] = ["token": Vault.get() ?? "", "to": target]
        let payload = (try? JSONSerialization.data(withJSONObject: obj)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        let html = "<!doctype html><html><head><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\">"
            + "<style>html,body{background:#04070e;margin:0}</style></head><body><script>"
            + "(async function(){var p=" + payload + ";"
            + "try{await fetch('/api/admin/session',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({token:p.token}),credentials:'same-origin'});}catch(e){}"
            + "try{sessionStorage.setItem('dw_admin_tok',p.token);localStorage.setItem('dw_admin_tok',p.token);}catch(e){}"
            + "location.replace(p.to);})();"
            + "</script></body></html>"
        w.loadHTMLString(html, baseURL: URL(string: DW.base + "/"))
    }

    final class Co: NSObject, WKNavigationDelegate, WKUIDelegate {
        let p: WebBox
        var seen = 0
        init(_ p: WebBox) { self.p = p }
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) { p.loading = true }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { p.loading = false }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { p.loading = false }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { p.loading = false }
        /// روابط «تبويب جديد» تنفتح بنفس الصفحة
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil, let u = navigationAction.request.url { webView.load(URLRequest(url: u)) }
            return nil
        }
        /// نوافذ التأكيد والتنبيه مال الصفحة (confirm/alert) — بدونها أزرار الحذف بالموقع ما تشتغل
        func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
            let a = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            a.addAction(UIAlertAction(title: "تمام", style: .default) { _ in completionHandler() })
            if !Self.show(a) { completionHandler() }
        }
        func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
            let a = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            a.addAction(UIAlertAction(title: "إلغاء", style: .cancel) { _ in completionHandler(false) })
            a.addAction(UIAlertAction(title: "موافق", style: .default) { _ in completionHandler(true) })
            if !Self.show(a) { completionHandler(false) }
        }
        func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
            let a = UIAlertController(title: nil, message: prompt, preferredStyle: .alert)
            a.addTextField { $0.text = defaultText }
            a.addAction(UIAlertAction(title: "إلغاء", style: .cancel) { _ in completionHandler(nil) })
            a.addAction(UIAlertAction(title: "موافق", style: .default) { _ in completionHandler(a.textFields?.first?.text) })
            if !Self.show(a) { completionHandler(nil) }
        }
        private static func show(_ a: UIAlertController) -> Bool {
            let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
            var top = scene?.windows.first { $0.isKeyWindow }?.rootViewController
            while let p = top?.presentedViewController { top = p }
            guard let top else { return false }
            top.present(a, animated: true); return true
        }
    }
}
