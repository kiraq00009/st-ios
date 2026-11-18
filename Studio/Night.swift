import SwiftUI

// MARK: - 🌙 سهرة دورلي (نفس night.html): المرشّحين + فحص ملفّاتهم، الفائز، المواعيد، الدردشة الحيّة، التنزيل، التقييم
struct NightAdminView: View {
    @State private var s: J = [:]
    @State private var toast = ""
    @State private var bad = false
    @State private var busy = false
    @State private var swapFor: Int? = nil
    @State private var vote = ""
    @State private var start = ""
    @State private var on = true
    @State private var editing = false
    @State private var say = ""

    private let PH = ["vote": "التصويت مفتوح", "soon": "التصويت سدّ — ينتظر العرض", "live": "🔴 يُعرض هسّه", "off": "السهرة مطفيّة", "wait": "ينتظر بناء الرئيسيّة"]

    var body: some View {
        let cands = jarr(s, "cands"), chk = (s["chk"] as? [Any]) ?? [], tot = jint(s, "total"), win = s["win"] as? Int, ph = jstr(s, "phase")
        ToolPage(title: "سهرة دورلي") {
            Toast(text: toast, bad: bad)
            Card {
                VStack(alignment: .leading, spacing: 8) {
                    Head(icon: "moon.stars.fill", title: PH[ph] ?? ph, sub: "سهرة \(jstr(s, "date")) · التصويت يسدّ \(jstr(s, "voteAt")) · العرض \(jstr(s, "startAt"))", tint: ph == "live" ? ST.red : ST.violet)
                    KV(k: "الأصوات", v: "\(tot)")
                    if ph == "live" || ph == "soon" { KV(k: "بالدردشة هسّه", v: "\(jint(s, "viewers"))", tint: ST.green) }
                    let rem = jobj(s, "rem")
                    KV(k: "ضغطوا «ذكّرني»", v: "\(jint(rem, "all"))" + (rem["sent"] is NSNumber ? " · وصل لـ \(jint(rem, "sent"))" : ""))
                    if !jstr(s, "winNote").isEmpty { Text("⚠️ " + jstr(s, "winNote")).font(.cairo(12.5, .bold)).foregroundStyle(ST.gold) }
                }
            }
            Text("المرشّحين").font(.cairo(15, .heavy)).foregroundStyle(ST.tx)
            ForEach(Array(cands.enumerated()), id: \.offset) { i, c in
                cand(c, i: i, k: chk.indices.contains(i) ? chk[i] as? J : nil, tot: tot, win: win)
            }
            if win == nil && !cands.isEmpty {
                HStack(spacing: 8) {
                    ActBtn(title: busy ? "دا يفحص…" : "افحص الملفّات هسّه", tint: ST.blue, icon: "magnifyingglass", disabled: busy) { act(["act": "recheck"], ok: "انفحصت") }
                    ActBtn(title: "٣ أفلام ثانية", tint: ST.am2, icon: "dice.fill", disabled: busy) { act(["act": "regen"], ok: "انختارت أفلام جديدة") }
                }
            }
            schedule
            chat
            downloads
            history
        }
        .task { while !Task.isCancelled { await load(); try? await Task.sleep(nanoseconds: 5_000_000_000) } }
        .sheet(item: Binding(get: { swapFor.map { SwapIdx(i: $0) } }, set: { swapFor = $0?.i })) { x in
            NightPick(i: x.i) { item in swapFor = nil; act(["act": "swap", "i": x.i, "item": item], ok: "تبدّل — دا نفحص ملفّه") }
        }
    }

    // ═══ بطاقة مرشّح ═══
    private func cand(_ c: J, i: Int, k: J?, tot: Int, win: Int?) -> some View {
        let v = jint(c, "votes"), p = tot > 0 ? Double(v) / Double(tot) : 0, isWin = win == i
        return Card {
            HStack(alignment: .top, spacing: 12) {
                Poster(url: DW.img(jstr(c, "poster")), w: 70)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(isWin ? ST.am : Color.clear, lineWidth: 2))
                VStack(alignment: .leading, spacing: 6) {
                    HStack { Text(DW.clean(jstr(c, "name"))).font(.cairo(14.5, .bold)).foregroundStyle(ST.tx).lineLimit(2); Spacer(); if isWin { Pill(text: "الفائز") } }
                    Text("\(v) صوت · \(Int((p * 100).rounded()))٪" + (jint(c, "dur") > 0 ? " · \(jint(c, "dur") / 60) د" : "")).font(.cairo(12)).foregroundStyle(ST.tx3)
                    GeometryReader { g in ZStack(alignment: .leading) { Capsule().fill(ST.s2); Capsule().fill(isWin ? ST.am : ST.am2).frame(width: g.size.width * p) } }.frame(height: 5)
                    chkLine(k)
                    HStack(spacing: 8) {
                        if win == nil { ActBtn(title: "بدّل", tint: ST.blue, icon: "arrow.triangle.2.circlepath", disabled: busy) { swapFor = i } }
                        else if !isWin { ActBtn(title: "اعرضه بدال الفائز", tint: ST.am, icon: "crown.fill", disabled: busy) { act(["act": "win", "i": i], ok: "تغيّر فلم السهرة") } }
                    }
                }
            }
        }
    }
    @ViewBuilder private func chkLine(_ k: J?) -> some View {
        let st = k.map { jstr($0, "st") } ?? ""
        switch st {
        case "ok": Text("✅ الملفّ سليم · " + String(format: "%.1f GB", jdbl(k ?? [:], "size") / 1073741824)).font(.cairo(12, .semibold)).foregroundStyle(ST.green)
        case "small": Text("⚠️ الملفّ صغير (\(Int(jdbl(k ?? [:], "size") / 1048576)) MB) — غالبًا إعلان مو فلم. بدّله").font(.cairo(12, .bold)).foregroundStyle(ST.gold)
        case "dead": Text("⚠️ المصدر ميّت ما يشتغل. بدّله").font(.cairo(12, .bold)).foregroundStyle(ST.gold)
        case "busy": Text("⏳ الخطّ مشغول — يعيد الفحص بعد ١٠ دقايق").font(.cairo(12)).foregroundStyle(ST.tx3)
        default: Text("⏳ بعده ما انفحص الملفّ").font(.cairo(12)).foregroundStyle(ST.tx3)
        }
    }

    // ═══ المواعيد ═══
    private var schedule: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Head(icon: "clock.fill", title: "المواعيد", sub: "بتوقيت بغداد", tint: ST.blue)
                Toggle(isOn: $on) { Text("السهرة شغّالة").font(.cairo(14, .bold)).foregroundStyle(ST.tx) }.tint(ST.am)
                    .onChange(of: on) { _ in editing = true }
                HStack(spacing: 10) {
                    field("يسدّ التصويت", $vote); field("يبدي العرض", $start)
                }
                ActBtn(title: "احفظ المواعيد", tint: ST.am, icon: "checkmark", disabled: busy) {
                    act(["act": "cfg", "on": on, "vote": vote, "start": start], ok: "انحفظ") ; editing = false
                }
            }
        }
    }
    private func field(_ label: String, _ b: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.cairo(11.5)).foregroundStyle(ST.tx3)
            TextField("21:00", text: b, onEditingChanged: { e in if e { editing = true } })
                .keyboardType(.numbersAndPunctuation).font(.system(size: 17, weight: .bold, design: .rounded)).foregroundStyle(ST.tx)
                .padding(.horizontal, 12).frame(height: 42).background(ST.s2, in: RoundedRectangle(cornerRadius: 10))
                .environment(\.layoutDirection, .leftToRight)
        }
    }

    // ═══ الدردشة ═══
    private var chat: some View {
        let ms = Array(jarr(s, "ms").suffix(40).reversed())
        return Card {
            VStack(alignment: .leading, spacing: 10) {
                Head(icon: "bubble.left.and.bubble.right.fill", title: "الدردشة الحيّة", sub: "اضغط مطوّلًا على رسالة: امسح، اكتم، اطرد", tint: ST.am2)
                HStack(spacing: 8) {
                    TextField("", text: $say, prompt: Text("رسالة رسميّة باسم «دورلي»").foregroundColor(ST.tx3))
                        .font(.cairo(14)).foregroundStyle(ST.tx).padding(.horizontal, 12).frame(height: 42).background(ST.s2, in: RoundedRectangle(cornerRadius: 10))
                    ActBtn(title: "دزّ", tint: ST.am, icon: "paperplane.fill", disabled: say.trimmingCharacters(in: .whitespaces).isEmpty) {
                        let t = say; say = ""; act(["act": "say", "text": t], ok: "نزلت للكلّ")
                    }
                }
                if ms.isEmpty { Text("ماكو رسائل بعد. الدردشة تنفتح من يسدّ التصويت.").font(.cairo(12.5)).foregroundStyle(ST.tx3) }
                ForEach(Array(ms.enumerated()), id: \.offset) { _, m in msgRow(m) }
            }
        }
    }
    private func msgRow(_ m: J) -> some View {
        let st = jstr(m, "st"), off = jint(m, "o") == 1, id = jint(m, "id")
        return HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(jstr(m, "n")).font(.cairo(12.5, .bold)).foregroundStyle(off ? ST.gold : ST.am2)
                    Text(ago(jdbl(m, "at"))).font(.cairo(10.5)).foregroundStyle(ST.tx3)
                    if jint(m, "rep") > 0 { Pill(text: "بلاغات \(jint(m, "rep"))", tint: ST.gold) }
                    if st == "held" { Pill(text: "مخفيّة", tint: ST.gold) }
                    if st == "del" { Pill(text: "انمسحت", tint: ST.red) }
                }
                Text(jstr(m, "x")).font(.cairo(13.5)).foregroundStyle(st == "del" ? ST.tx3 : ST.tx).strikethrough(st == "del")
            }
            Spacer(minLength: 0)
        }
        .padding(10).background(ST.s2.opacity(off ? 1 : 0.6), in: RoundedRectangle(cornerRadius: 12))
        .contextMenu {
            if !off {
                if st == "ok" { Button(role: .destructive) { act(["act": "del", "id": id], ok: "انمسحت") } label: { Label("امسحها", systemImage: "trash") } }
                if st == "held" || st == "del" { Button { act(["act": "restore", "id": id], ok: "رجعت") } label: { Label("رجّعها", systemImage: "arrow.uturn.backward") } }
                Button { act(["act": "mute", "id": id, "min": 10], ok: "انكتم ١٠ دقايق") } label: { Label("اكتم ١٠ دقايق", systemImage: "speaker.slash") }
                Button(role: .destructive) { act(["act": "mute", "id": id, "min": 720, "purge": 1], ok: "انطرد لآخر الليلة") } label: { Label("اطرده وامسح رسائله", systemImage: "person.fill.xmark") }
            }
        }
    }

    // ═══ التنزيل للسيرفر ═══
    @ViewBuilder private var downloads: some View {
        let dl = jarr(s, "dl")
        let names = ["dl": "دا ينزل", "ready": "جاهز على السيرفر", "conv": "دا يتحوّل", "wait": "ينتظر", "retry": "يعيد المحاولة", "fail": "فشل — يشتغل من المزوّد", "deleted": "انمسح"]
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Head(icon: "arrow.down.circle.fill", title: "التنزيل للسيرفر", sub: "قبل العرض بساعتين ينزل المتصدّر، وبسدّ التصويت الفائز", tint: ST.green)
                if dl.isEmpty { Text("يبدي قبل العرض بساعتين.").font(.cairo(12.5)).foregroundStyle(ST.tx3) }
                ForEach(Array(dl.enumerated()), id: \.offset) { _, d in
                    KV(k: DW.clean(jstr(d, "name")), v: (names[jstr(d, "state")] ?? jstr(d, "state")) + (jstr(d, "state") == "dl" ? " \(jint(d, "pct"))٪" : ""),
                       tint: jstr(d, "state") == "ready" ? ST.green : jstr(d, "state") == "fail" ? ST.red : Color.white)
                }
            }
        }
    }

    // ═══ السهرات السابقة ═══
    @ViewBuilder private var history: some View {
        let h = jarr(s, "hist")
        if !h.isEmpty {
            Card {
                VStack(alignment: .leading, spacing: 8) {
                    Head(icon: "hand.thumbsup.fill", title: "السهرات السابقة وتقييمها", sub: "الصفوف اللي أفلامها عجبت الناس تطلع أكثر بالترشيح", tint: ST.am)
                    ForEach(Array(h.prefix(10).enumerated()), id: \.offset) { _, x in
                        KV(k: jstr(x, "date") + " · " + DW.clean(jstr(x, "name").isEmpty ? jstr(x, "id") : jstr(x, "name")), v: "👍 \(jint(x, "up"))  👎 \(jint(x, "dn"))")
                    }
                }
            }
        }
    }

    // ═══ الشبكة ═══
    private func load() async {
        guard let d = try? await DW.get("/api/admin/night") else { return }
        s = d
        if !editing { let c = jobj(d, "cfg"); vote = jstr(c, "vote"); start = jstr(c, "start"); on = jbool(c, "on") }
    }
    private func act(_ b: J, ok: String) {
        busy = true
        Task {
            let r = await NightAdmin.post(b); busy = false
            if jbool(r, "ok") { bad = false; toast = ok } else { bad = true; toast = jstr(r, "msg").isEmpty ? "ما نجحت" : jstr(r, "msg") }
            await load()
            try? await Task.sleep(nanoseconds: 3_000_000_000); if toast == ok || bad { toast = "" }
        }
    }
}

struct SwapIdx: Identifiable { let i: Int; var id: Int { i } }

enum NightAdmin {
    /// POST يرجّع رسالة السيرفر حتى مع 4xx (مثل «التصويت سدّ»)
    static func post(_ b: J) async -> J {
        guard let t = Vault.get(), let u = URL(string: DW.base + "/api/admin/night?token=" + DW.enc(t)) else { return ["ok": false, "msg": "سجّل دخول من جديد"] }
        var r = URLRequest(url: u); r.httpMethod = "POST"; r.setValue("application/json", forHTTPHeaderField: "Content-Type"); r.timeoutInterval = 60
        r.httpBody = try? JSONSerialization.data(withJSONObject: b)
        guard let res = try? await DW.session.data(for: r) else { return ["ok": false, "msg": "ما وصلنا للسيرفر"] }
        return ((try? JSONSerialization.jsonObject(with: res.0)) as? J) ?? ["ok": false]
    }
}

/// اختيار فلم بدال مرشّح: بحث بالاسم بكلّ المكتبة
struct NightPick: View {
    let i: Int; let pick: (J) -> Void
    @State private var q = ""
    @State private var items: [J] = []
    @State private var loading = false
    @Environment(\.dismiss) private var dismiss
    private let cols = [GridItem(.adaptive(minimum: 100), spacing: 10)]
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    TextField("", text: $q, prompt: Text("دوّر على فلم بالاسم").foregroundColor(ST.tx3))
                        .font(.cairo(15)).foregroundStyle(ST.tx).padding(.horizontal, 12).frame(height: 46).background(ST.s2, in: RoundedRectangle(cornerRadius: 12))
                    Text("بعد ما تختار، السيرفر يفحص ملفّه: إذا طلع إعلان قصير أو ميّت ينكتب تحت المرشّح.").font(.cairo(12)).foregroundStyle(ST.tx3)
                    if loading { ProgressView().tint(ST.am).frame(maxWidth: .infinity) }
                    LazyVGrid(columns: cols, spacing: 12) {
                        ForEach(Array(items.enumerated()), id: \.offset) { _, x in
                            Button { pick(["id": jstr(x, "id"), "name": jstr(x, "name"), "poster": poster(x), "ext": jstr(x, "ext").isEmpty ? "mp4" : jstr(x, "ext"), "year": jint(x, "year"), "rating": jdbl(x, "rating")]) } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Poster(url: DW.img(poster(x)), w: 100)
                                    Text(DW.clean(jstr(x, "name"))).font(.cairo(11.5, .semibold)).foregroundStyle(ST.tx2).lineLimit(2)
                                }
                            }.buttonStyle(.plain)
                        }
                    }
                }.padding(16)
            }
            .background(STBackground())
            .navigationTitle("بدّل المرشّح \(i + 1)").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("سدّ") { dismiss() }.foregroundStyle(ST.am) } }
            .task(id: q) {
                let v = q.trimmingCharacters(in: .whitespaces); if v.count < 2 { items = []; return }
                try? await Task.sleep(nanoseconds: 350_000_000); if Task.isCancelled { return }
                loading = true
                let d = (try? await DW.get("/api/search?q=" + DW.enc(v))) ?? [:]
                loading = false
                items = Array(jarr(d, "items").filter { (jstr($0, "_kind").isEmpty ? jstr($0, "kind") : jstr($0, "_kind")) == "movie" }.prefix(30))
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }
    private func poster(_ x: J) -> String { jstr(x, "icon").isEmpty ? jstr(x, "poster") : jstr(x, "icon") }
}
