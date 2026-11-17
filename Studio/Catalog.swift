import SwiftUI

/// «كلّ المزوّدين» — تصفّح مكتبة كلّ مزوّد (الرئيسيّة/أ/ب/التجريبيّة) بأقسامها وبحث بكلّها،
/// وكلّ عمل تگدر تضيفه لأيّ صفّ بالرئيسيّة أو أيّ قسم (يطلع أوّل الصفّ). السيرفر: /api/admin/apanel/*
struct CatItem: Identifiable, Hashable {
    let id: String; let name: String; let clean: String; let poster: String; let ext: String; let kind: String
    let year: Int; let rating: Double; let catName: String; let inLib: Bool; let onSite: Bool
    init(_ o: J) {
        id = jstr(o, "id"); name = jstr(o, "name"); let c = jstr(o, "clean"); clean = c.isEmpty ? DW.clean(jstr(o, "name")) : c
        poster = jstr(o, "poster"); ext = jstr(o, "ext"); kind = jstr(o, "kind"); year = jint(o, "year"); rating = jdbl(o, "rating")
        catName = jstr(o, "catName"); inLib = jbool(o, "inLib"); onSite = jbool(o, "onSite")
    }
    var body: J { ["id": id, "name": name, "poster": poster, "ext": ext.isEmpty ? "mp4" : ext, "kind": kind] }
}
struct CatProv: Hashable { let key: String; let name: String; let lab: Bool }
struct CatTarget: Identifiable, Hashable { let id: String; let label: String; let group: String }
struct CatCategory: Identifiable, Hashable { let id: String; let name: String; let n: Int; let fresh: Int }

@MainActor
final class CatalogModel: ObservableObject {
    @Published var panels: [CatProv] = []
    @Published var panel = "main" { didSet { if oldValue != panel { cat = ""; reloadAll() } } }
    @Published var kind = "movies" { didSet { if oldValue != kind { cat = ""; reloadAll() } } }
    @Published var lang = "tr" { didSet { if oldValue != lang { reloadAll() } } }
    @Published var sort = "new" { didSet { if oldValue != sort { reload() } } }
    @Published var onlyNew = false { didSet { if oldValue != onlyNew { reload() } } }
    @Published var cat = ""
    @Published var q = ""
    @Published var cats: [CatCategory] = []
    @Published var catsTotal = 0
    @Published var items: [CatItem] = []
    @Published var total = 0
    @Published var page = 1
    @Published var pages = 1
    @Published var loading = false
    @Published var err = ""
    @Published var targets: [CatTarget] = []
    @Published var pins: [String: [J]] = [:]
    private var gen = 0

    func boot() async {
        if let r = try? await DW.get("/api/admin/apanel/panels") {
            panels = jarr(r, "panels").map { CatProv(key: jstr($0, "key"), name: jstr($0, "name"), lab: jbool($0, "lab")) }
        }
        if panels.isEmpty { panels = [CatProv(key: "main", name: "المكتبة الرئيسية", lab: false), CatProv(key: "a", name: "مكتبة أ", lab: false), CatProv(key: "b", name: "مكتبة ب", lab: false)] }
        await loadTargets()
        reloadAll()
    }
    func loadTargets() async {
        if let t = try? await DW.get("/api/admin/apanel/targets") {
            targets = jarr(t, "rows").map { CatTarget(id: jstr($0, "key"), label: jstr($0, "label"), group: "صفوف الرئيسيّة") }
                + jarr(t, "cats").map { CatTarget(id: jstr($0, "key"), label: jstr($0, "label"), group: "الأقسام") }
        }
        await loadPins()
    }
    func loadPins() async {
        if let p = try? await DW.get("/api/admin/apanel/pins") {
            var out: [String: [J]] = [:]
            for (k, v) in jobj(p, "pins") { out[k] = (v as? [J]) ?? [] }
            pins = out
        }
    }
    func pinned(_ it: CatItem) -> [String] { pins.filter { $0.value.contains { jstr($0, "id") == it.id } }.map(\.key) }
    func label(_ key: String) -> String { targets.first { $0.id == key }?.label ?? key.replacingOccurrences(of: "row:", with: "").replacingOccurrences(of: "cat:", with: "") }

    func reloadAll() { Task { await loadCats(); reload() } }
    func loadCats() async {
        let g = gen
        guard let r = try? await DW.get("/api/admin/apanel/cats?kind=\(kind)&panel=\(panel)&lang=\(lang)") else { return }
        guard g == gen else { return }
        cats = jarr(r, "cats").map { CatCategory(id: jstr($0, "id"), name: jstr($0, "name"), n: jint($0, "n"), fresh: jint($0, "fresh")) }
        catsTotal = jint(r, "total")
    }
    func reload() { page = 1; items = []; Task { await fetch() } }
    func more() { guard !loading, page < pages else { return }; page += 1; Task { await fetch() } }
    func fetch() async {
        gen += 1; let g = gen
        loading = true; err = ""
        var path = "/api/admin/apanel/list?kind=\(kind)&panel=\(panel)&lang=\(lang)&sort=\(sort)&page=\(page)"
        if !cat.isEmpty { path += "&cat=" + DW.enc(cat) }
        let qq = q.trimmingCharacters(in: .whitespaces)
        if !qq.isEmpty { path += "&q=" + DW.enc(qq) }
        if onlyNew { path += "&only=new" }
        do {
            let r = try await DW.get(path)
            guard g == gen else { return }
            let e = jstr(r, "err")
            if !e.isEmpty { err = e == "guard" ? "مزوّد أ موقوف حاليًّا بالحارس" : "المزوّد ما ردّ: " + e }
            let new = jarr(r, "items").map(CatItem.init)
            items = page == 1 ? new : items + new
            total = jint(r, "total"); pages = max(1, jint(r, "pages"))
        } catch {
            if g == gen { err = "ما وصلنا للسيرفر" }
        }
        if g == gen { loading = false }
    }
    func pin(_ it: CatItem, to t: String) async -> Bool {
        guard (try? await DW.post("/api/admin/apanel/pin", ["target": t, "item": it.body])) != nil else { return false }
        await loadPins(); return true
    }
    func unpin(_ id: String, from t: String) async {
        _ = try? await DW.post("/api/admin/apanel/unpin", ["target": t, "id": id])
        await loadPins()
    }
}

struct CatalogView: View {
    @StateObject private var m = CatalogModel()
    @State private var pick: CatItem?
    @State private var showCats = false
    @State private var showPins = false
    @State private var toast = ""
    private let cols = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12, pinnedViews: []) {
                controls
                if !m.err.isEmpty {
                    Text(m.err).font(.cairo(13, .semibold)).foregroundStyle(ST.red).padding(.horizontal, 16)
                }
                HStack {
                    Text(m.loading && m.items.isEmpty ? "جارِ التحميل…" : "\(m.total) عمل").font(.cairo(13, .semibold)).foregroundStyle(ST.tx2)
                    Spacer()
                    if m.loading && m.items.isEmpty { ProgressView().tint(ST.am) }
                }
                .padding(.horizontal, 16)
                LazyVGrid(columns: cols, spacing: 14) {
                    ForEach(m.items) { it in
                        Button { pick = it } label: { CatCard(it: it, pinnedN: m.pinned(it).count) }
                            .buttonStyle(.plain)
                            .onAppear { if it.id == m.items.last?.id { m.more() } }
                    }
                }
                .padding(.horizontal, 16)
                if m.loading && !m.items.isEmpty { ProgressView().tint(ST.am).frame(maxWidth: .infinity).padding() }
                if !m.loading && m.items.isEmpty && m.err.isEmpty {
                    Text("ماكو نتائج").font(.cairo(14)).foregroundStyle(ST.tx3).frame(maxWidth: .infinity).padding(.top, 40)
                }
            }
            .padding(.bottom, 30)
        }
        .scrollDismissesKeyboard(.immediately)
        .background(STBackground())
        .navigationTitle("كلّ المزوّدين")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showPins = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "pin.fill")
                        Text("\(m.pins.values.reduce(0) { $0 + $1.count })").font(.system(size: 13, weight: .bold))
                    }.foregroundStyle(ST.am)
                }
            }
        }
        .overlay(alignment: .bottom) {
            if !toast.isEmpty {
                Text(toast).font(.cairo(13.5, .bold)).foregroundStyle(ST.onAm).multilineTextAlignment(.center)
                    .padding(.horizontal, 16).padding(.vertical, 11).background(ST.am, in: Capsule())
                    .shadow(color: .black.opacity(0.4), radius: 12, y: 6).padding(.bottom, 24).padding(.horizontal, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sheet(item: $pick) { it in
            PinSheet(m: m, it: it) { msg in show(msg) }
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showCats) { CatPickSheet(m: m).presentationDetents([.large]) }
        .sheet(isPresented: $showPins) { PinsSheet(m: m).presentationDetents([.large]) }
        .task { if m.panels.isEmpty { await m.boot() } }
    }

    private func show(_ msg: String) {
        withAnimation(.spring(response: 0.35)) { toast = msg }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) { withAnimation { toast = "" } }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            // المزوّد
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(m.panels, id: \.key) { p in
                        Chip(text: p.name + (p.lab ? " · تجريبيّ" : ""), on: m.panel == p.key, icon: p.key == "main" ? "star.fill" : "server.rack") { m.panel = p.key }
                    }
                }.padding(.horizontal, 16)
            }
            // النوع + اللغة
            HStack(spacing: 8) {
                Chip(text: "أفلام", on: m.kind == "movies", icon: "film") { m.kind = "movies" }
                Chip(text: "مسلسلات", on: m.kind == "series", icon: "tv") { m.kind = "series" }
                Spacer(minLength: 0)
                Menu {
                    Picker("اللغة", selection: $m.lang) {
                        Text("عربي + إنكليزي").tag("tr"); Text("عربي بس").tag("ar"); Text("إنكليزي بس").tag("en"); Text("كلّ اللغات").tag("all")
                    }
                } label: { MenuLabel(icon: "character.bubble", text: ["tr": "عربي+إنكليزي", "ar": "عربي", "en": "إنكليزي", "all": "كلّ اللغات"][m.lang] ?? "") }
            }
            .padding(.horizontal, 16)
            // البحث
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(ST.tx3)
                TextField("", text: $m.q, prompt: Text("دوّر بكلّ المزوّد…").foregroundColor(ST.tx3))
                    .font(.cairo(15)).foregroundStyle(ST.tx).submitLabel(.search).onSubmit { m.reload() }
                    .autocorrectionDisabled().textInputAutocapitalization(.never)
                if !m.q.isEmpty { Button { m.q = ""; m.reload() } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(ST.tx3) } }
            }
            .padding(.horizontal, 12).frame(height: 44)
            .background(ST.s1, in: RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(ST.line))
            .padding(.horizontal, 16)
            // القسم + الترتيب + الجديد بس
            HStack(spacing: 8) {
                Button { showCats = true } label: {
                    MenuLabel(icon: "square.grid.2x2", text: m.cat.isEmpty ? "كلّ الأقسام (\(m.cats.count))" : (m.cats.first { $0.id == m.cat }?.name ?? "قسم"))
                }.buttonStyle(.plain)
                Menu {
                    Picker("الترتيب", selection: $m.sort) {
                        Text("الأحدث").tag("new"); Text("الأعلى تقييمًا").tag("rating"); Text("السنة").tag("year"); Text("الاسم").tag("name")
                    }
                } label: { MenuLabel(icon: "arrow.up.arrow.down", text: ["new": "الأحدث", "rating": "التقييم", "year": "السنة", "name": "الاسم"][m.sort] ?? "") }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            Toggle(isOn: $m.onlyNew) {
                Text("بس اللي مو موجود عدنا").font(.cairo(13.5, .semibold)).foregroundStyle(ST.tx2)
            }
            .tint(ST.am).padding(.horizontal, 16)
        }
        .padding(.top, 8)
    }
}

struct Chip: View {
    let text: String; let on: Bool; var icon = ""; let tap: () -> Void
    var body: some View {
        Button(action: { UIImpactFeedbackGenerator(style: .light).impactOccurred(); tap() }) {
            HStack(spacing: 5) {
                if !icon.isEmpty { Image(systemName: icon).font(.system(size: 11, weight: .bold)) }
                Text(text).font(.cairo(13, .bold)).lineLimit(1)
            }
            .foregroundStyle(on ? ST.onAm : ST.tx2)
            .padding(.horizontal, 13).frame(height: 34)
            .background(on ? AnyShapeStyle(ST.am) : AnyShapeStyle(ST.s1), in: Capsule())
            .overlay(Capsule().stroke(on ? Color.clear : ST.line))
        }.buttonStyle(.plain)
    }
}

struct MenuLabel: View {
    let icon: String; let text: String
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 11, weight: .bold))
            Text(text).font(.cairo(12.5, .semibold)).lineLimit(1)
            Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold))
        }
        .foregroundStyle(ST.tx)
        .padding(.horizontal, 11).frame(height: 32)
        .background(ST.s2, in: Capsule())
    }
}

struct CatCard: View {
    let it: CatItem; var pinnedN = 0
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Color.clear.aspectRatio(2 / 3, contentMode: .fit)
                .overlay(
                    AsyncImage(url: DW.img(it.poster)) { ph in
                        if case .success(let i) = ph { i.resizable().aspectRatio(contentMode: .fill) }
                        else { ZStack { ST.s2; Text(it.clean).font(.cairo(11)).foregroundStyle(ST.tx3).multilineTextAlignment(.center).padding(6) } }
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(pinnedN > 0 ? ST.am : Color(white: 1, opacity: 0.08), lineWidth: pinnedN > 0 ? 2 : 1))
                .overlay(alignment: .topLeading) {
                    Text(it.onSite ? "عدنا" : (it.inLib ? "بمكتبة ثانية" : "جديد"))
                        .font(.cairo(10, .bold)).foregroundStyle(it.onSite || it.inLib ? ST.tx : ST.onAm)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(it.onSite ? ST.green.opacity(0.85) : (it.inLib ? Color.black.opacity(0.6) : ST.am), in: RoundedRectangle(cornerRadius: 6))
                        .padding(5)
                }
                .overlay(alignment: .topTrailing) {
                    if pinnedN > 0 {
                        Image(systemName: "pin.fill").font(.system(size: 10, weight: .bold)).foregroundStyle(ST.onAm)
                            .frame(width: 22, height: 22).background(ST.am, in: Circle()).padding(5)
                    }
                }
            Text(it.clean).font(.cairo(12, .semibold)).foregroundStyle(ST.tx).lineLimit(1)
            HStack(spacing: 4) {
                if it.year > 0 { Text(String(it.year)) }
                if it.rating > 0 { Text("★ " + String(format: "%.1f", it.rating)) }
            }
            .font(.system(size: 10.5, weight: .medium)).foregroundStyle(ST.tx3).lineLimit(1)
        }
    }
}

/// «أضف إلى…»: كلّ الصفوف والأقسام، والمثبّت عليه علامة (تگدر تشيله)
struct PinSheet: View {
    @ObservedObject var m: CatalogModel
    let it: CatItem
    let done: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var q = ""
    @State private var busy = ""
    var body: some View {
        let on = Set(m.pinned(it))
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 12) {
                        Poster(url: DW.img(it.poster), w: 54)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(it.clean).font(.cairo(16, .bold)).foregroundStyle(ST.tx).lineLimit(2)
                            Text([it.kind == "series" ? "مسلسل" : "فيلم", it.year > 0 ? String(it.year) : "", it.catName].filter { !$0.isEmpty }.joined(separator: " · "))
                                .font(.cairo(12)).foregroundStyle(ST.tx3).lineLimit(2)
                            Text(it.name).font(.system(size: 10.5)).foregroundStyle(ST.tx3).lineLimit(1)
                        }
                    }
                    .listRowBackground(ST.s1)
                } footer: {
                    Text("اختار صفّ أو قسم — العمل يطلع أوّل شي بيه بالموقع والتطبيقات.").font(.cairo(12)).foregroundStyle(ST.tx3)
                }
                ForEach(["صفوف الرئيسيّة", "الأقسام"], id: \.self) { g in
                    let L = m.targets.filter { $0.group == g && (q.isEmpty || $0.label.localizedCaseInsensitiveContains(q)) }
                    if !L.isEmpty {
                        Section(g) {
                            ForEach(L) { t in
                                Button { toggle(t, on: on.contains(t.id)) } label: {
                                    HStack {
                                        Image(systemName: on.contains(t.id) ? "checkmark.circle.fill" : "plus.circle")
                                            .foregroundStyle(on.contains(t.id) ? ST.green : ST.am).font(.system(size: 18))
                                        Text(t.label).font(.cairo(14.5, .semibold)).foregroundStyle(ST.tx).lineLimit(2)
                                        Spacer()
                                        if busy == t.id { ProgressView().tint(ST.am) }
                                        else if on.contains(t.id) { Text("مضاف").font(.cairo(11.5, .bold)).foregroundStyle(ST.green) }
                                    }
                                }
                                .listRowBackground(ST.s1)
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(ST.bg)
            .searchable(text: $q, prompt: "دوّر على صفّ أو قسم")
            .navigationTitle("أضف إلى…")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("سدّ") { dismiss() }.foregroundStyle(ST.am) } }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .preferredColorScheme(.dark)
    }
    private func toggle(_ t: CatTarget, on: Bool) {
        busy = t.id
        Task {
            if on {
                await m.unpin(it.id, from: t.id)
                busy = ""; done("انشال من «\(t.label)»")
            } else {
                let ok = await m.pin(it, to: t.id)
                busy = ""
                UINotificationFeedbackGenerator().notificationOccurred(ok ? .success : .error)
                done(ok ? "✓ انضاف لـ«\(t.label)»" : "ما انضاف — جرّب مرّة ثانية")
                if ok { dismiss() }
            }
        }
    }
}

/// اختيار القسم من أقسام المزوّد
struct CatPickSheet: View {
    @ObservedObject var m: CatalogModel
    @Environment(\.dismiss) private var dismiss
    @State private var q = ""
    var body: some View {
        NavigationStack {
            List {
                Button { m.cat = ""; m.reload(); dismiss() } label: {
                    row("كلّ الأقسام", m.catsTotal, 0, m.cat.isEmpty)
                }.listRowBackground(ST.s1)
                ForEach(m.cats.filter { q.isEmpty || $0.name.localizedCaseInsensitiveContains(q) }) { c in
                    Button { m.cat = c.id; m.reload(); dismiss() } label: { row(c.name, c.n, c.fresh, m.cat == c.id) }
                        .listRowBackground(ST.s1)
                }
            }
            .scrollContentBackground(.hidden)
            .background(ST.bg)
            .searchable(text: $q, prompt: "دوّر على قسم")
            .navigationTitle("الأقسام")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("سدّ") { dismiss() }.foregroundStyle(ST.am) } }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .preferredColorScheme(.dark)
    }
    private func row(_ name: String, _ n: Int, _ fresh: Int, _ on: Bool) -> some View {
        HStack {
            Image(systemName: on ? "checkmark.circle.fill" : "circle").foregroundStyle(on ? ST.am : ST.tx3)
            Text(name).font(.cairo(14.5, .semibold)).foregroundStyle(ST.tx).lineLimit(2)
            Spacer()
            if fresh > 0 { Pill(text: "\(fresh) جديد", tint: ST.am) }
            Text("\(n)").font(.system(size: 12.5, weight: .semibold)).foregroundStyle(ST.tx3)
        }
    }
}

/// كلّ المثبّت حاليًّا، مجمّع بالصفّ، مع الإزالة
struct PinsSheet: View {
    @ObservedObject var m: CatalogModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                if m.pins.isEmpty {
                    Text("ما مثبّت شي بعد. اختار أيّ عمل واضغط عليه حتى تضيفه لصفّ.").font(.cairo(14)).foregroundStyle(ST.tx3).listRowBackground(ST.s1)
                }
                ForEach(m.pins.keys.sorted(), id: \.self) { k in
                    Section(m.label(k)) {
                        ForEach(Array((m.pins[k] ?? []).enumerated()), id: \.offset) { _, p in
                            HStack(spacing: 10) {
                                Poster(url: DW.img(jstr(p, "poster")), w: 38)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(DW.clean(jstr(p, "name"))).font(.cairo(14, .semibold)).foregroundStyle(ST.tx).lineLimit(2)
                                    Text(provName(jstr(p, "id")) + " · " + ago(jdbl(p, "at"))).font(.cairo(11.5)).foregroundStyle(ST.tx3)
                                }
                                Spacer()
                                Button(role: .destructive) { Task { await m.unpin(jstr(p, "id"), from: k) } } label: {
                                    Image(systemName: "trash").foregroundStyle(ST.red).frame(width: 36, height: 36)
                                }.buttonStyle(.plain)
                            }
                            .listRowBackground(ST.s1)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(ST.bg)
            .refreshable { await m.loadPins() }
            .navigationTitle("المثبّت بالصفوف")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("سدّ") { dismiss() }.foregroundStyle(ST.am) } }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .preferredColorScheme(.dark)
        .task { await m.loadPins() }
    }
    private func provName(_ id: String) -> String {
        guard let i = id.firstIndex(of: "~") else { return "الرئيسيّة" }
        let k = String(id[..<i])
        return m.panels.first { $0.key == k }?.name ?? k
    }
}
