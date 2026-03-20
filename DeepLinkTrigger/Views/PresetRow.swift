import SwiftUI

struct PresetRow: View {
    let link: DeepLink
    let onTrigger: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "star.fill")
                .foregroundStyle(.yellow)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(link.name)
                    .font(.system(.body, weight: .medium))
                Text(link.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Text("Preset")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.yellow)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.yellow.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))

            Image(systemName: "play.fill")
                .foregroundStyle(.blue)
                .font(.caption)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTrigger)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.clear)
        )
        .contextMenu {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete Preset", systemImage: "trash")
            }
        }
    }
}
