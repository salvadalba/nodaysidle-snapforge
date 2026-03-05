import SwiftUI

// MARK: - SmartFilter

private enum SmartFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case today = "Today"
    case thisWeek = "This Week"
    case starred = "Starred"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .all:      return "photo.on.rectangle.angled"
        case .today:    return "calendar"
        case .thisWeek: return "calendar.badge.clock"
        case .starred:  return "star.fill"
        }
    }
}

// MARK: - LibraryBrowserViewModel

@Observable
@MainActor
private final class LibraryBrowserViewModel {

    // MARK: State

    var searchText: String = ""
    var selectedCaptureTypes: Set<CaptureType> = []
    var selectedSmartFilter: SmartFilter = .all
    var selectedCapture: CaptureRecordSnapshot?
    var captures: [CaptureRecordSnapshot] = []
    var allTags: [TagUsage] = []
    var selectedTags: Set<String> = []
    var isLoading: Bool = false
    var errorMessage: String?

    // MARK: Derived

    var filteredCaptures: [CaptureRecordSnapshot] {
        var result = captures

        if !selectedCaptureTypes.isEmpty {
            result = result.filter { selectedCaptureTypes.map(\.rawValue).contains($0.captureType) }
        }

        if !selectedTags.isEmpty {
            result = result.filter { snap in
                let snapTags = Set(snap.tagArray)
                return selectedTags.isSubset(of: snapTags)
            }
        }

        switch selectedSmartFilter {
        case .all:
            break
        case .today:
            let cal = Calendar.current
            result = result.filter { cal.isDateInToday($0.createdAt) }
        case .thisWeek:
            let cal = Calendar.current
            let start = cal.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
            result = result.filter { $0.createdAt >= start }
        case .starred:
            result = result.filter(\.isStarred)
        }

        return result
    }

    var captureTypeCounts: [CaptureType: Int] {
        var counts: [CaptureType: Int] = [:]
        for capture in captures {
            if let type = CaptureType(rawValue: capture.captureType) {
                counts[type, default: 0] += 1
            }
        }
        return counts
    }

    // MARK: - Load

    func load(libraryService: any LibraryServiceProtocol) async {
        isLoading = true
        errorMessage = nil
        do {
            if searchText.isEmpty {
                let results = try await libraryService.fetchAll(
                    filters: LibraryFilters(),
                    sort: .timestampDesc,
                    limit: 500,
                    offset: 0
                )
                captures = results.records
            } else {
                let results = try await libraryService.search(
                    query: searchText,
                    filters: LibraryFilters(),
                    sort: .relevance,
                    limit: 200,
                    offset: 0
                )
                captures = results.records
            }
            allTags = try await libraryService.allTags()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func delete(id: UUID, libraryService: any LibraryServiceProtocol) async {
        do {
            try await libraryService.delete(id: id, deleteFile: true)
            captures.removeAll { $0.id == id }
            if selectedCapture?.id == id { selectedCapture = nil }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - LibraryBrowserView

struct LibraryBrowserView: View {

    @Environment(AppServices.self) private var appServices
    @State private var vm = LibraryBrowserViewModel()

    private let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 220), spacing: 12)
    ]

    var body: some View {
        NavigationSplitView {
            sidebarContent
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
        } detail: {
            detailContent
        }
        .searchable(text: $vm.searchText, prompt: "Search captures…")
        .task {
            await vm.load(libraryService: appServices.libraryService)
        }
        .onChange(of: vm.searchText) {
            Task { await vm.load(libraryService: appServices.libraryService) }
        }
    }

    // MARK: - Sidebar

    @ViewBuilder
    private var sidebarContent: some View {
        List(selection: $vm.selectedSmartFilter) {

            // Smart Filters
            Section("Library") {
                ForEach(SmartFilter.allCases) { filter in
                    Label(filter.rawValue, systemImage: filter.symbol)
                        .tag(filter)
                        .badge(smartFilterCount(filter))
                }
            }

            // Capture Types
            Section("Type") {
                ForEach(CaptureType.allCases, id: \.self) { type in
                    CaptureTypeFilterRow(
                        type: type,
                        count: vm.captureTypeCounts[type] ?? 0,
                        isSelected: vm.selectedCaptureTypes.contains(type)
                    ) {
                        if vm.selectedCaptureTypes.contains(type) {
                            vm.selectedCaptureTypes.remove(type)
                        } else {
                            vm.selectedCaptureTypes.insert(type)
                        }
                    }
                }
            }

            // Tag Cloud
            if !vm.allTags.isEmpty {
                Section("Tags") {
                    TagCloudView(
                        tags: vm.allTags,
                        selectedTags: $vm.selectedTags
                    )
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("SnapForge Library")
    }

    // MARK: - Detail

    @ViewBuilder
    private var detailContent: some View {
        if vm.isLoading {
            loadingView
        } else if vm.filteredCaptures.isEmpty {
            emptyStateView
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(vm.filteredCaptures, id: \.id) { capture in
                        CaptureThumbnailCell(
                            capture: capture,
                            isSelected: vm.selectedCapture?.id == capture.id
                        ) {
                            vm.selectedCapture = capture
                        } onDelete: {
                            Task { await vm.delete(id: capture.id, libraryService: appServices.libraryService) }
                        }
                    }
                }
                .padding(DesignSystem.Spacing.md)
            }
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(1.2)
            Text("Loading captures…")
                .font(DesignSystem.Typography.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            ZStack {
                Circle()
                    .fill(DesignSystem.Colors.forgeOrange.opacity(0.1))
                    .frame(width: 100, height: 100)
                Image(systemName: "hammer.fill")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.forgeOrange)
            }

            VStack(spacing: DesignSystem.Spacing.xs) {
                Text(vm.searchText.isEmpty ? "No Captures Yet" : "No Results")
                    .font(DesignSystem.Typography.title2)
                    .foregroundStyle(.primary)

                Text(vm.searchText.isEmpty
                     ? "Take a screenshot, record a video, or capture text with OCR."
                     : "Try a different search query or clear your filters.")
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func smartFilterCount(_ filter: SmartFilter) -> Int {
        switch filter {
        case .all:      return vm.captures.count
        case .today:
            let cal = Calendar.current
            return vm.captures.filter { cal.isDateInToday($0.createdAt) }.count
        case .thisWeek:
            let cal = Calendar.current
            let start = cal.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
            return vm.captures.filter { $0.createdAt >= start }.count
        case .starred:
            return vm.captures.filter(\.isStarred).count
        }
    }
}

// MARK: - CaptureTypeFilterRow

private struct CaptureTypeFilterRow: View {
    let type: CaptureType
    let count: Int
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: type.symbol)
                    .foregroundStyle(isSelected ? DesignSystem.Colors.forgeOrange : .secondary)
                    .frame(width: 20)
                Text(type.displayLabel)
                    .foregroundStyle(isSelected ? DesignSystem.Colors.forgeOrange : .primary)
                Spacer()
                Text("\(count)")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .padding(.vertical, 2)
    }
}

// MARK: - TagCloudView

private struct TagCloudView: View {
    let tags: [TagUsage]
    @Binding var selectedTags: Set<String>

    var body: some View {
        FlowLayout(spacing: DesignSystem.Spacing.xs) {
            ForEach(tags.prefix(20), id: \.tag) { tagUsage in
                TagChip(
                    tag: tagUsage.tag,
                    count: tagUsage.count,
                    isSelected: selectedTags.contains(tagUsage.tag)
                ) {
                    if selectedTags.contains(tagUsage.tag) {
                        selectedTags.remove(tagUsage.tag)
                    } else {
                        selectedTags.insert(tagUsage.tag)
                    }
                }
            }
        }
    }
}

// MARK: - TagChip

private struct TagChip: View {
    let tag: String
    let count: Int
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Text(tag)
                    .font(DesignSystem.Typography.caption)
                Text("\(count)")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                isSelected
                    ? DesignSystem.Colors.forgeOrange.opacity(0.15)
                    : Color.primary.opacity(0.07),
                in: Capsule()
            )
            .foregroundStyle(isSelected ? DesignSystem.Colors.forgeOrange : .primary)
            .overlay(
                Capsule().stroke(
                    isSelected ? DesignSystem.Colors.forgeOrange : Color.clear,
                    lineWidth: 1
                )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - FlowLayout

/// Simple left-to-right wrapping layout for tag chips.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - CaptureThumbnailCell

private struct CaptureThumbnailCell: View {
    let capture: CaptureRecordSnapshot
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                // Thumbnail area
                ZStack {
                    RoundedRectangle(cornerRadius: DesignSystem.Radii.sm, style: .continuous)
                        .fill(DesignSystem.Colors.surfacePrimary)

                    if let thumbPath = capture.thumbnailPath,
                       let nsImage = NSImage(contentsOfFile: thumbPath) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .scaledToFill()
                            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radii.sm, style: .continuous))
                    } else {
                        Image(systemName: captureTypeSymbol)
                            .font(.system(size: 28, weight: .light))
                            .foregroundStyle(DesignSystem.Colors.forgeOrange.opacity(0.6))
                    }

                    // Starred badge
                    if capture.isStarred {
                        Image(systemName: "star.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(DesignSystem.Colors.sparkGold)
                            .padding(6)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    }
                }
                .frame(height: 120)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Radii.sm, style: .continuous)
                        .stroke(
                            isSelected ? DesignSystem.Colors.forgeOrange : Color.clear,
                            lineWidth: 2
                        )
                )

                // Filename
                Text(fileName)
                    .font(DesignSystem.Typography.callout)
                    .lineLimit(1)
                    .foregroundStyle(.primary)

                // Metadata row
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Text(capture.captureType.capitalized)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(ByteCountFormatter.string(fromByteCount: capture.fileSize, countStyle: .file))
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(DesignSystem.Spacing.sm)
            .background(
                DesignSystem.Materials.thick,
                in: RoundedRectangle(cornerRadius: DesignSystem.Radii.md, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radii.md, style: .continuous)
                    .stroke(
                        isSelected
                            ? DesignSystem.Colors.forgeOrange.opacity(0.5)
                            : (isHovered ? DesignSystem.Colors.glassBorder : DesignSystem.Colors.glassBorderSubtle),
                        lineWidth: isSelected ? 1.5 : 0.5
                    )
            )
            .forgeShadow(isHovered ? DesignSystem.Shadows.medium : DesignSystem.Shadows.subtle)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .contextMenu {
            Button("Delete", role: .destructive, action: onDelete)
        }
    }

    private var fileName: String {
        capture.filePath.components(separatedBy: "/").last ?? capture.filePath
    }

    private var captureTypeSymbol: String {
        switch CaptureType(rawValue: capture.captureType) {
        case .screenshot: return "camera"
        case .scrolling:  return "arrow.up.and.down.text.horizontal"
        case .video:      return "record.circle"
        case .gif:        return "photo.on.rectangle"
        case .ocr:        return "doc.text.viewfinder"
        case .pin:        return "pin"
        case .none:       return "photo"
        }
    }
}

// MARK: - CaptureType Helpers

private extension CaptureType {
    var symbol: String {
        switch self {
        case .screenshot: return "camera"
        case .scrolling:  return "arrow.up.and.down.text.horizontal"
        case .video:      return "record.circle"
        case .gif:        return "photo.on.rectangle"
        case .ocr:        return "doc.text.viewfinder"
        case .pin:        return "pin"
        }
    }

    var displayLabel: String {
        switch self {
        case .screenshot: return "Screenshot"
        case .scrolling:  return "Scrolling"
        case .video:      return "Video"
        case .gif:        return "GIF"
        case .ocr:        return "OCR"
        case .pin:        return "Pin"
        }
    }
}

// MARK: - CaptureRecordSnapshot Helpers

private extension CaptureRecordSnapshot {
    var tagArray: [String] {
        tags.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    LibraryBrowserView()
        .environment(AppServices())
        .frame(width: 900, height: 600)
}
#endif
