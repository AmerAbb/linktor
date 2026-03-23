import SwiftUI

struct MainPopoverView: View {
    @State private var searchText = ""
    @State private var deepLinks: [DeepLink] = []
    @State private var projectPath: String?
    @State private var detectedPlatform: Platform?
    @State private var errorMessage: String?
    @State private var showQuickAdd = false
    @State private var expandedLinkID: UUID?
    @State private var triggerStatus: TriggerStatus?
    @State private var statusClearID = 0
    @State private var devices: [Device] = []
    @State private var selectedDevice: Device?
    @State private var bundleId: String?

    private let configLoader = ConfigLoader()
    private let deviceService = DeviceService()
    private let storageService = StorageService()

    private var filteredLinks: [DeepLink] {
        if searchText.isEmpty { return deepLinks }
        let query = searchText.lowercased()
        return deepLinks.filter {
            $0.name.lowercased().contains(query) || $0.path.lowercased().contains(query)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            searchBar
            Divider()

            if let error = errorMessage {
                errorBanner(error)
            }

            if deepLinks.isEmpty && projectPath != nil {
                emptyState
            } else if projectPath == nil {
                noProjectState
            } else {
                linkList
            }

            if let status = triggerStatus {
                statusBar(status)
            }
        }
        .frame(width: 380, height: 500)
        .onAppear(perform: loadLastProject)
        .sheet(isPresented: $showQuickAdd) {
            QuickAddView { name, url in
                addManualLink(name: name, url: url)
            }
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            if let path = projectPath {
                if let platform = detectedPlatform {
                    Image(systemName: platform.iconName)
                        .foregroundStyle(platform == .ios ? .blue : .green)
                }
                Text(URL(fileURLWithPath: path).lastPathComponent)
                    .font(.headline)
                    .lineLimit(1)
            } else {
                Text("DeepLink Trigger")
                    .font(.headline)
            }

            Spacer()

            if !devices.isEmpty || detectedPlatform != nil {
                devicePicker
            }

            Button(action: { loadLinks() }) {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("Reload .deeplinks.json")
            .disabled(projectPath == nil)

            Button(action: { showQuickAdd = true }) {
                Image(systemName: "plus")
            }
            .buttonStyle(.borderless)
            .help("Add a one-off URL")

            Button(action: selectProject) {
                Image(systemName: "folder")
            }
            .buttonStyle(.borderless)
            .help("Select project folder")

            Button(action: { NSApplication.shared.terminate(nil) }) {
                Image(systemName: "xmark.circle")
            }
            .buttonStyle(.borderless)
            .help("Quit DeepLink Trigger")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Search

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search deeplinks...", text: $searchText)
                .textFieldStyle(.plain)
        }
        .padding(8)
        .background(.quaternary)
        .cornerRadius(8)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Device Picker

    private var devicePicker: some View {
        Menu {
            if devices.isEmpty {
                Text("No devices found")
            } else {
                ForEach(devices) { device in
                    Button(action: { selectedDevice = device }) {
                        HStack {
                            if selectedDevice?.id == device.id {
                                Image(systemName: "checkmark")
                            }
                            Text(device.displayName)
                        }
                    }
                }
            }
            Divider()
            Button("Refresh Devices") {
                refreshDevices()
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: selectedDevice?.type == .physical ? "iphone" : "desktopcomputer")
                    .font(.caption)
                Text(selectedDevice?.name ?? "No Device")
                    .font(.caption)
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 8))
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.borderless)
        .fixedSize()
    }

    // MARK: - Link List

    private var linkList: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(filteredLinks) { link in
                    if link.source == .preset {
                        PresetRow(link: link) {
                            triggerLink(url: link.path)
                        } onDelete: {
                            deletePreset(link)
                        }
                    } else {
                        DeepLinkRow(
                            link: link,
                            isExpanded: expandedLinkID == link.id,
                            onTap: {
                                if link.hasParams {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        expandedLinkID = expandedLinkID == link.id ? nil : link.id
                                    }
                                } else {
                                    let url = URLBuilder.buildURL(from: link, pathValues: [:], queryValues: [:])
                                    triggerLink(url: url)
                                }
                            },
                            onTrigger: { pathValues, queryValues in
                                let url = URLBuilder.buildURL(from: link, pathValues: pathValues, queryValues: queryValues)
                                triggerLink(url: url)
                            },
                            onSavePreset: { name, pathValues, queryValues in
                                let url = URLBuilder.buildURL(from: link, pathValues: pathValues, queryValues: queryValues)
                                savePreset(name: name, url: url, originalLinkName: link.name)
                            },
                            onDelete: link.source == .manual ? { deleteManualLink(link) } : nil
                        )
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }

    // MARK: - States

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "doc.text.magnifyingglass")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No .deeplinks.json found")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Add one to your project root or use + to add links manually.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding()
    }

    private var noProjectState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("No project selected")
                .font(.subheadline)
            Button("Select Project Folder") {
                selectProject()
            }
            Spacer()
        }
        .padding()
    }

    private func errorBanner(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text(message)
                .font(.caption)
                .lineLimit(2)
            Spacer()
            Button(action: { errorMessage = nil }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
        }
        .padding(8)
        .background(Color.yellow.opacity(0.1))
    }

    private func statusBar(_ status: TriggerStatus) -> some View {
        HStack {
            switch status {
            case .success(let url):
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text(url)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.middle)
            case .failure(let message):
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
                Text(message)
                    .font(.caption)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(8)
        .background(.bar)
    }

    // MARK: - Actions

    @MainActor
    private func refreshDevices() {
        guard let platform = detectedPlatform else { return }
        Task {
            let found = await deviceService.listDevices(platform: platform)
            devices = found
            // Preserve current selection if still available
            if let current = selectedDevice, found.contains(where: { $0.id == current.id }) {
                // keep current
            } else {
                // Auto-select: physical first (already sorted by sortKey)
                selectedDevice = found.first
            }
        }
    }

    private func selectProject() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Select the project folder containing .deeplinks.json"

        if panel.runModal() == .OK, let url = panel.url {
            projectPath = url.path
            detectedPlatform = Platform.detect(in: url.path)
            storageService.lastProjectPath = url.path
            loadLinks()
        }
    }

    private func loadLastProject() {
        if let path = storageService.lastProjectPath {
            projectPath = path
            detectedPlatform = Platform.detect(in: path)
            loadLinks()
        }
    }

    private func loadLinks() {
        guard let path = projectPath else { return }
        errorMessage = nil
        var allLinks: [DeepLink] = []

        // Load from config file
        do {
            let config = try configLoader.load(from: path)
            bundleId = config.bundleId
            allLinks += config.links.map { DeepLink.from(definition: $0, scheme: config.scheme) }
        } catch is ConfigLoader.ConfigError {
            // No config file — that's OK, we may still have manual links
        } catch {
            errorMessage = error.localizedDescription
        }

        // Load manual links
        let manualLinks = storageService.loadManualLinks(for: path)
        allLinks += manualLinks.map { DeepLink.manual(id: $0.id, name: $0.name, url: $0.url) }

        // Load presets
        let presets = storageService.loadPresets(for: path)
        allLinks += presets.map { preset in
            DeepLink(
                id: preset.id,
                name: preset.name,
                path: preset.resolvedURL,
                scheme: "",
                pathParams: [],
                queryParams: [],
                source: .preset
            )
        }

        deepLinks = allLinks
        refreshDevices()
    }

    private func triggerLink(url: String) {
        guard let device = selectedDevice else {
            triggerStatus = .failure("No device selected — connect a device or start a simulator")
            scheduleClearStatus()
            return
        }
        Task {
            do {
                try await deviceService.openURL(url, device: device, bundleId: bundleId)
                triggerStatus = .success(url)
            } catch {
                triggerStatus = .failure(error.localizedDescription)
            }
            scheduleClearStatus()
        }
    }

    private func scheduleClearStatus() {
        statusClearID += 1
        let currentID = statusClearID
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if statusClearID == currentID {
                withAnimation { triggerStatus = nil }
            }
        }
    }

    private func addManualLink(name: String, url: String) {
        guard let path = projectPath else { return }
        storageService.addManualLink(name: name, url: url, for: path)
        loadLinks()
    }

    private func deleteManualLink(_ link: DeepLink) {
        guard let path = projectPath else { return }
        storageService.removeManualLink(id: link.id, for: path)
        loadLinks()
    }

    private func savePreset(name: String, url: String, originalLinkName: String) {
        guard let path = projectPath else { return }
        let preset = Preset(name: name, resolvedURL: url, originalLinkName: originalLinkName)
        storageService.addPreset(preset, for: path)
        loadLinks()
    }

    private func deletePreset(_ link: DeepLink) {
        guard let path = projectPath else { return }
        storageService.removePreset(id: link.id, for: path)
        loadLinks()
    }
}

enum TriggerStatus {
    case success(String)
    case failure(String)
}
