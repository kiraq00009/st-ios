import SwiftUI

/// Studio — لوحة تحكّم المالك لكلّ مشاريعه. أوّل مشروع: دورلي.
@main
struct StudioApp: App {
    @StateObject private var auth = Auth()
    init() {
        let nb = UINavigationBarAppearance(); nb.configureWithTransparentBackground()
        nb.titleTextAttributes = [.foregroundColor: UIColor(ST.tx), .font: STFont.ui(17)]
        nb.largeTitleTextAttributes = [.foregroundColor: UIColor(ST.tx), .font: STFont.ui(30)]
        UINavigationBar.appearance().standardAppearance = nb; UINavigationBar.appearance().scrollEdgeAppearance = nb
        UINavigationBar.appearance().tintColor = UIColor(ST.am)
    }
    var body: some Scene {
        WindowGroup {
            Group {
                if auth.ok { NavigationStack { ProjectsView() } } else { LoginView() }
            }
            .environmentObject(auth)
            .environment(\.layoutDirection, .rightToLeft)
            .preferredColorScheme(.dark)
            .tint(ST.am)
        }
    }
}

@MainActor
final class Auth: ObservableObject {
    @Published var ok = Vault.get() != nil
    func login(_ pw: String) async -> Bool {
        do { _ = try await DW.get("/api/admin/stats", token: pw); Vault.set(pw); ok = true; return true }
        catch { return false }
    }
    func logout() { Vault.clear(); ok = false }
}

// MARK: - الدخول
struct LoginView: View {
    @EnvironmentObject var auth: Auth
    @State private var pw = ""
    @State private var busy = false
    @State private var bad = false
    var body: some View {
        ZStack {
            STBackground()
            VStack(spacing: 18) {
                ZStack {
                    RoundedRectangle(cornerRadius: 24).fill(ST.s1).frame(width: 88, height: 88)
                        .overlay(RoundedRectangle(cornerRadius: 24).stroke(ST.am.opacity(0.35)))
                        .shadow(color: ST.am.opacity(0.35), radius: 22, y: 8)
                    DWMark().frame(width: 56, height: 56)
                }
                Text("Studio").font(.system(size: 34, weight: .bold)).foregroundStyle(ST.tx)
                Text("لوحة تحكّم مشاريعك").font(.cairo(15)).foregroundStyle(ST.tx2)
                SecureField("", text: $pw, prompt: Text("كلمة سرّ المدير").foregroundColor(ST.tx3))
                    .font(.system(size: 16)).foregroundStyle(ST.tx).multilineTextAlignment(.center)
                    .padding(14).background(ST.s2, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(bad ? ST.red : Color(white: 1, opacity: 0.1)))
                    .padding(.top, 16).submitLabel(.go).onSubmit(go)
                if bad { Text("كلمة السرّ غلط، أو السيرفر ما يردّ").font(.cairo(12.5)).foregroundStyle(ST.red) }
                Button(action: go) {
                    HStack { if busy { ProgressView().tint(ST.onAm) }; Text("دخول").font(.cairo(16, .heavy)) }
                        .foregroundStyle(ST.onAm).frame(maxWidth: .infinity).frame(height: 50).background(ST.am, in: Capsule())
                }.buttonStyle(.plain).disabled(busy || pw.isEmpty)
                Text("كلمة السرّ تنحفظ بخزنة الآيفون المشفّرة، وما تطلع لأيّ مكان غير سيرفرك.").font(.cairo(11.5)).foregroundStyle(ST.tx3).multilineTextAlignment(.center)
            }
            .padding(28).frame(maxWidth: 420)
        }
    }
    private func go() {
        guard !pw.isEmpty else { return }
        busy = true; bad = false
        Task { let ok = await auth.login(pw); busy = false; bad = !ok }
    }
}

// MARK: - مشاريعي
struct Project: Identifiable { let id: String; let name: String; let sub: String; let icon: String; let tint: Color; let url: String; let ready: Bool }

struct ProjectsView: View {
    @EnvironmentObject var auth: Auth
    private let others: [Project] = [
        Project(id: "proclub", name: "Pro Club", sub: "مدير فرق FC", icon: "soccerball", tint: ST.green, url: "https://dawwirli.watch/proclub/", ready: false),
        Project(id: "brain", name: "عقل", sub: "العقل الشخصيّ", icon: "brain.head.profile", tint: ST.violet, url: "https://dawwirli.watch/brain", ready: false),
        Project(id: "trjm", name: "مترجم", sub: "ترجمة الأفلام", icon: "captions.bubble.fill", tint: ST.blue, url: "https://dawwirli.watch/trjm/", ready: false),
    ]
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("مشاريعي").font(.cairo(30, .heavy)).foregroundStyle(ST.tx).padding(.top, 6)
                Text(greeting()).font(.cairo(14)).foregroundStyle(ST.tx3).padding(.top, -12)

                // دورلي — البطاقة الكبيرة الحيّة
                NavigationLink { DawwirliHome() } label: { DawwirliCard() }.buttonStyle(.plain)

                Text("مشاريع ثانية").font(.cairo(17, .heavy)).foregroundStyle(ST.tx).padding(.top, 8)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(others) { p in
                        Link(destination: URL(string: p.url)!) {
                            VStack(alignment: .leading, spacing: 8) {
                                Image(systemName: p.icon).font(.system(size: 18, weight: .bold)).foregroundStyle(ST.tx)
                                    .frame(width: 40, height: 40).background(p.tint.gradient, in: RoundedRectangle(cornerRadius: 12))
                                Text(p.name).font(.cairo(15, .heavy)).foregroundStyle(ST.tx)
                                Text(p.sub).font(.cairo(11.5)).foregroundStyle(ST.tx3)
                                Pill(text: "لوحته قريبًا — يفتح الموقع", tint: ST.tx3)
                            }
                            .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                            .background(ST.s1, in: RoundedRectangle(cornerRadius: 18))
                            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color(white: 1, opacity: 0.07)))
                        }.buttonStyle(.plain)
                    }
                    VStack(spacing: 8) {
                        Image(systemName: "plus").font(.system(size: 20, weight: .bold)).foregroundStyle(ST.tx3)
                        Text("مشروعك الجاي").font(.cairo(13, .bold)).foregroundStyle(ST.tx3)
                    }
                    .frame(maxWidth: .infinity, minHeight: 150)
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(style: StrokeStyle(lineWidth: 1.2, dash: [6, 5])).foregroundStyle(ST.tx3.opacity(0.6)))
                }
            }
            .padding(16)
        }
        .background(STBackground())
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Menu { Button(role: .destructive) { auth.logout() } label: { Label("تسجيل خروج", systemImage: "rectangle.portrait.and.arrow.right") } }
                label: { Image(systemName: "person.crop.circle").font(.system(size: 20)).foregroundStyle(ST.tx2) }
            }
        }
    }
    private func greeting() -> String {
        let h = Calendar.current.component(.hour, from: Date())
        return h < 5 ? "سهران؟ هذا وضع مشاريعك 🌙" : h < 12 ? "صباح الخير ☀️" : h < 18 ? "هلا بيك 👋" : "مساء الخير 🌆"
    }
}

/// بطاقة دورلي على الشاشة الأولى: أرقام حيّة تتحدّث كلّ ١٥ث
struct DawwirliCard: View {
    @EnvironmentObject var auth: Auth
    @State private var s: J = [:]
    @State private var chatUnread = 0
    @State private var reqUnread = 0
    var body: some View {
        let u = jobj(s, "usage"), vod = jobj(s, "vod"), live = jobj(s, "live"), disk = jobj(s, "disk")
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 14).fill(ST.bg)
                    .frame(width: 48, height: 48)
                    .overlay(DWMark().frame(width: 32, height: 32))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(ST.am.opacity(0.3)))
                VStack(alignment: .leading, spacing: 2) {
                    Text("دورلي").font(.cairo(22, .bold)).foregroundStyle(ST.tx)
                    HStack(spacing: 6) {
                        Circle().fill(s.isEmpty ? ST.tx3 : ST.green).frame(width: 7, height: 7)
                        Text(s.isEmpty ? "جارِ الاتّصال…" : (s["maintenance"] as? Bool == true ? "وضع الصيانة" : "شغّال")).font(.cairo(12)).foregroundStyle(ST.tx2)
                    }
                }
                Spacer()
                if chatUnread + reqUnread > 0 {
                    Text("\(chatUnread + reqUnread)").font(.system(size: 13, weight: .heavy)).foregroundStyle(ST.tx)
                        .frame(minWidth: 26, minHeight: 26).background(ST.red, in: Capsule())
                }
                Image(systemName: "chevron.left").foregroundStyle(ST.tx3)
            }
            HStack(spacing: 10) {
                Tile(value: "\(jint(u, "onlineNow"))", label: "متّصل هسه", icon: "person.2.fill", tint: ST.green)
                Tile(value: "\(jint(vod, "activeStreams"))/\(jint(vod, "capTotal"))", label: "أفلام تشتغل", icon: "film.fill", tint: ST.am)
                Tile(value: "\(jint(live, "viewersNow"))", label: "بالمباشر", icon: "dot.radiowaves.left.and.right", tint: ST.red)
            }
            HStack(spacing: 14) {
                Label("\(jint(u, "active24h")) باليوم", systemImage: "chart.bar.fill")
                Label("قرص \(jint(disk, "usedPct"))٪", systemImage: "internaldrive.fill")
                if chatUnread > 0 { Label("\(chatUnread) رسالة", systemImage: "message.fill").foregroundStyle(ST.am) }
            }
            .font(.cairo(12)).foregroundStyle(ST.tx3)
        }
        .padding(16)
        .background(
            ZStack {
                ST.s1
                RadialGradient(colors: [ST.am2.opacity(0.22), Color.clear], center: .topTrailing, startRadius: 0, endRadius: 260)
            }.clipShape(RoundedRectangle(cornerRadius: 24)))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(ST.am.opacity(0.3)))
        .task {
            while !Task.isCancelled {
                do {
                    s = try await DW.get("/api/admin/stats")
                    chatUnread = jint(try await DW.get("/api/admin/chat"), "unread")
                    reqUnread = jarr(try await DW.get("/api/requests"), "items").filter { ($0["unreadAdmin"] as? Bool) == true }.count
                } catch DW.Err.auth { auth.logout(); return } catch {}
                try? await Task.sleep(nanoseconds: 15_000_000_000)
            }
        }
    }
}
