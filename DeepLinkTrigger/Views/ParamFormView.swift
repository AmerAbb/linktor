import SwiftUI

struct ParamFormView: View {
    let link: DeepLink
    let onTrigger: ([String: String], [String: String]) -> Void
    let onSavePreset: (String, [String: String], [String: String]) -> Void

    @State private var pathValues: [String: String] = [:]
    @State private var queryValues: [String: String] = [:]
    @State private var showSavePreset = false
    @State private var presetName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !link.pathParams.isEmpty {
                paramSection(title: "Path Parameters", params: link.pathParams, values: $pathValues)
            }
            if !link.queryParams.isEmpty {
                paramSection(title: "Query Parameters", params: link.queryParams, values: $queryValues)
            }

            // Preview URL
            let previewURL = URLBuilder.buildURL(from: link, pathValues: pathValues, queryValues: queryValues)
            Text(previewURL)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .textSelection(.enabled)
                .padding(6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))

            HStack {
                Button("Trigger") {
                    onTrigger(pathValues, queryValues)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button("Save as Preset") {
                    presetName = link.name
                    showSavePreset = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            if showSavePreset {
                HStack {
                    TextField("Preset name", text: $presetName)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.small)
                    Button("Save") {
                        onSavePreset(presetName, pathValues, queryValues)
                        showSavePreset = false
                    }
                    .controlSize(.small)
                    Button("Cancel") {
                        showSavePreset = false
                    }
                    .controlSize(.small)
                }
            }
        }
        .onAppear {
            // Pre-fill with defaults
            for param in link.pathParams {
                pathValues[param.name] = param.defaultValue
            }
            for param in link.queryParams {
                queryValues[param.name] = param.defaultValue
            }
        }
    }

    private func paramSection(title: String, params: [ParamEntry], values: Binding<[String: String]>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fontWeight(.semibold)

            ForEach(params) { param in
                HStack {
                    Text(param.name)
                        .font(.system(.caption, design: .monospaced))
                        .frame(width: 80, alignment: .trailing)
                    TextField(param.defaultValue, text: Binding(
                        get: { values.wrappedValue[param.name] ?? param.defaultValue },
                        set: { values.wrappedValue[param.name] = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
                }
            }
        }
    }
}
