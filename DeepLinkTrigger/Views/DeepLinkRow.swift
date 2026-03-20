import SwiftUI

struct DeepLinkRow: View {
    let link: DeepLink
    let isExpanded: Bool
    let onTap: () -> Void
    let onTrigger: ([String: String], [String: String]) -> Void
    let onSavePreset: (String, [String: String], [String: String]) -> Void
    let onDelete: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main row
            HStack {
                // Icon distinguishing no-param vs parameterized
                if link.hasParams {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundStyle(.orange)
                        .frame(width: 20)
                } else {
                    Image(systemName: "bolt.fill")
                        .foregroundStyle(.blue)
                        .frame(width: 20)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(link.name)
                        .font(.system(.body, weight: .medium))
                    Text(link.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if link.source == .manual {
                    sourceBadge("Manual", color: .purple)
                }

                if link.hasParams {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                } else {
                    Image(systemName: "play.fill")
                        .foregroundStyle(.blue)
                        .font(.caption)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .contextMenu {
                if let onDelete {
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }

            // Expanded param form
            if isExpanded && link.hasParams {
                ParamFormView(
                    link: link,
                    onTrigger: onTrigger,
                    onSavePreset: onSavePreset
                )
                .padding(.horizontal, 8)
                .padding(.bottom, 6)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isExpanded ? Color.accentColor.opacity(0.05) : Color.clear)
        )
    }

    private func sourceBadge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
    }
}
