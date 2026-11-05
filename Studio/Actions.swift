import SwiftUI

/// أوامر سريعة — كلّ أمر يغيّر شي بالموقع يطلب تأكيد قبل لا يتنفّذ
struct ActionsView: View {
    @State private var ann: J = [:]
    @State private var annText = ""
    @State private var maint = false
    @State private var subs = 0
    @State private var pushTitle = "دورلي"
    @State private var pushBody = ""
    @State private var ask: Pending? = nil
    @State private var toast = ""

    enum Pending: Identifiable {
        case maint(Bool), push, announce(Bool)
        var id: String { switch self { case .maint(let b): return "m\(b)"; case .push: return "p"; case .announce(let b): return "a\(b)" } }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if !toast.isEmpty {
                    Text(toast).font(.cairo(13.5, .bold)).foregroundStyle(ST.green).padding(10).frame(maxWidth: .infinity)
                        .background(ST.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                }

                // إعلان الموقع
                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        head("megaphone.fill", "إعلان الموقع", "شريط يطلع لكلّ الزوّار فوق الصفحة", ST.am)
                        HStack { Text("الحالة:").font(.cairo(12.5)).foregroundStyle(ST.tx3); Pill(text: (ann["active"] as? Bool) == true ? "ظاهر هسه" : "مخفي", tint: (ann["active"] as? Bool) == true ? ST.green : ST.tx3) }
                        TextField("", text: $annText, prompt: Text("مثلًا: مباراة الكلاسيكو الليلة 10 مساءً على قسم المباشر ⚽").foregroundColor(ST.tx3), axis: .vertical)
                            .lineLimit(2...4).font(.cairo(14)).foregroundStyle(Color.white).padding(12).background(ST.s2, in: RoundedRectangle(cornerRadius: 12))
                        HStack(spacing: 8) {
                            btn("انشر الإعلان", ST.am, disabled: annText.trimmingCharacters(in: .whitespaces).isEmpty) { ask = .announce(true) }
                            if (ann["active"] as? Bool) == true { btn("أخفيه", ST.tx2) { ask = .announce(false) } }
                        }
                    }
                }

                // إشعار للمشتركين
                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        head("bell.badge.fill", "إشعار لكلّ المشتركين", "يوصل لـ \(subs) جهاز مفعّل الإشعارات بالموقع", ST.blue)
                        TextField("", text: $pushTitle, prompt: Text("العنوان").foregroundColor(ST.tx3))
                            .font(.cairo(14, .bold)).foregroundStyle(Color.white).padding(12).background(ST.s2, in: RoundedRectangle(cornerRadius: 12))
                        TextField("", text: $pushBody, prompt: Text("نصّ الإشعار — مثلًا: نزلت الحلقة الجديدة من …").foregroundColor(ST.tx3), axis: .vertical)
                            .lineLimit(2...4).font(.cairo(14)).foregroundStyle(Color.white).padding(12).background(ST.s2, in: RoundedRectangle(cornerRadius: 12))
                        btn("ابعث الإشعار", ST.blue, disabled: pushBody.trimmingCharacters(in: .whitespaces).isEmpty) { ask = .push }
                    }
                }

                // إخفاء عمل
                NavigationLink { HideView() } label: {
                    Card {
                        HStack {
                            head("eye.slash.fill", "إخفاء عمل من الموقع", "دوّر على فلم أو مسلسل واخفيه، أو رجّع المخفي", Color(red: 1, green: 0.42, blue: 0.52))
                            Spacer(); Image(systemName: "chevron.left").foregroundStyle(ST.tx3)
                        }
                    }
                }.buttonStyle(.plain)

                // وضع الصيانة
                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        head("wrench.and.screwdriver.fill", "وضع الصيانة", "يوقف الموقع للزوّار مؤقّتًا ويعرض صفحة صيانة", ST.red)
                        HStack {
                            Pill(text: maint ? "مفعّل — الموقع واقف للزوّار" : "مطفأ — الموقع شغّال", tint: maint ? ST.red : ST.green)
                            Spacer()
                            btn(maint ? "رجّع الموقع" : "فعّل الصيانة", maint ? ST.green : ST.red) { ask = .maint(!maint) }
                        }
                    }
                }
            }
            .padding(14)
        }
        .background(STBackground())
        .navigationTitle("أوامر سريعة").navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .alert(item: $ask) { p in
            switch p {
            case .maint(let on):
                return Alert(title: Text(on ? "توقف الموقع للزوّار؟" : "ترجّع الموقع للزوّار؟"),
                             message: Text(on ? "كلّ الزوّار راح يشوفون صفحة صيانة لحدّ ما ترجّعه." : "الموقع يرجع يشتغل للكلّ."),
                             primaryButton: .destructive(Text(on ? "فعّل الصيانة" : "رجّعه")) { run { _ = try await DW.post("/api/admin/maint", ["on": on]); return on ? "تفعّلت الصيانة" : "رجع الموقع ✓" } },
                             secondaryButton: .cancel(Text("إلغاء")))
            case .push:
                return Alert(title: Text("تبعث الإشعار لـ \(subs) جهاز؟"), message: Text("«\(pushTitle)»\n\(pushBody)"),
                             primaryButton: .default(Text("ابعث")) {
                                 let t = pushTitle, b = pushBody
                                 run { let r = try await DW.post("/api/admin/push", ["title": t, "body": b, "url": "/"]); pushBody = ""; return "انبعث لـ \(jint(r, "sent")) جهاز ✓" }
                             },
                             secondaryButton: .cancel(Text("إلغاء")))
            case .announce(let on):
                return Alert(title: Text(on ? "تنشر الإعلان لكلّ الزوّار؟" : "تخفي الإعلان؟"), message: on ? Text(annText) : nil,
                             primaryButton: .default(Text(on ? "انشر" : "أخفيه")) {
                                 let t = on ? annText : jstr(ann, "text")
                                 run { _ = try await DW.post("/api/admin/announce", ["text": t, "active": on]); return on ? "الإعلان ظاهر هسه ✓" : "انخفى الإعلان" }
                             },
                             secondaryButton: .cancel(Text("إلغاء")))
            }
        }
    }

    private func load() async {
        if let a = try? await DW.get("/api/admin/announce") { ann = a; if annText.isEmpty { annText = jstr(a, "text") } }
        if let m = try? await DW.get("/api/admin/maint") { maint = (m["on"] as? Bool) ?? false }
        if let p = try? await DW.get("/api/admin/push") { subs = jint(p, "subs") }
    }
    private func run(_ f: @escaping () async throws -> String) {
        Task {
            do { toast = try await f() } catch { toast = "ما تنفّذ — تأكّد من النت" }
            await load()
        }
    }
    private func head(_ ic: String, _ t: String, _ sub: String, _ c: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: ic).font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.white)
                .frame(width: 36, height: 36).background(c.gradient, in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 1) {
                Text(t).font(.cairo(15, .bold)).foregroundStyle(Color.white)
                Text(sub).font(.cairo(11.5)).foregroundStyle(ST.tx3)
            }
        }
    }
    private func btn(_ t: String, _ c: Color, disabled: Bool = false, _ a: @escaping () -> Void) -> some View {
        Button(action: a) {
            Text(t).font(.cairo(13.5, .bold)).foregroundStyle(c).padding(.horizontal, 16).padding(.vertical, 8)
                .background(c.opacity(0.14), in: Capsule()).overlay(Capsule().stroke(c.opacity(0.5)))
        }.buttonStyle(.plain).disabled(disabled).opacity(disabled ? 0.45 : 1)
    }
}

/// إخفاء/إرجاع عمل — بحث بالمكتبة ⇒ إخفاء بتأكيد؛ قائمة المخفي ⇒ إرجاع
struct HideView: View {
    @State private var q = ""
    @State private var res: [J] = []
    @State private var hidden: [J] = []
    @State private var ask: J? = nil
    @State private var toast = ""
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                TextField("", text: $q, prompt: Text("اسم الفلم أو المسلسل…").foregroundColor(ST.tx3))
                    .font(.cairo(15)).foregroundStyle(Color.white).padding(12).background(ST.s2, in: RoundedRectangle(cornerRadius: 12))
                    .submitLabel(.search).onSubmit { Task { await search() } }
                if !toast.isEmpty { Text(toast).font(.cairo(13, .bold)).foregroundStyle(ST.green) }
                ForEach(Array(res.enumerated()), id: \.offset) { _, x in
                    HStack(spacing: 12) {
                        Poster(url: DW.img(jstr(x, "icon").isEmpty ? jstr(x, "poster") : jstr(x, "icon")))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(DW.clean(jstr(x, "name"))).font(.cairo(14, .bold)).foregroundStyle(Color.white).lineLimit(2)
                            Text(jstr(x, "cat")).font(.cairo(11)).foregroundStyle(ST.tx3).lineLimit(1)
                        }
                        Spacer()
                        Button { ask = x } label: {
                            Text("إخفاء").font(.cairo(13, .bold)).foregroundStyle(ST.red).padding(.horizontal, 14).padding(.vertical, 7).background(ST.red.opacity(0.13), in: Capsule())
                        }.buttonStyle(.plain)
                    }.padding(10).background(ST.s1, in: RoundedRectangle(cornerRadius: 14))
                }
                if !hidden.isEmpty {
                    Text("المخفيّة (\(hidden.count))").font(.cairo(16, .heavy)).foregroundStyle(Color.white).padding(.top, 10)
                    ForEach(Array(hidden.enumerated()), id: \.offset) { _, x in
                        HStack {
                            Text(DW.clean(jstr(x, "name").isEmpty ? jstr(x, "id") : jstr(x, "name"))).font(.cairo(14)).foregroundStyle(ST.tx2).lineLimit(1)
                            Spacer()
                            Button {
                                Task { _ = try? await DW.get("/api/admin/unblock?id=" + DW.enc(jstr(x, "id"))); toast = "رجع يطلع بالموقع ✓"; await loadHidden() }
                            } label: { Text("رجّعه").font(.cairo(13, .bold)).foregroundStyle(ST.green) }.buttonStyle(.plain)
                        }.padding(12).background(ST.s1, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }.padding(14)
        }
        .background(STBackground())
        .navigationTitle("إخفاء عمل").navigationBarTitleDisplayMode(.inline)
        .task { await loadHidden() }
        .alert("تخفي «\(DW.clean(jstr(ask ?? [:], "name")))» من الموقع؟", isPresented: Binding(get: { ask != nil }, set: { if !$0 { ask = nil } })) {
            Button("أخفيه", role: .destructive) {
                let x = ask ?? [:]
                Task {
                    _ = try? await DW.get("/api/admin/block?id=" + DW.enc(jstr(x, "id")) + "&name=" + DW.enc(jstr(x, "name")))
                    toast = "انخفى ✓"; res.removeAll { jstr($0, "id") == jstr(x, "id") }; await loadHidden()
                }
            }
            Button("إلغاء", role: .cancel) {}
        } message: { Text("ما يطلع بالبحث ولا بالأقسام، وتكدر ترجّعه من نفس الصفحة.") }
    }
    private func search() async {
        let t = q.trimmingCharacters(in: .whitespaces); guard t.count >= 2 else { return }
        res = Array(jarr((try? await DW.get("/api/search?q=" + DW.enc(t))) ?? [:], "items").prefix(30))
    }
    private func loadHidden() async { hidden = jarr((try? await DW.get("/api/admin/blocked")) ?? [:], "items") }
}
