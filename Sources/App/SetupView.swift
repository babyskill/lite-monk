import SwiftUI
import LiteMonkCore

/// Native settings window for Minimal Zen Pet.
/// Focuses on pet appearance and Dhammapada quote data.
struct SetupView: View {
    @ObservedObject private var pet = PetController.shared
    @ObservedObject private var imagePets = ImagePetStore.shared
    @ObservedObject private var appLang = AppLanguage.shared
    @ObservedObject private var petWindow = PetWindowController.shared
    @ObservedObject private var dhammapada = DhammapadaStore.shared
    @ObservedObject private var bell = MindfulnessBellSettings.shared

    var onClose: () -> Void
    var onResize: (CGFloat) -> Void = { _ in }

    enum Tab { case pet, bell, content }
    @State private var tab: Tab = .pet

    @State private var browsing = false
    @State private var creating = false
    @State private var petQuery = ""

    private let windowWidth: CGFloat = 640
    private let preferredHeight: CGFloat = 680

    private var selectedPack: ImagePetPack? {
        pet.selectedPetID.flatMap { imagePets.pack(id: $0) }
    }

    private var filteredPacks: [ImagePetPack] {
        guard !petQuery.isEmpty else { return imagePets.packs }
        let q = petQuery.lowercased()
        return imagePets.packs.filter { $0.displayName.lowercased().contains(q) }
    }

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            Divider()
            Group {
                switch tab {
                case .pet:
                    PetTab(
                        pet: pet,
                        imagePets: imagePets,
                        petWindow: petWindow,
                        selectedPack: selectedPack,
                        filteredPacks: filteredPacks,
                        petQuery: $petQuery,
                        browsing: $browsing,
                        creating: $creating
                    )
                case .bell:
                    BellTab(pet: pet, bell: bell)
                case .content:
                    ContentTab(pet: pet, dhammapada: dhammapada)
                }
            }
            .frame(maxHeight: .infinity)
            Divider()
            bottomBar
        }
        .frame(width: windowWidth, height: preferredHeight)
        .preferredColorScheme(.dark)
        .environment(\.locale, appLang.locale)
        .id(appLang.lang.rawValue)
        .onAppear {
            onResize(windowWidth)
        }
        .sheet(isPresented: $browsing) {
            BrowsePetsView(onClose: { browsing = false })
        }
        .sheet(isPresented: $creating) {
            CreatePetView(
                onCreate: { id in
                    creating = false
                    imagePets.reload()
                    pet.selectedPetID = id
                },
                onCancel: { creating = false }
            )
        }
    }

    private var tabBar: some View {
        HStack(spacing: 8) {
            TabButton(icon: "pawprint.fill", label: "Character", selected: tab == .pet) {
                tab = .pet
            }
            TabButton(icon: "bell", label: "Chuông", selected: tab == .bell) {
                tab = .bell
            }
            TabButton(icon: "book", label: "Nội dung", selected: tab == .content) {
                tab = .content
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Toggle("Show menu bar character", isOn: Binding(
                get: { petWindow.isVisible },
                set: { petWindow.isVisible = $0 }
            ))
            .toggleStyle(.switch)
            Spacer()
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.bordered)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(.bar)
    }
}

private struct TabButton: View {
    let icon: String
    let label: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(label, systemImage: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(selected ? Color.systemAccent : Color.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(selected ? Color.systemAccent.opacity(0.18) : .clear))
        }
        .buttonStyle(.plain)
    }
}

private struct PetTab: View {
    @ObservedObject var pet: PetController
    @ObservedObject var imagePets: ImagePetStore
    @ObservedObject var petWindow: PetWindowController
    let selectedPack: ImagePetPack?
    let filteredPacks: [ImagePetPack]
    @Binding var petQuery: String
    @Binding var browsing: Bool
    @Binding var creating: Bool

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    petPreview
                        .frame(width: 84, height: 84)
                        .background(RoundedRectangle(cornerRadius: 12).fill(.quaternary))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(selectedPack?.displayName ?? "No pet selected")
                            .font(.title3.bold())
                        if let desc = selectedPack?.description {
                            Text(desc)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer()
                }
            }

            Section("Choose pet") {
                if imagePets.packs.isEmpty {
                    Text("No pets yet. Tap Browse to add one.")
                        .foregroundStyle(.secondary)
                } else {
                    if imagePets.packs.count > 4 {
                        NativeSearchField(text: $petQuery, placeholder: "Search pets")
                    }
                    PetPager(
                        packs: filteredPacks,
                        selectedID: pet.selectedPetID,
                        onSelect: { id in pet.selectedPetID = id },
                        onDelete: deleteSelection(for:)
                    )
                }
                HStack {
                    Button { browsing = true } label: {
                        Label("Browse", systemImage: "square.grid.2x2")
                    }
                    Button { creating = true } label: {
                        Label("Create", systemImage: "square.and.pencil")
                    }
                }
            }

            Section("Pet size") {
                HStack(spacing: 8) {
                    Slider(value: $pet.petPoint, in: PetController.minPoint...PetController.maxPoint)
                    Text("\(Int(pet.petPoint))")
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(.secondary)
                    ForEach(PetController.presets, id: \.0) { preset in
                        Button(preset.0) { pet.animateSize(to: preset.1) }
                            .buttonStyle(.bordered)
                    }
                }
            }

            Section("Font size") {
                HStack(spacing: 8) {
                    Slider(value: $pet.fontSize, in: PetController.minFontSize...PetController.maxFontSize)
                    Text("\(Int(pet.fontSize))")
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(.secondary)
                    ForEach(PetController.fontPresets, id: \.0) { preset in
                        Button(preset.0) { pet.fontSize = preset.1 }
                            .buttonStyle(.bordered)
                    }
                }
            }

            Section(
                header: Text("Behavior"),
                footer: pet.hasVoice ? nil : Text("Ngôn ngữ hiện tại không hỗ trợ giọng đọc")
            ) {
                Toggle("Keep pet on top", isOn: $petWindow.alwaysOnTop)
                Toggle("Show quote on pet", isOn: $pet.showQuote)
                Toggle("Show quote while idle", isOn: $pet.showIdleMessage)
                    .disabled(!pet.showQuote)
                Toggle("Phát âm thanh khi đổi câu", isOn: $pet.playVoiceEnabled)
                    .disabled(!pet.hasVoice)
                if pet.playVoiceEnabled && pet.hasVoice {
                    Picker("Âm thanh dẫn đầu", selection: $pet.introSoundRaw) {
                        ForEach(VerseIntroSound.allCases) { sound in
                            Text(sound.label).tag(sound.rawValue)
                        }
                    }
                }
                Toggle("Show reaction message on tap", isOn: $pet.showTapMessage)
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder private var petPreview: some View {
        if let pack = selectedPack {
            ImageSpriteView(frames: pack.clip(0), mood: .idle, size: 78)
        } else {
            Image(systemName: "pawprint.fill")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
        }
    }

    private func deleteSelection(for pack: ImagePetPack) {
        let wasSelected = pet.selectedPetID == pack.id
        imagePets.delete(pack)
        if wasSelected { pet.selectedPetID = imagePets.packs.first?.id }
    }

}

private struct PetPager: View {
    let packs: [ImagePetPack]
    let selectedID: String?
    let onSelect: (String) -> Void
    let onDelete: (ImagePetPack) -> Void

    @State private var page = 0
    private let perPage = 8

    var body: some View {
        let pageCount = max(1, Int(ceil(Double(packs.count) / Double(perPage))))
        let current = min(page, pageCount - 1)

        VStack(spacing: 10) {
            GeometryReader { geo in
                HStack(alignment: .top, spacing: 0) {
                    ForEach(0..<pageCount, id: \.self) { p in
                        grid(for: p).frame(width: geo.size.width, alignment: .top)
                    }
                }
                .offset(x: -CGFloat(current) * geo.size.width)
                .animation(.easeInOut(duration: 0.28), value: current)
            }
            .frame(height: 188)
            .clipped()

            if pageCount > 1 {
                HStack(spacing: 14) {
                    arrow("chevron.left", enabled: current > 0) { page = max(0, current - 1) }
                    HStack(spacing: 5) {
                        ForEach(0..<pageCount, id: \.self) { i in
                            Circle().fill(i == current ? Color.systemAccent : .secondary.opacity(0.4))
                                .frame(width: 6, height: 6)
                        }
                    }
                    arrow("chevron.right", enabled: current < pageCount - 1) {
                        page = min(pageCount - 1, current + 1)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .onChange(of: packs.count) { _ in page = 0 }
    }

    private func grid(for pageIndex: Int) -> some View {
        let slice = Array(packs.dropFirst(pageIndex * perPage).prefix(perPage))
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), alignment: .leading, spacing: 12) {
            ForEach(slice) { pack in
                PetThumb(
                    pack: pack,
                    selected: selectedID == pack.id,
                    onSelect: { onSelect(pack.id) },
                    onDelete: { onDelete(pack) }
                )
            }
        }
    }

    private func arrow(_ icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).frame(width: 30, height: 30)
        }
        .buttonStyle(.plain)
        .foregroundStyle(enabled ? Color.secondary : Color.secondary.opacity(0.3))
        .disabled(!enabled)
    }
}

private struct PetThumb: View {
    let pack: ImagePetPack
    let selected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 4) {
                StaticFrame(image: pack.clip(0).first, size: 48)
                    .frame(width: 56, height: 48)
                Text(pack.displayName)
                    .font(.caption)
                    .lineLimit(1)
                    .frame(width: 64)
            }
            .padding(6)
            .background(RoundedRectangle(cornerRadius: 10).fill(selected ? Color.systemAccent.opacity(0.2) : .clear))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(selected ? Color.systemAccent : .secondary.opacity(0.3), lineWidth: selected ? 2 : 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .topTrailing) {
            if hovering {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(.white, .black.opacity(0.55))
                }
                .buttonStyle(.plain)
                .offset(x: 4, y: -4)
            }
        }
        .onHover { hovering = $0 }
    }
}

private struct StaticFrame: View {
    let image: NSImage?
    var size: CGFloat

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image).resizable().interpolation(.high).scaledToFit()
            } else {
                Image(systemName: "pawprint.fill").foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
    }
}

private struct BellTab: View {
    @ObservedObject var pet: PetController
    @ObservedObject var bell: MindfulnessBellSettings

    var body: some View {
        Form {
            Section("Quote flow") {
                Toggle("Show quote on pet", isOn: $pet.showQuote)
                Toggle("Show quote while idle", isOn: $pet.showIdleMessage)
                    .disabled(!pet.showQuote)
            }

            Section("Chuông chánh niệm") {
                Toggle("Mindfulness bell", isOn: $bell.enabled)

                HStack {
                    Slider(value: $bell.intervalMinutes, in: 1...180, step: 1)
                        .disabled(!bell.enabled)
                    Text("\(Int(bell.intervalMinutes)) phút")
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 76, alignment: .trailing)
                }

                Toggle("Sync message with bell", isOn: $bell.syncMessage)
                    .disabled(!bell.enabled)
                Toggle("Bell sound", isOn: $bell.soundEnabled)
                    .disabled(!bell.enabled)

                Picker("Sound", selection: $bell.defaultSoundRaw) {
                    ForEach(MindfulnessBellSettings.DefaultSound.allCases) { sound in
                        Text(sound.label).tag(sound.rawValue)
                    }
                }
                .disabled(!bell.enabled || !bell.soundEnabled)

                HStack {
                    Button("Preview") { bell.playPreview() }
                        .disabled(!bell.soundEnabled)
                    Button("Choose file") { bell.upload() }
                    Button("Reset") { bell.resetToDefault() }
                        .disabled(bell.customPath.isEmpty)
                    Spacer()
                    Text(bell.sourceLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .disabled(!bell.enabled)

                HStack {
                    Text("Volume")
                    Slider(value: $bell.volume, in: 0...1)
                    Text("\(Int(bell.volume * 100))%")
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 48, alignment: .trailing)
                }
                .disabled(!bell.enabled || !bell.soundEnabled)

                Stepper("Repeat \(bell.repeatCount)x", value: $bell.repeatCount, in: 1...10)
                    .disabled(!bell.enabled || !bell.soundEnabled)

                Toggle("Quiet hours", isOn: $bell.quietHoursEnabled)
                    .disabled(!bell.enabled)
                if bell.quietHoursEnabled {
                    DatePicker("Start", selection: $bell.allowedStartDate, displayedComponents: .hourAndMinute)
                    DatePicker("End", selection: $bell.allowedEndDate, displayedComponents: .hourAndMinute)
                    Text(bell.quietHoursSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }
}

private struct ContentTab: View {
    @ObservedObject var pet: PetController
    @ObservedObject var dhammapada: DhammapadaStore

    @State private var query = ""
    @State private var editingMode: VerseEditMode?
    
    // GitHub zip update states
    @State private var updateUrl = "https://github.com/babyskill/dhammapada-data/archive/refs/heads/main.zip"
    @State private var isUpdating = false
    @State private var updateError: String? = nil
    @State private var updateSuccess = false

    private enum VerseEditMode: Identifiable {
        case add
        case edit(DhammapadaVerse)

        var id: String {
            switch self {
            case .add: "add"
            case .edit(let verse): verse.id
            }
        }

        var verse: DhammapadaVerse {
            switch self {
            case .add:
                return .blank
            case .edit(let verse):
                return verse
            }
        }

        var title: String {
            switch self {
            case .add:
                return "Thêm câu"
            case .edit:
                return "Sửa câu"
            }
        }
    }

    private var matchingVerses: [DhammapadaVerse] {
        let filtered = dhammapada.sorted(query)
        return filtered.sorted {
            if $0.chapterNumber != $1.chapterNumber { return $0.chapterNumber < $1.chapterNumber }
            if $0.verseNumber != $1.verseNumber { return $0.verseNumber < $1.verseNumber }
            return $0.chapterTitle.localizedCaseInsensitiveCompare($1.chapterTitle) == .orderedAscending
        }
    }

    var body: some View {
        Form {
            Section("Cập nhật dữ liệu từ GitHub") {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("GitHub ZIP URL", text: $updateUrl)
                        .textFieldStyle(.roundedBorder)
                        .disabled(isUpdating)
                    
                    HStack(spacing: 12) {
                        Button(action: triggerGitHubUpdate) {
                            if isUpdating {
                                HStack(spacing: 6) {
                                    ProgressView().controlSize(.small)
                                    Text("Đang cập nhật...")
                                }
                            } else {
                                Text("Cập nhật ngay")
                             }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isUpdating || updateUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        
                        if updateSuccess {
                            Label("Thành công!", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.callout)
                        }
                        
                        if let err = updateError {
                            Label(err, systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                                .font(.callout)
                                .lineLimit(2)
                        }
                    }
                }
            }

            Section("Thêm / Sửa kinh") {
                HStack {
                    NativeSearchField(text: $query, placeholder: "Tìm kiếm phẩm/câu")
                    Button("Thêm câu") {
                        editingMode = .add
                    }
                    .buttonStyle(.borderedProminent)
                }

                if matchingVerses.isEmpty {
                    Text("Không có câu phù hợp.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                } else {
                    ForEach(matchingVerses) { verse in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .firstTextBaseline) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Phẩm \(verse.chapterNumber) • Câu \(verse.verseNumber)")
                                        .font(.caption.weight(.medium))
                                    Text(verse.chapterTitle)
                                        .font(.callout.weight(.medium))
                                }
                                Spacer()
                                Button("Edit") {
                                    editingMode = .edit(verse)
                                }
                                .buttonStyle(.bordered)
                                Button("Xóa") {
                                    dhammapada.remove(id: verse.id)
                                }
                                .buttonStyle(.bordered)
                                .tint(.red)
                            }

                            Text(verse.text)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)

                            Divider()
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Section("Current quote") {
                Text(IdleBoost.dhammapadaLine())
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
            }
        }
        .formStyle(.grouped)
        .sheet(item: $editingMode) { mode in
            DhammapadaVerseEditor(
                title: mode.title,
                verse: mode.verse,
                onSave: { verse in
                    dhammapada.upsert(verse)
                    editingMode = nil
                }
            ) {
                editingMode = nil
            }
        }
    }
    
    private func triggerGitHubUpdate() {
        guard let url = URL(string: updateUrl.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            updateError = "URL không hợp lệ"
            return
        }
        isUpdating = true
        updateError = nil
        updateSuccess = false
        
        Task {
            do {
                try await dhammapada.updateFromGitHub(zipURL: url)
                isUpdating = false
                updateSuccess = true
            } catch {
                isUpdating = false
                updateError = error.localizedDescription
            }
        }
    }
}

private struct DhammapadaVerseEditor: View {
    let title: String
    let verse: DhammapadaVerse
    let onSave: (DhammapadaVerse) -> Void
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var chapterTitle: String
    @State private var chapterNumber: String
    @State private var verseNumber: String
    @State private var text: String
    @State private var translator: String
    @State private var source: String

    init(
        title: String,
        verse: DhammapadaVerse,
        onSave: @escaping (DhammapadaVerse) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.title = title
        self.verse = verse
        self.onSave = onSave
        self.onCancel = onCancel
        _chapterTitle = State(initialValue: verse.chapterTitle)
        _chapterNumber = State(initialValue: String(verse.chapterNumber))
        _verseNumber = State(initialValue: String(verse.verseNumber))
        _text = State(initialValue: verse.text)
        _translator = State(initialValue: verse.translator)
        _source = State(initialValue: verse.source)
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(title).font(.headline)
                Spacer()
            }

            Form {
                Section("Thông tin") {
                    TextField("Tên phẩm", text: $chapterTitle)
                    TextField("Số phẩm", text: $chapterNumber)
                    TextField("Số câu", text: $verseNumber)
                    TextField("Người dịch", text: $translator)
                    TextField("Nguồn tài liệu", text: $source)
                }

                Section("Nội dung") {
                    TextEditor(text: $text)
                        .frame(minHeight: 150)
                        .font(.system(size: 12))
                }
            }

            HStack {
                Button("Huỷ") {
                    onCancel()
                    dismiss()
                }
                Spacer()
                Button("Lưu") {
                    onSave(sanitizedVerse)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(chapterTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .padding()
        .frame(width: 520, height: 450)
        .onAppear {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private var sanitizedVerse: DhammapadaVerse {
        let chapter = Int(chapterNumber.trimmingCharacters(in: .whitespacesAndNewlines)) ?? verse.chapterNumber
        let line = Int(verseNumber.trimmingCharacters(in: .whitespacesAndNewlines)) ?? verse.verseNumber
        
        // Save using current active language key
        let langCode = AppLanguage.shared.lang.rawValue
        let code: String
        if langCode == "system" {
            code = Locale.current.language.languageCode?.identifier ?? "en"
        } else {
            code = langCode
        }
        
        var updatedTranslations = verse.translations
        updatedTranslations[code] = DhammapadaVerse.Translation(
            chapterTitle: chapterTitle,
            text: text,
            translator: translator,
            source: source
        )
        
        return DhammapadaVerse(
            id: verse.id,
            chapterNumber: max(1, chapter),
            verseNumber: max(1, line),
            translations: updatedTranslations
        )
    }
}
