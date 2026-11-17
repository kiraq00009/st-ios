import SwiftUI
import Security

/// ألوان ستوديو = هويّة دورلي الجديدة (رمّانيّ، نفس :root بالموقع)
enum ST {
    static let bg = Color(hex: 0x121011)
    static let s1 = Color(hex: 0x1C1819)
    static let s2 = Color(hex: 0x262122)
    static let line = Color(hex: 0x2E2829)
    static let tx = Color(hex: 0xF3ECE2)
    static let tx2 = Color(hex: 0xA89F98), tx3 = Color(hex: 0x857C76)
    static let am = Color(hex: 0xE2445C)
    static let am2 = Color(hex: 0xF06A7E)
    static let onAm = Color(hex: 0xFFF5F2)
    static let red = Color(hex: 0xFF5A5F)
    static let green = Color(hex: 0x3DDC84)
    static let blue = Color(hex: 0x5B9BFF)
    static let violet = Color(hex: 0x9B7BFF)
    static let gold = Color(hex: 0xF5B83D)
    static let grad = LinearGradient(colors: [Color(hex: 0xF06A7E), Color(hex: 0xE2445C), Color(hex: 0xC93652)], startPoint: .topLeading, endPoint: .bottomTrailing)
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255, opacity: alpha)
    }
}

extension Font {
    /// خطّ الموقع: IBM Plex Sans Arabic (الاسم «cairo» باقٍ كاسم مستعار)
    static func cairo(_ size: CGFloat, _ w: Font.Weight = .regular) -> Font { .custom(STFont.name(w), size: size) }
}

enum STFont {
    static func name(_ w: Font.Weight) -> String {
        switch w {
        case .heavy, .black, .bold: return "IBMPlexSansArabic-Bold"
        case .semibold: return "IBMPlexSansArabic-SemiBold"
        case .medium: return "IBMPlexSansArabic-Medium"
        default: return "IBMPlexSansArabic-Regular"
        }
    }
    static func ui(_ size: CGFloat) -> UIFont { UIFont(name: "IBMPlexSansArabic-Bold", size: size) ?? .boldSystemFont(ofSize: size) }
}

/// لوغو دورلي (نفس svg.mk بالموقع، مربّع ٤٨)
struct DWPoly: Shape {
    let pts: [CGPoint]
    func path(in r: CGRect) -> Path {
        var p = Path()
        let s = min(r.width, r.height) / 48, ox = r.midX - 24 * s, oy = r.midY - 24 * s
        for (i, q) in pts.enumerated() {
            let c = CGPoint(x: ox + q.x * s, y: oy + q.y * s)
            if i == 0 { p.move(to: c) } else { p.addLine(to: c) }
        }
        p.closeSubpath(); return p
    }
}
struct DWMark: View {
    var body: some View {
        ZStack {
            DWPoly(pts: [CGPoint(x: 21, y: 5), CGPoint(x: 31, y: 5), CGPoint(x: 31, y: 14), CGPoint(x: 16, y: 14)]).fill(Color(hex: 0xB8304B))
            DWPoly(pts: [CGPoint(x: 31, y: 33), CGPoint(x: 40, y: 33), CGPoint(x: 40, y: 43), CGPoint(x: 5, y: 43), CGPoint(x: 11, y: 33)])
                .fill(LinearGradient(colors: [Color(hex: 0xC93652), Color(hex: 0x9C2441)], startPoint: .leading, endPoint: .trailing))
            DWPoly(pts: [CGPoint(x: 30, y: 5), CGPoint(x: 40, y: 5), CGPoint(x: 40, y: 43), CGPoint(x: 30, y: 43)])
                .fill(LinearGradient(stops: [.init(color: Color(hex: 0xFF8D9E), location: 0), .init(color: Color(hex: 0xE2445C), location: 0.5), .init(color: Color(hex: 0xA22743), location: 1)], startPoint: .top, endPoint: .bottom))
            DWPoly(pts: [CGPoint(x: 19, y: 16.5), CGPoint(x: 25.5, y: 23), CGPoint(x: 19, y: 29.5), CGPoint(x: 12.5, y: 23)])
                .fill(LinearGradient(colors: [Color(hex: 0xFFF8F0), Color(hex: 0xE4CDB6)], startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        .aspectRatio(1, contentMode: .fit)
        .environment(\.layoutDirection, .leftToRight)
    }
}

typealias J = [String: Any]

func jstr(_ o: J, _ k: String) -> String {
    if let s = o[k] as? String { return s }
    if let n = o[k] as? NSNumber { return n.stringValue }
    return ""
}
func jint(_ o: J, _ k: String) -> Int { (o[k] as? NSNumber)?.intValue ?? Int(jstr(o, k)) ?? 0 }
func jobj(_ o: J, _ k: String) -> J { (o[k] as? J) ?? [:] }
func jarr(_ o: J, _ k: String) -> [J] { (o[k] as? [J]) ?? [] }

/// كلمة سرّ المدير تنحفظ بخزنة الآيفون المشفّرة (Keychain) — ولا شي سرّيّ داخل التطبيق نفسه
enum Vault {
    private static let svc = "watch.dawwirli.studio", acc = "dawwirli-admin"
    static func get() -> String? {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: svc, kSecAttrAccount as String: acc,
                                kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let d = out as? Data else { return nil }
        return String(data: d, encoding: .utf8)
    }
    static func set(_ v: String) {
        clear()
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: svc, kSecAttrAccount as String: acc,
                                kSecValueData as String: Data(v.utf8), kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        SecItemAdd(q as CFDictionary, nil)
    }
    static func clear() {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: svc, kSecAttrAccount as String: acc]
        SecItemDelete(q as CFDictionary)
    }
}

/// نداءات لوحة دورلي (نفس نقاط panel.html)
enum DW {
    static let base = "https://premium.dawwirli.watch"
    static let session: URLSession = {
        let c = URLSessionConfiguration.default
        c.timeoutIntervalForRequest = 25; c.requestCachePolicy = .reloadIgnoringLocalCacheData
        c.httpAdditionalHeaders = ["User-Agent": "Dawwirli-Studio/2.1"]
        return URLSession(configuration: c)
    }()
    static func enc(_ s: String) -> String { s.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? s }

    enum Err: Error { case auth, net }

    private static func url(_ path: String, _ token: String) -> URL? {
        URL(string: base + path + (path.contains("?") ? "&" : "?") + "token=" + enc(token))
    }
    static func get(_ path: String, token: String? = Vault.get()) async throws -> J {
        guard let t = token, let u = url(path, t) else { throw Err.auth }
        let (d, r) = try await session.data(from: u)
        let code = (r as? HTTPURLResponse)?.statusCode ?? 0
        if code == 401 || code == 403 { throw Err.auth }
        guard (200..<300).contains(code) else { throw Err.net }
        return (try? JSONSerialization.jsonObject(with: d) as? J) ?? [:]
    }
    @discardableResult static func post(_ path: String, _ body: J) async throws -> J {
        guard let t = Vault.get(), let u = url(path, t) else { throw Err.auth }
        var r = URLRequest(url: u); r.httpMethod = "POST"; r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (d, resp) = try await session.data(for: r)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        if code == 401 || code == 403 { throw Err.auth }
        guard (200..<300).contains(code) else { throw Err.net }
        return (try? JSONSerialization.jsonObject(with: d) as? J) ?? [:]
    }
    @discardableResult static func del(_ path: String) async throws -> J {
        guard let t = Vault.get(), let u = url(path, t) else { throw Err.auth }
        var r = URLRequest(url: u); r.httpMethod = "DELETE"
        let (d, resp) = try await session.data(for: r)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        if code == 401 || code == 403 { throw Err.auth }
        guard (200..<300).contains(code) else { throw Err.net }
        return (try? JSONSerialization.jsonObject(with: d) as? J) ?? [:]
    }
    static func img(_ s: String) -> URL? {
        if s.isEmpty { return nil }
        if s.contains("image.tmdb.org") { return URL(string: base + "/api/img?u=" + enc(s)) }
        return URL(string: s.hasPrefix("/") ? base + s : s)
    }
    /// أسماء المزوّد فيها رموز (AR| · EN - · [4K]) — ننظّفها للعرض
    static func clean(_ n: String) -> String {
        var s = n
        for r in ["^\\s*[A-Z]{2,4}\\s*[|\\-–]\\s*", "\\[[^\\]]*\\]", "\\s*[-–]\\s*(19|20)\\d{2}\\s*$"] { s = s.replacingOccurrences(of: r, with: "", options: .regularExpression) }
        return s.trimmingCharacters(in: .whitespaces)
    }
}

func ago(_ ms: Double) -> String {
    guard ms > 0 else { return "" }
    let s = Int(Date().timeIntervalSince1970 - ms / 1000)
    if s < 60 { return "هسه" }; if s < 3600 { return "قبل \(s / 60) د" }; if s < 86400 { return "قبل \(s / 3600) س" }
    return "قبل \(s / 86400) يوم"
}

// MARK: - مكوّنات مشتركة
struct Card<C: View>: View {
    @ViewBuilder let content: () -> C
    var body: some View {
        content().padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(ST.s1, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color(white: 1, opacity: 0.07)))
    }
}

struct Tile: View {
    let value: String; let label: String; var icon: String = ""; var tint: Color = ST.am
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !icon.isEmpty { Image(systemName: icon).font(.system(size: 14, weight: .bold)).foregroundStyle(tint) }
            Text(value).font(.system(size: 24, weight: .heavy, design: .rounded)).foregroundStyle(ST.tx).lineLimit(1).minimumScaleFactor(0.6)
            Text(label).font(.cairo(11.5)).foregroundStyle(ST.tx3).lineLimit(1)
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background(ST.s1, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(tint.opacity(0.25)))
    }
}

struct Pill: View {
    let text: String; var tint: Color = ST.am
    var body: some View {
        Text(text).font(.cairo(11, .bold)).foregroundStyle(tint).padding(.horizontal, 8).padding(.vertical, 2)
            .background(tint.opacity(0.14), in: Capsule())
    }
}

struct Poster: View {
    let url: URL?; var w: CGFloat = 46
    var body: some View {
        AsyncImage(url: url) { ph in
            if case .success(let i) = ph { i.resizable().aspectRatio(contentMode: .fill) } else { ST.s2 }
        }
        .frame(width: w, height: w * 1.5).clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct STBackground: View {
    var body: some View {
        ZStack {
            ST.bg
            RadialGradient(colors: [ST.am.opacity(0.10), Color.clear], center: .top, startRadius: 0, endRadius: 520)
        }.ignoresSafeArea()
    }
}

/// تحميل دوريّ بحالات جارٍ/خطأ/جاهز — يحدّث كلّ `every` ثانية طول ما الصفحة ظاهرة
struct Live<T, C: View>: View {
    var every: Double = 10
    let load: () async throws -> T
    @ViewBuilder let content: (T, @escaping () -> Void) -> C
    @EnvironmentObject var auth: Auth
    @State private var value: T?
    @State private var failed = false
    @State private var bump = 0
    var body: some View {
        Group {
            if let v = value { content(v) { bump += 1 } }
            else if failed {
                VStack(spacing: 12) {
                    Text("ما وصلنا للسيرفر").font(.cairo(15, .bold)).foregroundStyle(ST.tx2)
                    Button("إعادة المحاولة") { bump += 1 }.font(.cairo(14, .bold)).foregroundStyle(ST.am)
                }.frame(maxWidth: .infinity).padding(.top, 80)
            } else { ProgressView().tint(ST.am).frame(maxWidth: .infinity).padding(.top, 80) }
        }
        .task(id: bump) {
            while !Task.isCancelled {
                do { value = try await load(); failed = false }
                catch DW.Err.auth { auth.logout(); return }
                catch { if value == nil { failed = true } }
                try? await Task.sleep(nanoseconds: UInt64(every * 1_000_000_000))
            }
        }
    }
}
