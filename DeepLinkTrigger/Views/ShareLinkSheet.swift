import SwiftUI
import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins

/// A deeplink URL to hand off to a device that the Mac can't reach directly
/// (e.g. a physical iPhone on a machine with no Xcode tooling).
struct ShareTarget: Identifiable {
    let id = UUID()
    let url: String
}

/// Presents a deeplink as a scannable QR code plus a copy button, so the link
/// can be opened on a device without any Mac → device bridge (no Xcode/devicectl).
struct ShareLinkSheet: View {
    let url: String
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    var body: some View {
        VStack(spacing: 14) {
            Text("Open on your device")
                .font(.headline)

            if let image = Self.qrImage(from: url) {
                Image(nsImage: image)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 200, height: 200)
                    .background(Color.white)
                    .cornerRadius(8)
            } else {
                Text("Couldn't generate QR code")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(url)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .truncationMode(.middle)
                .padding(.horizontal)

            Text("Scan with the iPhone Camera, or copy the URL and open it on the device.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            HStack {
                Button(action: copyURL) {
                    Label(copied ? "Copied!" : "Copy URL",
                          systemImage: copied ? "checkmark" : "doc.on.doc")
                }
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 280)
    }

    private func copyURL() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url, forType: .string)
        withAnimation { copied = true }
    }

    /// Renders `string` into a crisp QR `NSImage`. Uses CoreImage's QR generator
    /// scaled up with nearest-neighbour so the modules stay sharp.
    static func qrImage(from string: String) -> NSImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))

        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return NSImage(cgImage: cgImage,
                       size: NSSize(width: scaled.extent.width, height: scaled.extent.height))
    }
}
