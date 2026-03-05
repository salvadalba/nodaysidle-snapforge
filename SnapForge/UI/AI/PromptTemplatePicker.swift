import SwiftUI

// MARK: - PromptTemplatePicker

/// Sheet view for browsing, selecting, and creating prompt templates.
/// Highlights `{{image}}` and `{{ocr_text}}` placeholders in the editor.
struct PromptTemplatePicker: View {

    // MARK: - Input

    let templates: [PromptTemplate]
    /// Called when the user confirms a template selection.
    var onTemplateSelected: ((PromptTemplate) -> Void)?
    var onDismiss: (() -> Void)?

    // MARK: - State

    @State private var selectedTemplate: PromptTemplate?
    @State private var editorText: String = ""
    @State private var isCreatingNew: Bool = false
    @State private var newTemplateName: String = ""
    @State private var newTemplateCategory: String = "custom"

    // MARK: - Body

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 200, ideal: 240)
        } detail: {
            if let selected = selectedTemplate {
                templateDetail(for: selected)
            } else {
                detailPlaceholder
            }
        }
        .navigationTitle("Prompt Templates")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { onDismiss?() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Use Template") {
                    if let selected = selectedTemplate {
                        onTemplateSelected?(selected)
                        onDismiss?()
                    }
                }
                .disabled(selectedTemplate == nil)
                .buttonStyle(.borderedProminent)
                .tint(DesignSystem.Colors.forgeOrange)
            }
        }
        .frame(minWidth: 680, minHeight: 440)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $selectedTemplate) {
            ForEach(templates) { template in
                templateRow(for: template)
                    .tag(template)
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            newTemplateButton
        }
        .sheet(isPresented: $isCreatingNew) {
            newTemplateSheet
        }
    }

    private func templateRow(for template: PromptTemplate) -> some View {
        HStack(alignment: .center, spacing: DesignSystem.Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(template.name)
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack(spacing: DesignSystem.Spacing.xs) {
                    categoryPill(template.category)
                    Text("\(template.usageCount) use\(template.usageCount == 1 ? "" : "s")")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.warmGray)
                }
            }
            Spacer()
            if template.isDefault {
                Image(systemName: "star.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(DesignSystem.Colors.sparkGold)
            }
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
    }

    private func categoryPill(_ category: String) -> some View {
        Text(category.capitalized)
            .font(DesignSystem.Typography.caption)
            .foregroundStyle(DesignSystem.Colors.warmGray)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(DesignSystem.Colors.warmGray.opacity(0.15))
            )
    }

    private var newTemplateButton: some View {
        Button(action: { isCreatingNew = true }) {
            Label("New Template", systemImage: "plus.circle.fill")
                .font(DesignSystem.Typography.body)
                .foregroundStyle(DesignSystem.Colors.forgeOrange)
        }
        .buttonStyle(.plain)
        .padding(DesignSystem.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Template Detail

    private func templateDetail(for template: PromptTemplate) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Text(template.name)
                    .font(DesignSystem.Typography.title2)
                    .foregroundStyle(.primary)
                categoryPill(template.category)
                Spacer()
                Text("\(template.usageCount) use\(template.usageCount == 1 ? "" : "s")")
                    .font(DesignSystem.Typography.callout)
                    .foregroundStyle(DesignSystem.Colors.warmGray)
            }

            Divider()

            Text("Template")
                .font(DesignSystem.Typography.callout)
                .foregroundStyle(DesignSystem.Colors.warmGray)

            ScrollView {
                Text(highlightedTemplate(template.template))
                    .font(DesignSystem.Typography.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(DesignSystem.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.05))
                    )
            }

            Spacer()
        }
        .padding(DesignSystem.Spacing.lg)
    }

    private var detailPlaceholder: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "text.bubble")
                .font(.system(size: 36))
                .foregroundStyle(DesignSystem.Colors.warmGray)
            Text("Select a template to preview it")
                .font(DesignSystem.Typography.body)
                .foregroundStyle(DesignSystem.Colors.warmGray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - New Template Sheet

    private var newTemplateSheet: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("New Template")
                .font(DesignSystem.Typography.title2)
                .padding(.bottom, DesignSystem.Spacing.xs)

            TextField("Template name", text: $newTemplateName)
                .textFieldStyle(.roundedBorder)

            Picker("Category", selection: $newTemplateCategory) {
                Text("Explain").tag("explain")
                Text("Annotate").tag("annotate")
                Text("Summarize").tag("summarize")
                Text("Custom").tag("custom")
            }
            .pickerStyle(.segmented)

            Text("Template Body")
                .font(DesignSystem.Typography.callout)
                .foregroundStyle(DesignSystem.Colors.warmGray)

            Text("Available placeholders: {{image}}, {{ocr_text}}")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.warmGray)

            TextEditor(text: $editorText)
                .font(DesignSystem.Typography.body)
                .frame(minHeight: 120)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )

            HStack {
                Button("Cancel") {
                    isCreatingNew = false
                    newTemplateName = ""
                    editorText = ""
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Create") {
                    isCreatingNew = false
                    // In production, call PromptStorageService.createTemplate — the
                    // caller is responsible for persistence and list refresh.
                }
                .buttonStyle(.borderedProminent)
                .tint(DesignSystem.Colors.forgeOrange)
                .disabled(newTemplateName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .frame(minWidth: 400, minHeight: 360)
    }

    // MARK: - Placeholder Highlighting

    /// Returns an `AttributedString` that renders `{{image}}` and `{{ocr_text}}`
    /// with a yellow highlight background so authors can spot them at a glance.
    private func highlightedTemplate(_ text: String) -> AttributedString {
        var attributed = AttributedString(text)
        let placeholders = ["{{image}}", "{{ocr_text}}"]

        for placeholder in placeholders {
            var searchStart = attributed.startIndex
            while searchStart < attributed.endIndex {
                guard let range = attributed[searchStart...].range(of: placeholder) else { break }
                attributed[range].backgroundColor = .yellow.opacity(0.35)
                attributed[range].foregroundColor = .primary
                searchStart = range.upperBound
            }
        }

        return attributed
    }
}

// MARK: - Preview

#Preview {
    let templates: [PromptTemplate] = [
        PromptTemplate(name: "Explain this screenshot", template: "Please explain what is shown in this screenshot.\n\n{{ocr_text}}", category: "explain", usageCount: 14, isDefault: true),
        PromptTemplate(name: "Summarize the text", template: "Summarize the key points from the text below:\n\n{{ocr_text}}", category: "summarize", usageCount: 7, isDefault: true),
        PromptTemplate(name: "Extract key information", template: "Extract all key information, data points, and actionable items from {{image}}.\n\n{{ocr_text}}", category: "explain", usageCount: 3),
        PromptTemplate(name: "My Custom Template", template: "Describe the UI elements visible in {{image}}.", category: "custom", usageCount: 1)
    ]

    PromptTemplatePicker(
        templates: templates,
        onTemplateSelected: { print("Selected: \($0.name)") },
        onDismiss: {}
    )
}
