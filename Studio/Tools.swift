import SwiftUI

// MARK: - مكوّنات مشتركة للأدوات
struct Toast: View {
    let text: String; var bad = false
    var body: some View {
        if !text.isEmpty {
            Text(text).font(.cairo(13.5, .bold)).foregroundStyle(bad ? ST.red : ST.green).multilineTextAlignment(.center)
                .padding(10).frame(maxWidth: .infinity)
                .background((bad ? ST.red : ST.green).opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

struct ActBtn: View {
    let title: String; var tint: Color = ST.am; var icon: String = ""; var disabled = false; let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if !icon.isEmpty { Image(systemName: icon).font(.system(size: 12, weight: .bold)) }
                Text(title).font(.cairo(13, .bold)).lineLimit(1)
            }
            .foregroundStyle(tint).padding(.horizontal, 14).padding(.vertical, 7)
            .background(tint.opacity(0.14), in: Capsule()).overlay(Capsule().stroke(tint.opacity(0.45)))
        }.buttonStyle(.plain).disabled(disabled).opacity(disabled ? 0.45 : 1)
    }
}

struct Head: View {
    let icon: String; let title: String; var sub: String = ""; var tint: Color = ST.am
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.white)
                .frame(width: 36, height: 36).background(tint.gradient, in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.cairo(15, .bold)).foregroundStyle(Color.white)
                if !sub.isEmpty { Text(sub).font(.cairo(11.5)).foregroundStyle(ST.tx3) }
            }
            Spacer(minLength: 0)
        }
    }
}

struct KV: View {
    let k: String; let v: String; var tint: Color = Color.white
    var body: some View {
        HStack { Text(k).font(.cairo(13)).foregroundStyle(ST.tx3); Spacer(); Text(v).font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(tint).lineLimit(1) }
    }
}

struct Field: View {
    let hint: String; @Binding var text: String; var lines = 1
    var body: some View {
        TextField("", text: $text, prompt: Text(hint).foregroundColor(ST.tx3), axis: .vertical)
            .lineLimit(lines...max(lines, 4)).font(.cairo(14)).foregroundStyle(Color.white)
            .padding(12).background(ST.s2, in: RoundedRectangle(cornerRadius: 12))
    }
}

func jbool(_ o: J, _ k: String) -> Bool { (o[k] as? Bool) ?? ((o[k] as? NSNumber)?.boolValue ?? false) }
func jdbl(_ o: J, _ k: String) -> Double { (o[k] as? NSNumber)?.doubleValue ?? 0 }
func dayStr(_ ms: Double) -> String {
    guard ms > 0 else { return "—" }
    let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "d/M HH:mm"
    return f.string(from: Date(timeIntervalSince1970: ms / 1000))
}

/// صفحة أداة: خلفيّة + عنوان + تمرير
struct ToolPage<C: View>: View {
    let title: String
    @ViewBuilder let content: () -> C
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 12) { content() }.padding(14) }
            .background(STBackground())
            .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - الإعلانات (منبثقة + بنر الرئيسيّة) — نفس الشاشة لنوعين
enum AdKind { case pop, home
    var path: String { self == .pop ? "/api/admin/popads" : "/api/admin/hads" }
    var title: String { self == .pop ? "الإعلانات المنبثقة" : "بنر الرئيسيّة" }
}

struct AdsView: View {
    let kind: AdKind
    @State private var items: [J] = []
    @State private var now = 0.0
    @State private var toast = ""
    @State private var bad = false
    @State private var adding = false
    @State private var del: J? = nil
    @State private var loaded = false

    var body: some View {
        ToolPage(title: kind.title) {
            Toast(text: toast, bad: bad)
            Button { adding = true } label: {
                HStack(spacing: 8) { Image(systemName: "plus.circle.fill"); Text(kind == .pop ? "إعلان منبثق جديد" : "شريحة جديدة بالبنر").font(.cairo(15, .heavy)) }
                    .foregroundStyle(ST.onAm).frame(maxWidth: .infinity).frame(height: 48).background(ST.am, in: RoundedRectangle(cornerRadius: 14))
            }.buttonStyle(.plain)
            if !loaded { ProgressView().tint(ST.am).frame(maxWidth: .infinity).padding(.top, 30) }
            else if items.isEmpty { Text("ماكو إعلانات هسه").font(.cairo(14)).foregroundStyle(ST.tx3).frame(maxWidth: .infinity).padding(.top, 30) }
            ForEach(Array(items.enumerated()), id: \.offset) { i, it in row(i, it) }
        }
        .task { await load() }
        .sheet(isPresented: $adding) { AdEditor(kind: kind) { msg in toast = msg; bad = false; Task { await load() } } }
        .alert("تمسح «\(jstr(del ?? [:], "title"))»؟", isPresented: Binding(get: { del != nil }, set: { if !$0 { del = nil } })) {
            Button("امسحه", role: .destructive) {
                let id = jstr(del ?? [:], "id")
                Task { do { _ = try await DW.del(kind.path + "?id=" + DW.enc(id)); say("انمسح ✓") } catch { say("ما انمسح — تأكّد من النت", true) }; await load() }
            }
            Button("إلغاء", role: .cancel) {}
        } message: { Text("ينشال نهائيًّا وما يرجع.") }
    }

    private func say(_ t: String, _ b: Bool = false) { toast = t; bad = b }
    private func load() async {
        if let d = try? await DW.get(kind.path) { items = jarr(d, "items"); now = jdbl(d, "now") }
        loaded = true
    }
    private func state(_ it: J) -> (String, Color) {
        if !jbool(it, "active") { return ("مطفأ", ST.tx3) }
        if now > 0 && jdbl(it, "end") < now { return ("خلصت مدّته", ST.red) }
        if now > 0 && jdbl(it, "start") > now { return ("مجدول", ST.blue) }
        return ("ظاهر هسه", ST.green)
    }

    @ViewBuilder private func row(_ i: Int, _ it: J) -> some View {
        let st = state(it), stats = jobj(it, "stats"), tg = jobj(it, "target")
        let img = [jstr(it, "poster"), jstr(it, "image"), jstr(tg, "poster")].first { !$0.isEmpty } ?? ""
        Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    Poster(url: DW.img(img), w: 54)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) { Pill(text: st.0, tint: st.1); if !jstr(it, "badge").isEmpty { Pill(text: jstr(it, "badge"), tint: ST.am) } }
                        Text(jstr(it, "title").isEmpty ? "بلا عنوان" : jstr(it, "title")).font(.cairo(15, .heavy)).foregroundStyle(Color.white).lineLimit(2)
                        if !jstr(it, "text").isEmpty { Text(jstr(it, "text")).font(.cairo(12.5)).foregroundStyle(ST.tx2).lineLimit(3) }
                    }
                    Spacer(minLength: 0)
                }
                HStack(spacing: 14) {
                    Label("\(jint(stats, "view")) شافوه", systemImage: "eye.fill")
                    Label("\(jint(stats, "click")) ضغطوا", systemImage: "hand.tap.fill")
                    if kind == .pop { Label("\(jint(stats, "close")) سكّروه", systemImage: "xmark") }
                }.font(.cairo(11.5)).foregroundStyle(ST.tx3)
                Text("ينتهي: " + dayStr(jdbl(it, "end"))).font(.cairo(11.5)).foregroundStyle(ST.tx3)
                HStack(spacing: 8) {
                    ActBtn(title: jbool(it, "active") ? "طفّيه" : "شغّله", tint: jbool(it, "active") ? ST.tx2 : ST.green, icon: jbool(it, "active") ? "pause.fill" : "play.fill") { toggle(it) }
                    if kind == .home {
                        ActBtn(title: "فوق", tint: ST.blue, icon: "arrow.up", disabled: i == 0) { move(it, -1) }
                        ActBtn(title: "جوّه", tint: ST.blue, icon: "arrow.down", disabled: i == items.count - 1) { move(it, 1) }
                    }
                    Spacer()
                    ActBtn(title: "حذف", tint: ST.red, icon: "trash") { del = it }
                }
            }
        }
    }
    private func toggle(_ it: J) {
        var b = it; b["active"] = !jbool(it, "active")
        Task { do { _ = try await DW.post(kind.path, b); say(jbool(b, "active") ? "اشتغل ✓" : "انطفى") } catch { say("ما تنفّذ — تأكّد من النت", true) }; await load() }
    }
    private func move(_ it: J, _ dir: Int) {
        Task { _ = try? await DW.post(kind.path, ["move": jstr(it, "id"), "dir": dir]); await load() }
    }
}

struct AdEditor: View {
    let kind: AdKind
    let done: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var text = ""
    @State private var badge = ""
    @State private var btn = "شاهد الآن"
    @State private var days = 3
    @State private var gap = 1
    @State private var q = ""
    @State private var res: [J] = []
    @State private var target: J? = nil
    @State private var busy = false
    @State private var err = ""
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Toast(text: err, bad: true)
                    Card {
                        VStack(alignment: .leading, spacing: 10) {
                            Head(icon: "text.badge.plus", title: "النصّ", sub: "شنو يطلع للزائر", tint: ST.am)
                            Field(hint: "العنوان — مثلًا: نزلت الحلقة الجديدة", text: $title)
                            Field(hint: "سطر تحت العنوان (اختياريّ)", text: $text, lines: 2)
                            Field(hint: "شارة صغيرة — مثلًا: جديد (اختياريّ)", text: $badge)
                            Field(hint: "نصّ الزرّ", text: $btn)
                        }
                    }
                    Card {
                        VStack(alignment: .leading, spacing: 10) {
                            Head(icon: "film.fill", title: "العمل اللي يفتحه الزرّ", sub: target == nil ? "دوّر واختار فلم أو مسلسل (اختياريّ)" : "تمّ الاختيار", tint: ST.blue)
                            if let t = target {
                                HStack(spacing: 10) {
                                    Poster(url: DW.img(jstr(t, "poster")), w: 40)
                                    Text(DW.clean(jstr(t, "name"))).font(.cairo(14, .bold)).foregroundStyle(Color.white).lineLimit(2)
                                    Spacer()
                                    ActBtn(title: "غيّره", tint: ST.tx2) { target = nil }
                                }
                            } else {
                                HStack(spacing: 8) {
                                    Field(hint: "اسم الفلم أو المسلسل…", text: $q)
                                    ActBtn(title: "دوّر", tint: ST.blue, disabled: q.trimmingCharacters(in: .whitespaces).count < 2) { Task { await search() } }
                                }
                                ForEach(Array(res.enumerated()), id: \.offset) { _, x in
                                    Button { pick(x) } label: {
                                        HStack(spacing: 10) {
                                            Poster(url: DW.img(jstr(x, "icon").isEmpty ? jstr(x, "poster") : jstr(x, "icon")), w: 34)
                                            Text(DW.clean(jstr(x, "name"))).font(.cairo(13.5, .semibold)).foregroundStyle(Color.white).lineLimit(1)
                                            Spacer()
                                            Pill(text: jstr(x, "_kind") == "series" ? "مسلسل" : "فلم", tint: ST.tx3)
                                        }.contentShape(Rectangle())
                                    }.buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    Card {
                        VStack(alignment: .leading, spacing: 10) {
                            Head(icon: "calendar", title: "المدّة", tint: ST.violet)
                            Stepper(value: $days, in: 1...60) { Text("يبقى \(days) يوم").font(.cairo(14, .bold)).foregroundStyle(Color.white) }
                            if kind == .pop {
                                Stepper(value: $gap, in: 0...14) { Text(gap == 0 ? "يطلع بكلّ دخول" : "يطلع للشخص مرّة كلّ \(gap) يوم").font(.cairo(14, .bold)).foregroundStyle(Color.white) }
                            }
                        }
                    }
                    Button(action: save) {
                        HStack { if busy { ProgressView().tint(ST.onAm) }; Text("انشره").font(.cairo(16, .heavy)) }
                            .foregroundStyle(ST.onAm).frame(maxWidth: .infinity).frame(height: 50).background(ST.am, in: Capsule())
                    }.buttonStyle(.plain).disabled(busy || title.trimmingCharacters(in: .whitespaces).isEmpty)
                        .opacity(title.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
                }.padding(14)
            }
            .background(STBackground())
            .navigationTitle(kind == .pop ? "إعلان منبثق جديد" : "شريحة جديدة").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarLeading) { Button("إلغاء") { dismiss() }.font(.cairo(14, .bold)) } }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .preferredColorScheme(.dark)
    }
    private func search() async {
        let t = q.trimmingCharacters(in: .whitespaces)
        res = Array(jarr((try? await DW.get("/api/search?q=" + DW.enc(t))) ?? [:], "items").prefix(12))
    }
    private func pick(_ x: J) {
        let poster = jstr(x, "icon").isEmpty ? jstr(x, "poster") : jstr(x, "icon")
        target = ["id": jstr(x, "id"), "kind": jstr(x, "_kind") == "series" ? "series" : "movie", "name": jstr(x, "name"), "poster": poster, "ext": jstr(x, "ext").isEmpty ? "mp4" : jstr(x, "ext")]
        if title.isEmpty { title = DW.clean(jstr(x, "name")) }
        res = []
    }
    private func save() {
        busy = true; err = ""
        let nowMs = Date().timeIntervalSince1970 * 1000
        var b: J = ["title": title, "text": text, "badge": badge, "btn": btn.isEmpty ? "شاهد الآن" : btn,
                    "start": nowMs, "end": nowMs + Double(days) * 86_400_000, "active": true]
        if kind == .pop { b["gapDays"] = gap; b["dur"] = 10 } else { b["style"] = "custom" }
        if let t = target { b["target"] = t; b["poster"] = jstr(t, "poster") }
        Task {
            do { _ = try await DW.post(kind.path, b); done("انتشر ✓"); dismiss() }
            catch { err = "ما انتشر — تأكّد من النت وجرّب مرّة ثانية" }
            busy = false
        }
    }
}

// MARK: - ترشيح دورلي اليوم
struct DailyView: View {
    @State private var d: J = [:]
    @State private var toast = ""
    @State private var bad = false
    @State private var askGen = false
    @State private var busy = false
    private var today: String { jstr(d, "today") }
    private var items: [J] { jarr(jarr(d, "days").first { jstr($0, "date") == today } ?? [:], "items") }

    var body: some View {
        let cfg = jobj(d, "cfg")
        ToolPage(title: "ترشيح دورلي اليوم") {
            Toast(text: toast, bad: bad)
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    Head(icon: "target", title: "قائمة اليوم", sub: "\(items.count) عمل · المخزون \(jint(d, "poolSize"))", tint: ST.am)
                    HStack {
                        Pill(text: jbool(cfg, "auto") ? "التوليد التلقائيّ شغّال" : "التوليد التلقائيّ مطفأ", tint: jbool(cfg, "auto") ? ST.green : ST.tx3)
                        Spacer()
                        ActBtn(title: jbool(cfg, "auto") ? "طفّيه" : "شغّله", tint: ST.tx2) { setCfg(auto: !jbool(cfg, "auto"), n: max(1, jint(cfg, "n"))) }
                    }
                    HStack {
                        Text("عدد الأعمال باليوم: \(max(1, jint(cfg, "n")))").font(.cairo(13.5, .bold)).foregroundStyle(Color.white)
                        Spacer()
                        ActBtn(title: "−", tint: ST.tx2, disabled: jint(cfg, "n") <= 1) { setCfg(auto: jbool(cfg, "auto"), n: jint(cfg, "n") - 1) }
                        ActBtn(title: "+", tint: ST.tx2) { setCfg(auto: jbool(cfg, "auto"), n: jint(cfg, "n") + 1) }
                    }
                    ActBtn(title: busy ? "دا يولّد…" : "ولّد قائمة جديدة لليوم", tint: ST.am, icon: "arrow.triangle.2.circlepath", disabled: busy || today.isEmpty) { askGen = true }
                }
            }
            ForEach(Array(items.enumerated()), id: \.offset) { i, it in
                let st = jobj(it, "stats")
                HStack(spacing: 12) {
                    Poster(url: DW.img(jstr(it, "poster")), w: 48)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Pill(text: jstr(it, "kind") == "series" ? "مسلسل" : "فلم", tint: ST.blue)
                            if !jbool(it, "alive") { Pill(text: "ما يشتغل", tint: ST.red) }
                        }
                        Text(DW.clean(jstr(it, "name"))).font(.cairo(14, .bold)).foregroundStyle(Color.white).lineLimit(1)
                        Text(jstr(it, "why")).font(.cairo(11)).foregroundStyle(ST.tx3).lineLimit(2)
                        Text("شافوه \(jint(st, "seen")) · شغّلوه \(jint(st, "play")) · تجاهلوه \(jint(st, "hide"))").font(.cairo(11)).foregroundStyle(ST.tx3)
                    }
                    Spacer(minLength: 0)
                    Button { remove(i) } label: { Image(systemName: "trash").font(.system(size: 14)).foregroundStyle(ST.red).frame(width: 36, height: 36).background(ST.red.opacity(0.12), in: Circle()) }.buttonStyle(.plain)
                }
                .padding(10).background(ST.s1, in: RoundedRectangle(cornerRadius: 14))
            }
        }
        .task { await load() }
        .alert("تولّد قائمة جديدة لليوم؟", isPresented: $askGen) {
            Button("ولّد", role: .destructive) { gen() }
            Button("إلغاء", role: .cancel) {}
        } message: { Text("القائمة الحاليّة تنبدل بأعمال جديدة من صفوف الرئيسيّة.") }
    }
    private func say(_ t: String, _ b: Bool = false) { toast = t; bad = b }
    private func load() async { if let x = try? await DW.get("/api/admin/daily") { d = x } }
    private func setCfg(auto: Bool, n: Int) {
        Task { do { _ = try await DW.post("/api/admin/daily", ["cfg": ["auto": auto, "n": n] as J]); say("انحفظ ✓") } catch { say("ما انحفظ", true) }; await load() }
    }
    private func gen() {
        busy = true
        Task {
            do { let r = try await DW.post("/api/admin/daily", ["date": today, "gen": true, "force": true]); say("تولّدت \(jarr(r, "items").count) عمل ✓") } catch { say("ما تولّدت — جرّب مرّة ثانية", true) }
            busy = false; await load()
        }
    }
    private func remove(_ i: Int) {
        var list = items; guard list.indices.contains(i) else { return }
        list.remove(at: i)
        let slim: [J] = list.map { ["id": jstr($0, "id"), "kind": jstr($0, "kind"), "name": jstr($0, "name"), "poster": jstr($0, "poster"), "ext": jstr($0, "ext"),
                                    "why": jstr($0, "why"), "tag": jstr($0, "tag"), "year": jstr($0, "year"), "auto": jbool($0, "auto")] }
        Task { do { _ = try await DW.post("/api/admin/daily", ["date": today, "items": slim]); say("انشال ✓") } catch { say("ما انشال", true) }; await load() }
    }
}

// MARK: - التلفزيون · قنوات الرياضة
struct TVSportsView: View {
    @State private var d: J = [:]
    @State private var toast = ""
    @State private var bad = false
    @State private var checking = ""
    private var cfg: J { jobj(d, "cfg") }
    private var chans: [J] { jarr(cfg, "channels") }

    var body: some View {
        let status = jobj(d, "status")
        ToolPage(title: "قنوات الرياضة") {
            Toast(text: toast, bad: bad)
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    Head(icon: "sportscourt.fill", title: "قسم التلفزيون", sub: "\(chans.filter { jbool($0, "on") }.count) قناة شغّالة من \(chans.count) · الحدّ \(jint(cfg, "max"))", tint: ST.am)
                    HStack {
                        Pill(text: jbool(cfg, "enabled") ? "القسم ظاهر للزوّار" : "القسم مخفي", tint: jbool(cfg, "enabled") ? ST.green : ST.red)
                        Spacer()
                        ActBtn(title: jbool(cfg, "enabled") ? "اخفيه" : "أظهره", tint: jbool(cfg, "enabled") ? ST.red : ST.green) { save(["enabled": !jbool(cfg, "enabled")]) }
                    }
                }
            }
            ForEach(Array(chans.enumerated()), id: \.offset) { i, c in
                let st = jobj(status, jstr(c, "id")), bst = jobj(status, jstr(c, "backup"))
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        AsyncImage(url: DW.img(jstr(c, "logo"))) { ph in if case .success(let im) = ph { im.resizable().scaledToFit() } else { ST.s2 } }
                            .frame(width: 44, height: 44).clipShape(RoundedRectangle(cornerRadius: 10))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(DW.clean(jstr(c, "name"))).font(.cairo(14, .bold)).foregroundStyle(Color.white).lineLimit(1)
                            HStack(spacing: 6) {
                                Pill(text: jbool(st, "dead") ? "واقفة" : "شغّالة", tint: jbool(st, "dead") ? ST.red : ST.green)
                                if jint(st, "viewers") > 0 { Pill(text: "\(jint(st, "viewers")) يشوفون", tint: ST.am) }
                                if !jstr(c, "backup").isEmpty { Pill(text: jbool(bst, "dead") ? "الاحتياط واقف" : "إلها احتياط", tint: jbool(bst, "dead") ? ST.red : ST.blue) }
                            }
                        }
                        Spacer(minLength: 0)
                        Toggle("", isOn: Binding(get: { jbool(c, "on") }, set: { v in setOn(i, v) })).labelsHidden().tint(ST.am)
                    }
                    HStack(spacing: 8) {
                        ActBtn(title: checking == jstr(c, "id") ? "دا يفحص…" : "افحصها", tint: ST.blue, icon: "waveform.path.ecg", disabled: !checking.isEmpty) { check(c) }
                        ActBtn(title: "فوق", tint: ST.tx2, icon: "arrow.up", disabled: i == 0) { swap(i, i - 1) }
                        ActBtn(title: "جوّه", tint: ST.tx2, icon: "arrow.down", disabled: i == chans.count - 1) { swap(i, i + 1) }
                    }
                }
                .padding(12).background(ST.s1, in: RoundedRectangle(cornerRadius: 14))
            }
            NavigationLink { WebTool(path: "tvsports.html", title: "تعديل القنوات") } label: {
                Card { HStack { Head(icon: "plus.rectangle.on.rectangle", title: "إضافة أو تبديل قناة", sub: "يفتح صفحة القنوات الكاملة داخل التطبيق", tint: ST.violet); Image(systemName: "chevron.left").foregroundStyle(ST.tx3) } }
            }.buttonStyle(.plain)
        }
        .task { await load() }
    }
    private func say(_ t: String, _ b: Bool = false) { toast = t; bad = b }
    private func load() async { if let x = try? await DW.get("/api/admin/tvsports") { d = x } }
    private func save(_ body: J) {
        Task { do { _ = try await DW.post("/api/admin/tvsports/save", body); say("انحفظ ✓") } catch { say("ما انحفظ — تأكّد من النت", true) }; await load() }
    }
    private func setOn(_ i: Int, _ v: Bool) { var l = chans; guard l.indices.contains(i) else { return }; l[i]["on"] = v; save(["channels": l]) }
    private func swap(_ a: Int, _ b: Int) { var l = chans; guard l.indices.contains(a), l.indices.contains(b) else { return }; l.swapAt(a, b); save(["channels": l]) }
    private func check(_ c: J) {
        checking = jstr(c, "id")
        Task {
            let r = try? await DW.post("/api/admin/tvsports/check", ["id": jint(c, "id")])
            checking = ""
            let nm = DW.clean(jstr(c, "name"))
            if let r {
                if jbool(r, "ok") { say("«\(nm)» تشتغل ✓ (\(jint(r, "ms")) ملّي ثانية)") } else { say("«\(nm)» ما تشتغل هسه", true) }
            } else { say("ما گدرت أفحص — تأكّد من النت", true) }
        }
    }
}

// MARK: - المزوّدون
struct ProvidersView: View {
    @State private var items: [J] = []
    @State private var test: [J] = []
    @State private var testing = false
    @State private var tested = false
    var body: some View {
        ToolPage(title: "المزوّدون") {
            ForEach(Array(items.enumerated()), id: \.offset) { _, p in
                let ok = ["active", "ok"].contains(jstr(p, "status").lowercased()), act = jint(p, "active"), mx = max(1, jint(p, "max"))
                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Circle().fill(ok ? ST.green : ST.red).frame(width: 9, height: 9)
                            Text(jstr(p, "key")).font(.cairo(15, .heavy)).foregroundStyle(Color.white)
                            Spacer()
                            Pill(text: act >= mx ? "مشغول \(act)/\(mx)" : "فاضي \(act)/\(mx)", tint: act >= mx ? ST.red : ST.green)
                        }
                        KV(k: "الحالة", v: jstr(p, "status").isEmpty ? "ما يردّ" : jstr(p, "status"), tint: ok ? ST.green : ST.red)
                        KV(k: "السيرفر", v: jstr(p, "host"))
                        KV(k: "ينتهي الاشتراك", v: jstr(p, "exp").isEmpty ? "—" : jstr(p, "exp"))
                    }
                }
            }
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    Head(icon: "testtube.2", title: "اختبار المزوّدين", sub: "يجرّب كلّ مزوّد من السيرفر: القائمة + فيلم عيّنة (ياخذ ~15 ثانية)", tint: ST.am)
                    ActBtn(title: testing ? "دا يختبر…" : "شغّل الاختبار", tint: ST.am, icon: "play.fill", disabled: testing) { run() }
                    if tested && test.isEmpty { Text("الاختبار ما رجّع نتيجة").font(.cairo(12.5)).foregroundStyle(ST.red) }
                    ForEach(Array(test.enumerated()), id: \.offset) { _, t in
                        let http = jint(t, "serverHttp"), good = jbool(t, "apiOk") && (200..<400).contains(http)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack { Text(jstr(t, "key")).font(.cairo(14, .bold)).foregroundStyle(Color.white); Spacer(); Pill(text: good ? "يشتغل" : "بيه مشكلة", tint: good ? ST.green : ST.red) }
                            KV(k: "القائمة", v: jbool(t, "apiOk") ? "\(jint(t, "catalog")) فيلم" : "ما تفتح", tint: jbool(t, "apiOk") ? Color.white : ST.red)
                            KV(k: "تشغيل العيّنة", v: http == 0 ? "ما ردّ" : "HTTP \(http)", tint: (200..<400).contains(http) ? ST.green : ST.red)
                        }
                        .padding(10).background(ST.s2, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
        .task {
            while !Task.isCancelled {
                if let d = try? await DW.get("/api/admin/providers") { items = jarr(d, "items") }
                try? await Task.sleep(nanoseconds: 20_000_000_000)
            }
        }
    }
    private func run() {
        testing = true
        Task { test = jarr((try? await DW.get("/api/admin/provtest")) ?? [:], "items"); testing = false; tested = true }
    }
}

// MARK: - صحّة النظام
struct HealthView: View {
    @State private var s: J = [:]
    @State private var h: J = [:]
    @State private var t: J = [:]
    @State private var al: J = [:]
    @State private var toast = ""
    var body: some View {
        let content = jobj(h, "content"), wd = jobj(s, "watchdog"), disk = jobj(s, "disk"), cache = jobj(s, "cache"), sum = jobj(t, "summary"), jobs = jobj(s, "jobs")
        let up = jint(s, "uptimeMin")
        ToolPage(title: "صحّة النظام") {
            Toast(text: toast)
            Card {
                VStack(alignment: .leading, spacing: 8) {
                    Head(icon: "heart.text.square.fill", title: "الحالة العامّة", sub: jstr(h, "state") == "ok" ? "كلّشي تمام" : "أكو شي يحتاج نظرة", tint: jstr(h, "state") == "ok" ? ST.green : ST.red)
                    KV(k: "الرئيسيّة", v: jbool(content, "homeOk") ? "تطلع صفوفها" : "فاضية!", tint: jbool(content, "homeOk") ? ST.green : ST.red)
                    KV(k: "الأفلام بالمكتبة", v: "\(jint(content, "movies"))")
                    KV(k: "المسلسلات بالمكتبة", v: "\(jint(content, "series"))")
                    KV(k: "السيرفر شغّال من", v: up >= 1440 ? "\(up / 1440) يوم" : (up >= 60 ? "\(up / 60) ساعة" : "\(up) دقيقة"))
                }
            }
            Card {
                VStack(alignment: .leading, spacing: 8) {
                    Head(icon: "cpu.fill", title: "السيرفر", tint: ST.blue)
                    KV(k: "الحمل", v: String(format: "%.2f", jdbl(wd, "load")) + " / \(jint(wd, "cores")) نواة", tint: jdbl(wd, "load") > Double(max(1, jint(wd, "cores"))) ? ST.red : Color.white)
                    KV(k: "القرص", v: "\(jint(disk, "usedPct"))٪ مستعمل · \(jint(disk, "freeGB")) GB فاضي", tint: jint(disk, "usedPct") > 90 ? ST.red : Color.white)
                    KV(k: "كاش الأفلام", v: String(format: "%.0f / %.0f GB", jdbl(cache, "usedGB"), jdbl(cache, "capGB")))
                    KV(k: "أعمال جاهزة / تتحوّل", v: "\(jint(cache, "readyCount")) / \(jint(cache, "convertingCount"))")
                    KV(k: "تحويلات شغّالة", v: "\(jint(jobs, "convertJobsActive"))")
                    KV(k: "مصادر ميّتة مسجّلة", v: "\(jint(wd, "badSources"))")
                }
            }
            Card {
                VStack(alignment: .leading, spacing: 8) {
                    Head(icon: "speedometer", title: "سرعة التشغيل", sub: "آخر مهامّ التحويل", tint: ST.am)
                    KV(k: "بداية الفيلم (الوسط)", v: String(format: "%.1f ثانية", jdbl(jobj(sum, "viewerStartupMs"), "p50") / 1000))
                    KV(k: "ردّ المزوّد (الوسط)", v: String(format: "%.1f ثانية", jdbl(jobj(sum, "upstreamTtfbMs"), "p50") / 1000))
                    KV(k: "من الكاش", v: String(format: "%.0f٪", jdbl(sum, "hitRate")))
                    KV(k: "مهامّ فشلت", v: "\(jint(sum, "fail")) من \(jint(sum, "jobs"))", tint: jint(sum, "fail") > 0 ? ST.red : ST.green)
                }
            }
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    Head(icon: "bell.and.waves.left.and.right.fill", title: "تنبيه الانقطاع", sub: jbool(al, "webhook") ? "يبعث على ديسكورد" : "ديسكورد مو مربوط", tint: ST.red)
                    HStack {
                        Pill(text: jbool(al, "auto") ? "التنبيه التلقائيّ شغّال" : "التنبيه التلقائيّ مطفأ", tint: jbool(al, "auto") ? ST.green : ST.tx3)
                        Spacer()
                        ActBtn(title: jbool(al, "auto") ? "طفّيه" : "شغّله", tint: ST.tx2) { fire("toggle", "انحفظ ✓") }
                        ActBtn(title: "اختبار", tint: ST.blue) { fire("test", "انبعث تنبيه اختبار ✓") }
                    }
                    ForEach(Array(jarr(al, "log").prefix(8).enumerated()), id: \.offset) { _, l in
                        HStack(alignment: .top, spacing: 8) {
                            Circle().fill(jstr(l, "kind") == "down" ? ST.red : ST.green).frame(width: 7, height: 7).padding(.top, 6)
                            Text(jstr(l, "msg")).font(.cairo(12.5)).foregroundStyle(ST.tx2)
                            Spacer()
                            Text(ago(jdbl(l, "t"))).font(.cairo(11)).foregroundStyle(ST.tx3)
                        }
                    }
                }
            }
        }
        .task {
            while !Task.isCancelled {
                async let a = DW.get("/api/admin/stats")
                async let b = DW.get("/api/admin/health")
                async let c = DW.get("/api/admin/timings")
                async let e = DW.get("/api/admin/alert")
                if let x = try? await a { s = x }
                if let y = try? await b { h = y }
                if let z = try? await c { t = z }
                if let w = try? await e { al = w }
                try? await Task.sleep(nanoseconds: 15_000_000_000)
            }
        }
    }
    private func fire(_ act: String, _ ok: String) {
        Task {
            let r = try? await DW.post("/api/admin/alert", ["action": act])
            if let r { al["auto"] = jbool(r, "auto"); toast = ok } else { toast = "ما تنفّذ" }
        }
    }
}

// MARK: - صيانة وتشغيل
struct OpsView: View {
    @State private var req: J = [:]
    @State private var hero: J = [:]
    @State private var sub: J = [:]
    @State private var maint = false
    @State private var toast = ""
    @State private var bad = false
    @State private var busy = ""
    @State private var ask: Op? = nil
    enum Op: String, Identifiable { case home, sections, index, maintOn, maintOff; var id: String { rawValue } }

    var body: some View {
        ToolPage(title: "صيانة وتشغيل") {
            Toast(text: toast, bad: bad)
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    Head(icon: "wrench.and.screwdriver.fill", title: "وضع الصيانة", sub: "يوقف الموقع للزوّار ويعرض صفحة صيانة", tint: ST.red)
                    HStack {
                        Pill(text: maint ? "مفعّل — الموقع واقف" : "مطفأ — الموقع شغّال", tint: maint ? ST.red : ST.green)
                        Spacer()
                        ActBtn(title: maint ? "رجّع الموقع" : "فعّل الصيانة", tint: maint ? ST.green : ST.red) { ask = maint ? .maintOff : .maintOn }
                    }
                }
            }
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    Head(icon: "arrow.triangle.2.circlepath", title: "إعادة بناء", sub: "إذا شي ما محدّث بالموقع", tint: ST.am)
                    opRow("الرئيسيّة", "تحدّث صفوف الصفحة الرئيسيّة", .home)
                    opRow("الأقسام", "أفلام، مسلسلات، وباقي الأقسام", .sections)
                    opRow("فهرس المكتبة", "يسحب قائمة الأعمال من المزوّدين من جديد (دقيقة أو أكثر)", .index)
                }
            }
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    Head(icon: "tray.and.arrow.down.fill", title: "الطلبات التلقائيّة", sub: "يدوّر على طلبات الزوّار بالمكتبة ويوفّرها لحاله", tint: ST.blue)
                    KV(k: "عالجها", v: "\(jint(req, "handled"))")
                    KV(k: "لكاها وأضافها", v: "\(jint(req, "added"))", tint: ST.green)
                    KV(k: "ما موجودة عند المزوّد", v: "\(jint(req, "missing"))")
                    KV(k: "بالانتظار", v: "\(jint(req, "pending"))")
                    HStack {
                        Pill(text: jbool(req, "on") ? "شغّال" : "مطفأ", tint: jbool(req, "on") ? ST.green : ST.tx3)
                        Spacer()
                        ActBtn(title: "شغّله هسه", tint: ST.blue, icon: "play.fill") { call("/api/admin/reqauto?run=1", "اشتغل ✓") }
                        ActBtn(title: jbool(req, "on") ? "طفّيه" : "شغّله", tint: ST.tx2) { call("/api/admin/reqauto?on=" + (jbool(req, "on") ? "0" : "1"), "انحفظ ✓") }
                    }
                }
            }
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    Head(icon: "photo.on.rectangle.angled", title: "بانر الهيرو التلقائيّ", sub: "يبدّل أعمال البانر الكبير بالرئيسيّة كلّ يوم", tint: ST.violet)
                    HStack {
                        Pill(text: jbool(hero, "on") ? "شغّال" : "مطفأ", tint: jbool(hero, "on") ? ST.green : ST.tx3)
                        if jdbl(hero, "lastAt") > 0 { Text("آخر تبديل " + ago(jdbl(hero, "lastAt"))).font(.cairo(11.5)).foregroundStyle(ST.tx3) }
                        Spacer()
                        ActBtn(title: jbool(hero, "on") ? "طفّيه" : "شغّله", tint: ST.tx2) { call("/api/admin/heroauto?on=" + (jbool(hero, "on") ? "0" : "1"), "انحفظ ✓") }
                    }
                }
            }
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    Head(icon: "captions.bubble.fill", title: "ماسح الترجمة", sub: "يفحص أيّ فلم أجنبيّ إله ترجمة عربيّة ويخفي اللي ما إله", tint: ST.green)
                    KV(k: "انفحص", v: "\(jint(sub, "scannedTotal"))")
                    KV(k: "إله ترجمة", v: "\(jint(sub, "has"))", tint: ST.green)
                    KV(k: "بلا ترجمة", v: "\(jint(sub, "none"))")
                    KV(k: "باقي", v: "\(jint(sub, "remaining"))")
                    HStack {
                        Pill(text: jbool(sub, "running") ? "شغّال" : "موقّف", tint: jbool(sub, "running") ? ST.green : ST.tx3)
                        Spacer()
                        ActBtn(title: jbool(sub, "running") ? "وقّفه" : "كمّله", tint: ST.tx2) { call("/api/admin/subscan?action=" + (jbool(sub, "running") ? "pause" : "resume"), "انحفظ ✓") }
                    }
                }
            }
        }
        .task { await load() }
        .alert(item: $ask) { op in
            switch op {
            case .maintOn: return Alert(title: Text("توقف الموقع للزوّار؟"), message: Text("كلّ الزوّار راح يشوفون صفحة صيانة لحدّ ما ترجّعه."),
                                        primaryButton: .destructive(Text("فعّل الصيانة")) { setMaint(true) }, secondaryButton: .cancel(Text("إلغاء")))
            case .maintOff: return Alert(title: Text("ترجّع الموقع للزوّار؟"), primaryButton: .default(Text("رجّعه")) { setMaint(false) }, secondaryButton: .cancel(Text("إلغاء")))
            default: return Alert(title: Text("تعيد البناء؟"), message: Text(op == .index ? "ياخذ دقيقة أو أكثر، والموقع يبقى شغّال." : "ياخذ ثواني، والموقع يبقى شغّال."),
                                  primaryButton: .default(Text("ابدي")) { rebuild(op) }, secondaryButton: .cancel(Text("إلغاء")))
            }
        }
    }
    private func opRow(_ t: String, _ subt: String, _ op: Op) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) { Text(t).font(.cairo(14, .bold)).foregroundStyle(Color.white); Text(subt).font(.cairo(11.5)).foregroundStyle(ST.tx3) }
            Spacer()
            ActBtn(title: busy == op.rawValue ? "دا يشتغل…" : "أعد البناء", tint: ST.am, disabled: !busy.isEmpty) { ask = op }
        }
    }
    private func say(_ t: String, _ b: Bool = false) { toast = t; bad = b }
    private func load() async {
        if let x = try? await DW.get("/api/admin/reqauto") { req = x }
        if let x = try? await DW.get("/api/admin/heroauto") { hero = x }
        if let x = try? await DW.get("/api/admin/subscan") { sub = x }
        if let x = try? await DW.get("/api/admin/maint") { maint = jbool(x, "on") }
    }
    private func call(_ path: String, _ ok: String) {
        Task { do { _ = try await DW.get(path); say(ok) } catch { say("ما تنفّذ — تأكّد من النت", true) }; await load() }
    }
    private func setMaint(_ on: Bool) {
        Task { do { _ = try await DW.post("/api/admin/maint", ["on": on]); say(on ? "تفعّلت الصيانة" : "رجع الموقع ✓") } catch { say("ما تنفّذ", true) }; await load() }
    }
    private func rebuild(_ op: Op) {
        busy = op.rawValue
        Task {
            do { _ = try await DW.get("/api/admin/rebuild?what=" + op.rawValue); say("انبنى من جديد ✓") } catch { say("ما كمل — يمكن ياخذ وقت أطول، شوف بعد دقيقة", true) }
            busy = ""
        }
    }
}

// MARK: - جديد دورلي
struct NewestView: View {
    @State private var d: J = [:]
    @State private var series = false
    var body: some View {
        let list = jarr(d, series ? "series" : "movies")
        ToolPage(title: "جديد دورلي") {
            Picker("", selection: $series) {
                Text("أفلام (\(jint(d, "totalMovies")))").tag(false); Text("مسلسلات (\(jint(d, "totalSeries")))").tag(true)
            }.pickerStyle(.segmented)
            if d.isEmpty { ProgressView().tint(ST.am).frame(maxWidth: .infinity).padding(.top, 30) }
            ForEach(Array(list.enumerated()), id: \.offset) { _, x in
                HStack(spacing: 12) {
                    Poster(url: DW.img(jstr(x, "poster")), w: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(DW.clean(jstr(x, "name"))).font(.cairo(14, .bold)).foregroundStyle(Color.white).lineLimit(1)
                        Text(jstr(x, "cat")).font(.cairo(11)).foregroundStyle(ST.tx3).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    Text(ago(jdbl(x, "added") * 1000)).font(.cairo(11)).foregroundStyle(ST.tx3)
                }
                .padding(10).background(ST.s1, in: RoundedRectangle(cornerRadius: 14))
            }
        }
        .task { if let x = try? await DW.get("/api/admin/newest") { d = x } }
    }
}

// MARK: - ردود الفعل
struct ReactsView: View {
    @State private var d: J = [:]
    @State private var toast = ""
    @State private var block: J? = nil
    var body: some View {
        let items = jarr(d, "items")
        ToolPage(title: "ردود الفعل") {
            Toast(text: toast)
            HStack(spacing: 10) {
                Tile(value: "\(jint(d, "total"))", label: "ردّ فعل", icon: "face.smiling.fill", tint: ST.am)
                Tile(value: "\(jint(d, "titles"))", label: "عمل", icon: "film.fill", tint: ST.blue)
                Tile(value: "\((d["blocked"] as? [Any])?.count ?? 0)", label: "جهاز محظور", icon: "hand.raised.fill", tint: ST.red)
            }
            ForEach(Array(items.prefix(150).enumerated()), id: \.offset) { _, r in
                HStack(spacing: 10) {
                    Text(jstr(r, "e")).font(.system(size: 24))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(jstr(r, "name").isEmpty ? jstr(r, "key") : jstr(r, "name")).font(.cairo(13.5, .bold)).foregroundStyle(Color.white).lineLimit(1)
                        if !jstr(r, "x").isEmpty { Text(jstr(r, "x")).font(.cairo(12.5)).foregroundStyle(ST.tx2).lineLimit(3) }
                        Text(ago(jdbl(r, "at"))).font(.cairo(11)).foregroundStyle(ST.tx3)
                    }
                    Spacer(minLength: 0)
                    Menu {
                        Button(role: .destructive) { act("/api/admin/react/delete", ["key": jstr(r, "key"), "at": jdbl(r, "at"), "d": jstr(r, "d")], "انمسح ✓") } label: { Label("امسح هذا", systemImage: "trash") }
                        Button(role: .destructive) { block = r } label: { Label("احظر هذا الجهاز", systemImage: "hand.raised.fill") }
                    } label: { Image(systemName: "ellipsis.circle").font(.system(size: 18)).foregroundStyle(ST.tx3).frame(width: 36, height: 36) }
                }
                .padding(10).background(ST.s1, in: RoundedRectangle(cornerRadius: 14))
            }
        }
        .task { await load() }
        .alert("تحظر هذا الجهاز؟", isPresented: Binding(get: { block != nil }, set: { if !$0 { block = nil } })) {
            Button("احظره", role: .destructive) { act("/api/admin/react/block", ["d": jstr(block ?? [:], "d")], "انحظر وانمسحت ردوده ✓") }
            Button("إلغاء", role: .cancel) {}
        } message: { Text("كلّ ردوده تنمسح وما يگدر يكتب ردود بعد.") }
    }
    private func load() async { if let x = try? await DW.get("/api/admin/reacts") { d = x } }
    private func act(_ path: String, _ body: J, _ ok: String) {
        Task {
            let r = try? await DW.post(path, body)
            toast = r != nil ? ok : "ما تنفّذ"
            await load()
        }
    }
}

// MARK: - المتابعة: منو ينتظر ردّ، شنو يدوّرون وما يلگون، وشنو يتعطّل
struct SupWatchView: View {
    @State private var d: J = [:]
    @State private var tab = 0
    var body: some View {
        let waiting = jarr(d, "waiting"), misses = jarr(d, "misses"), fails = jarr(d, "fails")
        ToolPage(title: "المتابعة") {
            Picker("", selection: $tab) {
                Text("ينتظرون (\(waiting.count))").tag(0); Text("ما لگوه (\(misses.count))").tag(1); Text("أعطال (\(fails.count))").tag(2)
            }.pickerStyle(.segmented)
            if jdbl(d, "at") > 0 { Text("آخر فحص " + ago(jdbl(d, "at"))).font(.cairo(11.5)).foregroundStyle(ST.tx3) }
            if tab == 0 {
                ForEach(Array(waiting.enumerated()), id: \.offset) { _, w in
                    NavigationLink { ChatThread(dev: jstr(w, "dev"), name: jstr(w, "name")) } label: {
                        HStack(spacing: 12) {
                            Text(String(jstr(w, "name").first ?? "؟")).font(.system(size: 16, weight: .heavy)).foregroundStyle(ST.onAm).frame(width: 40, height: 40).background(ST.am.gradient, in: Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                HStack { Text(jstr(w, "name").isEmpty ? "زائر" : jstr(w, "name")).font(.cairo(14, .bold)).foregroundStyle(Color.white); Spacer(); Text("من " + jstr(w, "ago")).font(.cairo(11)).foregroundStyle(ST.tx3) }
                                Text(jstr(w, "text")).font(.cairo(12.5)).foregroundStyle(ST.tx2).lineLimit(2).multilineTextAlignment(.leading)
                            }
                            Image(systemName: "chevron.left").font(.system(size: 12, weight: .bold)).foregroundStyle(ST.tx3)
                        }
                        .padding(12).background(ST.s1, in: RoundedRectangle(cornerRadius: 14))
                    }.buttonStyle(.plain)
                }
            } else if tab == 1 {
                ForEach(Array(misses.enumerated()), id: \.offset) { _, m in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(jstr(m, "q")).font(.cairo(14, .bold)).foregroundStyle(Color.white).lineLimit(2)
                            Text("\(jint(m, "n")) مرّة · \(jint(m, "devs")) جهاز · من " + jstr(m, "ago")).font(.cairo(11.5)).foregroundStyle(ST.tx3)
                        }
                        Spacer()
                        Pill(text: jstr(m, "intent") == "missing" ? "ما موجود" : "ما انفهم", tint: jstr(m, "intent") == "missing" ? ST.red : ST.tx3)
                    }
                    .padding(12).background(ST.s1, in: RoundedRectangle(cornerRadius: 14))
                }
            } else {
                ForEach(Array(fails.enumerated()), id: \.offset) { _, f in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack { Text(DW.clean(jstr(f, "title"))).font(.cairo(14, .bold)).foregroundStyle(Color.white).lineLimit(1); Spacer(); Pill(text: "\(jint(f, "n")) بلاغ", tint: ST.red) }
                        if !jstr(f, "hint").isEmpty { Text(jstr(f, "hint")).font(.cairo(12.5)).foregroundStyle(ST.am) }
                        Text((jobj(f, "os").map { "\($0.key) \(($0.value as? NSNumber)?.intValue ?? 0)" }).sorted().joined(separator: " · ")).font(.cairo(11.5)).foregroundStyle(ST.tx3)
                    }
                    .padding(12).background(ST.s1, in: RoundedRectangle(cornerRadius: 14))
                }
            }
        }
        .task { if let x = try? await DW.get("/api/admin/supwatch") { d = x } }
    }
}
