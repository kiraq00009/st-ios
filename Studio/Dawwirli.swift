import SwiftUI

// MARK: - لوحة دورلي (الرئيسيّة)
struct ToolItem: Identifiable {
    let id: String; let icon: String; let name: String; let tint: Color
    var badge = 0; var web = false
    let dest: AnyView
}

struct DawwirliHome: View {
    var body: some View {
        Live(every: 12, load: { () async throws -> (J, J, J, J) in
            async let s = DW.get("/api/admin/stats")
            async let c = DW.get("/api/admin/chat")
            async let r = DW.get("/api/requests")
            async let w = DW.get("/api/admin/supwatch")
            return (try await s, try await c, try await r, (try? await w) ?? [:])
        }) { v, _ in
            HomeBody(s: v.0, c: v.1, r: v.2, w: v.3)
        }
        .background(STBackground())
        .navigationTitle("Dawwirli").navigationBarTitleDisplayMode(.inline)
    }
}

struct HomeBody: View {
    let s: J; let c: J; let r: J; let w: J
    private let cols2 = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
    private let cols3 = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                status
                tiles
                waitingCard
                ForEach(Array(groups.enumerated()), id: \.offset) { _, g in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(g.0).font(.cairo(16, .heavy)).foregroundStyle(Color.white)
                        LazyVGrid(columns: cols3, spacing: 10) { ForEach(g.1) { t in ToolTile(t: t) } }
                    }
                }
                lines
            }
            .padding(16)
        }
    }

    // الحالة العامّة
    private var status: some View {
        let maint = jbool(s, "maintenance"), up = jint(s, "uptimeMin"), wd = jobj(s, "watchdog")
        return HStack(spacing: 12) {
            ZStack {
                Circle().fill((maint ? ST.red : ST.green).opacity(0.18)).frame(width: 46, height: 46)
                Image(systemName: maint ? "wrench.and.screwdriver.fill" : "checkmark.seal.fill").font(.system(size: 19, weight: .bold)).foregroundStyle(maint ? ST.red : ST.green)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(maint ? "الموقع بوضع الصيانة" : "الموقع شغّال").font(.cairo(17, .heavy)).foregroundStyle(Color.white)
                Text("شغّال من " + (up >= 1440 ? "\(up / 1440) يوم" : (up >= 60 ? "\(up / 60) ساعة" : "\(up) دقيقة")) + " · الحمل " + String(format: "%.1f", jdbl(wd, "load")))
                    .font(.cairo(12)).foregroundStyle(ST.tx3)
            }
            Spacer(minLength: 0)
            NavigationLink { HealthView() } label: {
                Text("التفاصيل").font(.cairo(12.5, .bold)).foregroundStyle(ST.am).padding(.horizontal, 12).padding(.vertical, 6).background(ST.am.opacity(0.14), in: Capsule())
            }.buttonStyle(.plain)
        }
        .padding(14)
        .background(
            ZStack { ST.s1; RadialGradient(colors: [(maint ? ST.red : ST.green).opacity(0.16), Color.clear], center: .topLeading, startRadius: 0, endRadius: 240) }
                .clipShape(RoundedRectangle(cornerRadius: 20)))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke((maint ? ST.red : ST.green).opacity(0.28)))
    }

    private var tiles: some View {
        let u = jobj(s, "usage"), vod = jobj(s, "vod"), live = jobj(s, "live"), disk = jobj(s, "disk")
        return LazyVGrid(columns: cols2, spacing: 10) {
            Tile(value: "\(jint(u, "onlineNow"))", label: "متّصل هسه", icon: "person.2.fill", tint: ST.green)
            Tile(value: "\(jint(u, "active24h"))", label: "زوّار آخر ٢٤ ساعة", icon: "chart.bar.fill", tint: ST.blue)
            Tile(value: "\(jint(vod, "activeStreams")) / \(jint(vod, "capTotal"))", label: "خطوط الأفلام المشغولة", icon: "film.fill", tint: ST.am)
            Tile(value: "\(jint(live, "viewersNow"))", label: "يشوفون المباشر", icon: "dot.radiowaves.left.and.right", tint: ST.red)
            Tile(value: "\(jint(u, "loadsToday"))", label: "فتحات اليوم", icon: "arrow.down.app.fill", tint: ST.violet)
            Tile(value: "\(jint(disk, "usedPct"))٪", label: "القرص (\(jint(disk, "freeGB")) GB فاضي)", icon: "internaldrive.fill", tint: jint(disk, "usedPct") > 90 ? ST.red : ST.green)
        }
    }

    // منو ينتظر ردّك
    @ViewBuilder private var waitingCard: some View {
        let waiting = jarr(w, "waiting")
        if !waiting.isEmpty {
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Head(icon: "hourglass", title: "ينتظرون ردّك", sub: "\(waiting.count) محادثة بلا ردّ", tint: ST.am2)
                        NavigationLink { SupWatchView() } label: { Text("الكلّ").font(.cairo(12.5, .bold)).foregroundStyle(ST.am) }.buttonStyle(.plain)
                    }
                    ForEach(Array(waiting.prefix(3).enumerated()), id: \.offset) { _, x in
                        NavigationLink { ChatThread(dev: jstr(x, "dev"), name: jstr(x, "name")) } label: {
                            HStack(spacing: 10) {
                                Text(String(jstr(x, "name").first ?? "؟")).font(.system(size: 14, weight: .heavy)).foregroundStyle(ST.onAm).frame(width: 34, height: 34).background(ST.am.gradient, in: Circle())
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(jstr(x, "name").isEmpty ? "زائر" : jstr(x, "name")).font(.cairo(13, .bold)).foregroundStyle(Color.white)
                                    Text(jstr(x, "text")).font(.cairo(12)).foregroundStyle(ST.tx2).lineLimit(1)
                                }
                                Spacer(minLength: 0)
                                Text(jstr(x, "ago")).font(.cairo(11)).foregroundStyle(ST.tx3)
                            }.contentShape(Rectangle())
                        }.buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // خطوط المزوّدين (ملخّص)
    private var lines: some View {
        let cache = jobj(s, "cache")
        return NavigationLink { ProvidersView() } label: {
            Card {
                HStack {
                    Head(icon: "antenna.radiowaves.left.and.right", title: "الخطوط والكاش", sub: "\(jint(cache, "readyCount")) عمل جاهز · \(jint(cache, "convertingCount")) يتحوّل", tint: ST.blue)
                    Image(systemName: "chevron.left").foregroundStyle(ST.tx3)
                }
            }
        }.buttonStyle(.plain)
    }

    private func t<V: View>(_ id: String, _ icon: String, _ name: String, _ tint: Color, badge: Int = 0, _ v: V) -> ToolItem {
        ToolItem(id: id, icon: icon, name: name, tint: tint, badge: badge, dest: AnyView(v))
    }
    private func web(_ path: String, _ icon: String, _ name: String, _ tint: Color) -> ToolItem {
        ToolItem(id: "w:" + path, icon: icon, name: name, tint: tint, web: true, dest: AnyView(WebTool(path: path, title: name)))
    }

    private var groups: [(String, [ToolItem])] {
        let reqs = jarr(r, "items")
        let pink = Color(red: 1, green: 0.42, blue: 0.52), cyan = Color(red: 0.2, green: 0.8, blue: 0.85)
        let g0: [ToolItem] = [
                t("chat", "message.fill", "محادثات الدعم", ST.am, badge: jint(c, "unread"), ChatList()),
                t("req", "tray.full.fill", "طلبات الزوّار", ST.blue, badge: reqs.filter { ($0["unreadAdmin"] as? Bool) == true }.count, RequestsView()),
                t("sup", "hourglass", "المتابعة", ST.am2, badge: jarr(w, "waiting").count, SupWatchView()),
                t("fb", "exclamationmark.bubble.fill", "الملاحظات", pink, FeedbackView()),
                t("bot", "sparkles", "مساعد دورلي", ST.violet, BotStatsView()),
                web("botadmin.html", "graduationcap.fill", "تعليم المساعد", ST.green),
        ]
        let g1: [ToolItem] = [
                t("quick", "megaphone.fill", "إعلان وإشعار", ST.red, ActionsView()),
                t("pop", "rectangle.portrait.on.rectangle.portrait.fill", "إعلانات منبثقة", ST.am2, AdsView(kind: .pop)),
                t("hads", "rectangle.stack.fill", "بنر الرئيسيّة", ST.am, AdsView(kind: .home)),
                web("tgbot.html", "paperplane.fill", "بوت التليكرام", Color(red: 0.16, green: 0.67, blue: 0.93)),
                web("messages.html", "envelope.fill", "رسائل الطلبات", pink),
                t("reacts", "face.smiling.fill", "ردود الفعل", cyan, ReactsView()),
        ]
        let g2: [ToolItem] = [
                t("new", "sparkle", "جديد دورلي", ST.violet, NewestView()),
                t("daily", "target", "ترشيح اليوم", ST.am, DailyView()),
                t("hide", "eye.slash.fill", "إخفاء عمل", pink, HideView()),
                web("manager.html", "square.grid.3x3.fill", "مدير المحتوى", ST.blue),
                web("dl.html", "arrow.down.circle.fill", "التنزيلات", ST.green),
                web("studio.html", "film.stack.fill", "استوديو الريلز", ST.am2),
                web("motion.html", "wand.and.stars", "استوديو الموشن", ST.red),
                web("cinema-admin.html", "popcorn.fill", "سينما دورلي", cyan),
                web("/dawwir/admin.html", "play.square.stack.fill", "لوحة دوّر", ST.violet),
        ]
        let g3: [ToolItem] = [
                t("watch", "eye.fill", "يُشاهَد الآن", ST.green, WatchingView()),
                t("top", "flame.fill", "الأكثر مشاهدة", ST.am2, TopView(items: jarr(s, "topTitles"))),
                web("stats.html", "chart.xyaxis.line", "الإحصاءات", cyan),
                web("users.html", "person.3.fill", "المستخدمون", ST.blue),
        ]
        let g4: [ToolItem] = [
                t("prov", "antenna.radiowaves.left.and.right", "المزوّدون", ST.blue, ProvidersView()),
                t("tv", "sportscourt.fill", "قنوات الرياضة", ST.am, TVSportsView()),
                t("health", "heart.text.square.fill", "صحّة النظام", ST.green, HealthView()),
                web("live-admin.html", "tv.fill", "إدارة المباشر", ST.red),
                web("scout.html", "magnifyingglass.circle.fill", "فحص المزوّدين", cyan),
                web("compare.html", "scalemass.fill", "مقارنة المزوّدين", ST.green),
                web("trials.html", "testtube.2", "مزوّدون تجريبيّون", ST.red),
                web("apanel.html", "a.square.fill", "مزوّد أ", ST.blue),
        ]
        let g5: [ToolItem] = [
                t("ops", "wrench.and.screwdriver.fill", "صيانة وتشغيل", ST.am, OpsView()),
                web("panel.html", "rectangle.3.group.fill", "اللوحة الكاملة", ST.violet),
        ]
        return [("الدعم والمحادثات", g0), ("التواصل والإعلانات", g1), ("المحتوى", g2), ("المشاهدون", g3), ("المزوّدون والبثّ", g4), ("التشغيل", g5)]
    }
}

struct ToolTile: View {
    let t: ToolItem
    var body: some View {
        NavigationLink(destination: t.dest) {
            VStack(spacing: 8) {
                Image(systemName: t.icon).font(.system(size: 19, weight: .semibold)).foregroundStyle(Color.white)
                    .frame(width: 46, height: 46).background(t.tint.gradient, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(alignment: .topTrailing) {
                        if t.badge > 0 {
                            Text("\(t.badge)").font(.system(size: 11, weight: .heavy)).foregroundStyle(Color.white)
                                .padding(.horizontal, 5).frame(minWidth: 20, minHeight: 20).background(ST.red, in: Capsule()).offset(x: 8, y: -8)
                        }
                    }
                Text(t.name).font(.cairo(12, .bold)).foregroundStyle(Color.white).lineLimit(2).multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity).frame(height: 34, alignment: .top)
            }
            .padding(.top, 14).padding(.bottom, 8).padding(.horizontal, 4)
            .frame(maxWidth: .infinity)
            .background(ST.s1, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color(white: 1, opacity: 0.07)))
            .overlay(alignment: .topLeading) {
                if t.web { Image(systemName: "globe").font(.system(size: 9, weight: .bold)).foregroundStyle(ST.tx3).padding(7) }
            }
            .contentShape(Rectangle())
        }.buttonStyle(.plain)
    }
}

// MARK: - محادثات الدعم
struct ChatList: View {
    var body: some View {
        Live(every: 6, load: { try await DW.get("/api/admin/chat") }) { d, _ in
            let list = jarr(d, "list")
            ScrollView {
                LazyVStack(spacing: 8) {
                    if list.isEmpty { Text("ماكو محادثات").font(.cairo(14)).foregroundStyle(ST.tx3).padding(.top, 60) }
                    ForEach(Array(list.enumerated()), id: \.offset) { _, t in
                        NavigationLink { ChatThread(dev: jstr(t, "dev"), name: jstr(t, "name")) } label: {
                            HStack(spacing: 12) {
                                Text(String(jstr(t, "name").first ?? "؟")).font(.system(size: 17, weight: .heavy)).foregroundStyle(ST.onAm)
                                    .frame(width: 42, height: 42).background(ST.am.gradient, in: Circle())
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text(jstr(t, "name").isEmpty ? "زائر" : jstr(t, "name")).font(.cairo(14.5, .bold)).foregroundStyle(Color.white)
                                        if jstr(t, "contact") == "iPhone" { Pill(text: "آيفون", tint: ST.blue) }
                                        Spacer()
                                        Text(ago((t["at"] as? NSNumber)?.doubleValue ?? 0)).font(.cairo(11)).foregroundStyle(ST.tx3)
                                    }
                                    Text((jstr(t, "lastFrom") == "a" ? "أنت: " : "") + jstr(t, "last")).font(.cairo(12.5)).foregroundStyle((t["unread"] as? Bool) == true ? Color.white : ST.tx3).lineLimit(1)
                                }
                                if (t["unread"] as? Bool) == true { Circle().fill(ST.am).frame(width: 9, height: 9) }
                            }
                            .padding(12).background(ST.s1, in: RoundedRectangle(cornerRadius: 16))
                        }.buttonStyle(.plain)
                    }
                }.padding(14)
            }
        }
        .background(STBackground())
        .navigationTitle("محادثات الدعم").navigationBarTitleDisplayMode(.inline)
    }
}

struct ChatThread: View {
    let dev: String; let name: String
    @Environment(\.dismiss) private var dismiss
    @State private var msgs: [J] = []
    @State private var text = ""
    @State private var sending = false
    @State private var confirmDel = false
    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { sp in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(msgs.enumerated()), id: \.offset) { i, m in
                            let mine = jstr(m, "f") == "a"
                            HStack {
                                if mine { Spacer(minLength: 50) }
                                VStack(alignment: .leading, spacing: 4) {
                                    if !jstr(m, "img").isEmpty {
                                        AsyncImage(url: DW.img(jstr(m, "img"))) { $0.resizable().scaledToFit() } placeholder: { ProgressView() }
                                            .frame(maxWidth: 220).clipShape(RoundedRectangle(cornerRadius: 12))
                                    }
                                    if !jstr(m, "t").isEmpty { Text(jstr(m, "t")).font(.cairo(14.5)).foregroundStyle(mine ? ST.onAm : Color.white) }
                                    Text(ago((m["at"] as? NSNumber)?.doubleValue ?? 0)).font(.cairo(10)).foregroundStyle(mine ? ST.onAm.opacity(0.6) : ST.tx3)
                                }
                                .padding(.horizontal, 14).padding(.vertical, 9)
                                .background(mine ? AnyShapeStyle(ST.am) : AnyShapeStyle(ST.s2), in: RoundedRectangle(cornerRadius: 18))
                                if !mine { Spacer(minLength: 50) }
                            }.id(i)
                        }
                        Color.clear.frame(height: 2).id("end")
                    }.padding(14)
                }
                .onChange(of: msgs.count) { _ in withAnimation { sp.scrollTo("end", anchor: .bottom) } }
            }
            HStack(spacing: 8) {
                TextField("", text: $text, prompt: Text("اكتب ردّك…").foregroundColor(ST.tx3), axis: .vertical)
                    .lineLimit(1...5).font(.cairo(14.5)).foregroundStyle(Color.white)
                    .padding(.horizontal, 14).padding(.vertical, 11).background(ST.s2, in: RoundedRectangle(cornerRadius: 20))
                Button(action: reply) {
                    Image(systemName: "arrow.up").font(.system(size: 16, weight: .bold)).foregroundStyle(ST.onAm).frame(width: 44, height: 44)
                        .background(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || sending ? ST.am.opacity(0.35) : ST.am, in: Circle())
                }.buttonStyle(.plain).disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || sending)
            }.padding(12).background(ST.s1)
        }
        .background(STBackground())
        .navigationTitle(name.isEmpty ? "زائر" : name).navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button { confirmDel = true } label: { Image(systemName: "trash").foregroundStyle(ST.red) } } }
        .confirmationDialog("تمسح هاي المحادثة كلها؟", isPresented: $confirmDel, titleVisibility: .visible) {
            Button("امسحها", role: .destructive) { Task { _ = try? await DW.post("/api/admin/chat", ["action": "delete", "dev": dev]); dismiss() } }
            Button("إلغاء", role: .cancel) {}
        }
        .task {
            _ = try? await DW.post("/api/admin/chat", ["action": "seen", "dev": dev])
            while !Task.isCancelled {
                if let d = try? await DW.get("/api/admin/chat?dev=" + DW.enc(dev)) {
                    let m = jarr(jobj(d, "thread"), "msgs"); if m.count != msgs.count { msgs = m }
                }
                try? await Task.sleep(nanoseconds: 4_000_000_000)
            }
        }
    }
    private func reply() {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines); guard !t.isEmpty else { return }
        sending = true; text = ""
        msgs.append(["f": "a", "t": t, "at": Date().timeIntervalSince1970 * 1000])
        Task {
            if let d = try? await DW.post("/api/admin/chat", ["action": "reply", "dev": dev, "text": t]) { msgs = jarr(jobj(d, "thread"), "msgs") }
            sending = false
        }
    }
}

// MARK: - طلبات المستخدمين
struct RequestsView: View {
    @State private var filter = 0
    @State private var replyTo: J? = nil
    @State private var replyText = ""
    @State private var delAt: String? = nil
    @State private var toast = ""
    var body: some View {
        Live(every: 15, load: { try await DW.get("/api/requests") }) { d, refresh in
            let all = jarr(d, "items").sorted { (($0["at"] as? NSNumber)?.doubleValue ?? 0) > (($1["at"] as? NSNumber)?.doubleValue ?? 0) }
            let items = all.filter { filter == 0 ? !($0["fulfilled"] as? Bool ?? false) : ($0["fulfilled"] as? Bool ?? false) }
            ScrollView {
                VStack(spacing: 10) {
                    Picker("", selection: $filter) { Text("بانتظار التوفير").tag(0); Text("وفّرتها").tag(1) }.pickerStyle(.segmented)
                    if !toast.isEmpty { Text(toast).font(.cairo(13, .bold)).foregroundStyle(ST.green) }
                    if items.isEmpty { Text("ماكو شي هنا").font(.cairo(14)).foregroundStyle(ST.tx3).padding(.top, 40) }
                    ForEach(Array(items.enumerated()), id: \.offset) { _, it in
                        let at = jstr(it, "at")
                        Card {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(alignment: .top, spacing: 12) {
                                    Poster(url: DW.img(jstr(it, "poster")), w: 54)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(jstr(it, "title")).font(.cairo(15, .bold)).foregroundStyle(Color.white).lineLimit(2)
                                        HStack(spacing: 6) {
                                            Pill(text: jstr(it, "kind") == "series" || jstr(it, "kind") == "tv" ? "مسلسل" : "فلم", tint: ST.blue)
                                            if jint(it, "n") > 1 { Pill(text: "طلبه \(jint(it, "n")) أشخاص", tint: ST.am) }
                                            if (it["unreadAdmin"] as? Bool) == true { Pill(text: "جديد", tint: ST.red) }
                                        }
                                        Text("\(jstr(it, "who")) · \(ago((it["at"] as? NSNumber)?.doubleValue ?? 0))").font(.cairo(11.5)).foregroundStyle(ST.tx3)
                                        if let last = jarr(it, "thread").last { Text("آخر ردّ: " + jstr(last, "text")).font(.cairo(11.5)).foregroundStyle(ST.tx2).lineLimit(2) }
                                    }
                                }
                                HStack(spacing: 8) {
                                    if !(it["fulfilled"] as? Bool ?? false) {
                                        Button {
                                            Task {
                                                let r = try? await DW.get("/api/admin/request/fulfill?at=" + DW.enc(at))
                                                toast = (r?["ok"] as? Bool) == true ? "تمّ — وصله إشعار إنّ طلبه متوفّر ✓" : "ما لكيته بالمكتبة بعد — تأكّد إنّه انضاف"
                                                refresh()
                                            }
                                        } label: { act("وفّرته ✓", ST.green) }.buttonStyle(.plain)
                                    }
                                    Button { replyTo = it; replyText = "" } label: { act("ردّ", ST.am) }.buttonStyle(.plain)
                                    Spacer()
                                    Button { delAt = at } label: { Image(systemName: "trash").foregroundStyle(ST.red).frame(width: 36, height: 36).background(ST.red.opacity(0.12), in: Circle()) }.buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }.padding(14)
            }
            .confirmationDialog("تمسح هذا الطلب؟", isPresented: Binding(get: { delAt != nil }, set: { if !$0 { delAt = nil } }), titleVisibility: .visible) {
                Button("امسحه", role: .destructive) { if let a = delAt { Task { _ = try? await DW.get("/api/request/delete?at=" + DW.enc(a)); delAt = nil; refresh() } } }
                Button("إلغاء", role: .cancel) { delAt = nil }
            }
            .sheet(isPresented: Binding(get: { replyTo != nil }, set: { if !$0 { replyTo = nil } })) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("ردّ على: " + jstr(replyTo ?? [:], "title")).font(.cairo(16, .heavy)).foregroundStyle(Color.white)
                    TextField("", text: $replyText, prompt: Text("مثلًا: انضاف، تكدر تشوفه هسه 🎉").foregroundColor(ST.tx3), axis: .vertical)
                        .lineLimit(3...6).font(.cairo(15)).foregroundStyle(Color.white).padding(12).background(ST.s2, in: RoundedRectangle(cornerRadius: 14))
                    Button {
                        let at = jstr(replyTo ?? [:], "at"), t = replyText
                        Task { _ = try? await DW.post("/api/request/reply", ["at": NSNumber(value: Int64(at) ?? 0), "text": t]); replyTo = nil; toast = "انبعث الردّ ✓"; refresh() }
                    } label: { Text("إرسال").font(.cairo(16, .heavy)).foregroundStyle(ST.onAm).frame(maxWidth: .infinity).frame(height: 48).background(ST.am, in: Capsule()) }
                        .buttonStyle(.plain).disabled(replyText.trimmingCharacters(in: .whitespaces).isEmpty)
                    Spacer()
                }
                .padding(20).background(ST.bg.ignoresSafeArea())
                .presentationDetents([.medium])
                .environment(\.layoutDirection, .rightToLeft)
            }
        }
        .background(STBackground())
        .navigationTitle("طلبات المستخدمين").navigationBarTitleDisplayMode(.inline)
    }
    private func act(_ t: String, _ c: Color) -> some View {
        Text(t).font(.cairo(13.5, .bold)).foregroundStyle(c).padding(.horizontal, 16).padding(.vertical, 8)
            .background(c.opacity(0.14), in: Capsule()).overlay(Capsule().stroke(c.opacity(0.5)))
    }
}

// MARK: - يُشاهَد الآن
struct WatchingView: View {
    var body: some View {
        Live(every: 8, load: { () async throws -> (J, J) in
            async let n = DW.get("/api/admin/livenow"); async let w = DW.get("/api/admin/watching")
            return (try await n, try await w)
        }) { v, _ in
            let (n, w) = v
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        Tile(value: "\(jint(n, "online"))", label: "متّصل", icon: "person.2.fill", tint: ST.green)
                        Tile(value: "\(jint(n, "vodViewers"))", label: "يشوف أفلام/مسلسلات", icon: "film.fill", tint: ST.am)
                        Tile(value: "\(jint(jobj(w, "live"), "total"))", label: "بالمباشر", icon: "dot.radiowaves.left.and.right", tint: ST.red)
                    }
                    Text("الأعمال").font(.cairo(16, .heavy)).foregroundStyle(Color.white).padding(.top, 4)
                    if jarr(n, "vod").isEmpty { Text("ماكو أحد يشوف فلم هسه").font(.cairo(13)).foregroundStyle(ST.tx3) }
                    ForEach(Array(jarr(n, "vod").enumerated()), id: \.offset) { _, x in
                        HStack(spacing: 12) {
                            Poster(url: DW.img(jstr(x, "poster")))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(DW.clean(jstr(x, "name"))).font(.cairo(14, .bold)).foregroundStyle(Color.white).lineLimit(1)
                                Pill(text: jstr(x, "kind") == "series" ? "مسلسل" : "فلم", tint: ST.blue)
                            }
                            Spacer()
                            Label("\(jint(x, "n"))", systemImage: "eye.fill").font(.system(size: 14, weight: .bold)).foregroundStyle(ST.green)
                        }.padding(10).background(ST.s1, in: RoundedRectangle(cornerRadius: 14))
                    }
                    if !jarr(jobj(w, "live"), "chans").isEmpty {
                        Text("القنوات").font(.cairo(16, .heavy)).foregroundStyle(Color.white).padding(.top, 4)
                        ForEach(Array(jarr(jobj(w, "live"), "chans").enumerated()), id: \.offset) { _, ch in
                            HStack {
                                Circle().fill(ST.red).frame(width: 8, height: 8)
                                Text(DW.clean(jstr(ch, "name").isEmpty ? jstr(ch, "id") : jstr(ch, "name"))).font(.cairo(14, .bold)).foregroundStyle(Color.white)
                                Spacer()
                                Label("\(max(jint(ch, "n"), jint(ch, "viewers")))", systemImage: "eye.fill").font(.system(size: 14, weight: .bold)).foregroundStyle(ST.red)
                            }.padding(12).background(ST.s1, in: RoundedRectangle(cornerRadius: 14))
                        }
                    }
                }.padding(14)
            }
        }
        .background(STBackground())
        .navigationTitle("يُشاهَد الآن").navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - مساعد دورلي
struct BotStatsView: View {
    var body: some View {
        Live(every: 30, load: { try await DW.get("/api/admin/bot?logs=1") }) { d, _ in
            let st = jobj(d, "stats"), h = jobj(d, "health"), intents = jobj(d, "intents")
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        Tile(value: "\(jint(st, "now"))", label: "يحجي ويّاه هسه", icon: "bubble.left.and.bubble.right.fill", tint: ST.green)
                        Tile(value: "\(jint(st, "today"))", label: "اليوم (\(jint(st, "todayMsgs")) رسالة)", icon: "calendar", tint: ST.blue)
                        Tile(value: "\(jint(h, "understood"))٪", label: "فهم الأسئلة", icon: "brain.head.profile", tint: ST.violet)
                        Tile(value: "\(jint(h, "playRate"))٪", label: "اقتراح ⇐ تشغيل", icon: "play.fill", tint: ST.am)
                        Tile(value: "\(jint(st, "week"))", label: "هذا الأسبوع", icon: "chart.bar.fill", tint: ST.blue)
                        Tile(value: "\(jint(st, "total"))", label: "المجموع", icon: "person.3.fill", tint: ST.green)
                    }
                    Card {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("شنو يطلبون أكثر").font(.cairo(16, .heavy)).foregroundStyle(Color.white)
                            let top = intents.compactMap { k, v in (v as? NSNumber).map { (k, $0.intValue) } }.sorted { $0.1 > $1.1 }.prefix(8)
                            let mx = max(1, top.first?.1 ?? 1)
                            ForEach(Array(top.enumerated()), id: \.offset) { _, e in
                                let k = e.0, n = e.1
                                HStack(spacing: 8) {
                                    Text(intentName(k)).font(.cairo(12.5)).foregroundStyle(ST.tx2).frame(width: 90, alignment: .leading)
                                    GeometryReader { g in Capsule().fill(ST.violet.gradient).frame(width: max(6, g.size.width * CGFloat(n) / CGFloat(mx))) }.frame(height: 8)
                                    Text("\(n)").font(.system(size: 12, weight: .bold)).foregroundStyle(ST.tx3).frame(width: 40, alignment: .trailing)
                                }
                            }
                        }
                    }
                    Text("آخر المحادثات").font(.cairo(16, .heavy)).foregroundStyle(Color.white)
                    ForEach(Array(jarr(d, "threads").prefix(25).enumerated()), id: \.offset) { _, t in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(jstr(t, "name").isEmpty ? "زائر" : jstr(t, "name")).font(.cairo(13.5, .bold)).foregroundStyle(Color.white)
                                if jint(t, "miss") > 0 { Pill(text: "ما فهم \(jint(t, "miss"))", tint: ST.red) }
                                Spacer()
                                Text("\(jint(t, "n")) رسالة").font(.cairo(11)).foregroundStyle(ST.tx3)
                            }
                            Text(jstr(t, "lastU")).font(.cairo(12.5)).foregroundStyle(ST.tx2).lineLimit(2)
                        }.padding(12).background(ST.s1, in: RoundedRectangle(cornerRadius: 14))
                    }
                    Link(destination: URL(string: DW.base + "/botadmin.html")!) {
                        Label("علّم المساعد (صفحة الإدارة الكاملة)", systemImage: "graduationcap.fill").font(.cairo(14, .bold)).foregroundStyle(ST.violet)
                    }.padding(.top, 4)
                }.padding(14)
            }
        }
        .background(STBackground())
        .navigationTitle("مساعد دورلي").navigationBarTitleDisplayMode(.inline)
    }
    private func intentName(_ k: String) -> String {
        ["pick": "اختارلي", "title": "اسم عمل", "problem": "مشكلة", "request": "طلب عمل", "reqsend": "أرسل طلب", "live": "مباشر", "sport": "رياضة",
         "miss": "ما فهمه", "prob": "مشكلة تشغيل", "kind": "نوع", "go": "شغّل", "more": "المزيد", "answer": "جواب", "other": "غيرها"][k] ?? k
    }
}

// MARK: - الملاحظات
struct FeedbackView: View {
    var body: some View {
        Live(every: 30, load: { try await DW.get("/api/admin/feedback") }) { d, _ in
            ScrollView {
                LazyVStack(spacing: 10) {
                    if jarr(d, "items").isEmpty { Text("ماكو ملاحظات").font(.cairo(14)).foregroundStyle(ST.tx3).padding(.top, 60) }
                    ForEach(Array(jarr(d, "items").enumerated()), id: \.offset) { _, f in
                        Card {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Pill(text: jstr(f, "kind").isEmpty ? "ملاحظة" : jstr(f, "kind"), tint: ST.blue)
                                    if (f["read"] as? Bool) != true { Pill(text: "جديد", tint: ST.red) }
                                    Spacer()
                                    Text(ago((f["at"] as? NSNumber)?.doubleValue ?? 0)).font(.cairo(11)).foregroundStyle(ST.tx3)
                                }
                                Text(jstr(f, "text")).font(.cairo(14)).foregroundStyle(Color.white)
                                if !jstr(f, "contact").isEmpty { Text("للتواصل: " + jstr(f, "contact")).font(.cairo(12)).foregroundStyle(ST.am) }
                            }
                        }
                    }
                }.padding(14)
            }
        }
        .background(STBackground())
        .navigationTitle("الملاحظات").navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - الأكثر مشاهدة
struct TopView: View {
    let items: [J]
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.offset) { i, x in
                    HStack(spacing: 12) {
                        Text("\(i + 1)").font(.system(size: 22, weight: .black, design: .rounded)).foregroundStyle(i < 3 ? ST.am : ST.tx3).frame(width: 34)
                        Poster(url: DW.img(jstr(x, "poster")))
                        Text(DW.clean(jstr(x, "name"))).font(.cairo(14, .bold)).foregroundStyle(Color.white).lineLimit(2)
                        Spacer()
                        Label("\(jint(x, "plays"))", systemImage: "play.fill").font(.system(size: 13, weight: .bold)).foregroundStyle(ST.green)
                    }.padding(10).background(ST.s1, in: RoundedRectangle(cornerRadius: 14))
                }
            }.padding(14)
        }
        .background(STBackground())
        .navigationTitle("الأكثر مشاهدة").navigationBarTitleDisplayMode(.inline)
    }
}
