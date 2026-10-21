import SwiftUI
import UniformTypeIdentifiers
import ZIPFoundation

/// Experimental iOS 17 PosterBoard installer.
///
/// This intentionally uses the same .Trash symlink workflow as Pocket Poster.
/// It is isolated from the Wallet exploit and requires the PosterBoard app hash
/// supplied by Nugget's Pocket Poster Helper.
final class ExperimentalPosterBoardManager: ObservableObject {
    @Published var selectedFiles: [URL] = []
    @Published var appHash = UserDefaults.standard.string(forKey: "aircard17.posterboard_hash") ?? ""
    @Published var log: [String] = []
    @Published var isApplying = false
    @Published var isDetecting = false

    private let extensionVersion = "61" // iOS 17+ PosterBoard layout

    private var documents: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private var trashLink: URL {
        documents.appendingPathComponent(".Trash", isDirectory: false)
    }

    private let exploit = ExploitManager.shared
    private let helper = ObjcHelper()

    func saveHash() {
        appHash = appHash.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(appHash, forKey: "aircard17.posterboard_hash")
    }

    func addFiles(_ urls: [URL]) {
        for url in urls where url.pathExtension.lowercased() == "tendies" {
            if !selectedFiles.contains(url) { selectedFiles.append(url) }
        }
    }

    func clear() {
        selectedFiles.removeAll()
        log.removeAll()
    }

    /// Finds the PosterBoard data-container UUID directly instead of relying on
    /// Nugget/Pocket Poster to pass it through AFC.
    func detectPosterBoardHash() async {
        guard !isDetecting else { return }
        isDetecting = true
        defer { isDetecting = false }

        if !exploit.kfsReady && !exploit.directWriteReady {
            append("Preparing filesystem access…")
            await withCheckedContinuation { continuation in
                exploit.runAll { _ in continuation.resume() }
            }
        }

        let roots = [
            "/var/mobile/Containers/Data/Application",
            "/private/var/mobile/Containers/Data/Application"
        ]

        for root in roots {
            let entries = directoryEntries(at: root)
            for entry in entries where UUID(uuidString: entry) != nil {
                let base = root + "/" + entry
                let extensions = base + "/Library/Application Support/PRBPosterExtensionDataStore/61/Extensions"
                if directoryExists(at: extensions) {
                    appHash = entry
                    saveHash()
                    append("Detected PosterBoard app hash: \(entry)")
                    return
                }
            }
        }

        append("PosterBoard container was not found. Leave the phone unlocked and run Access/Exploit once, then try Detect again.")
    }

    private func directoryEntries(at path: String) -> [String] {
        if let direct = try? FileManager.default.contentsOfDirectory(atPath: path), !direct.isEmpty {
            return direct
        }
        guard exploit.kfsReady else { return [] }
        return helper.kfsListDirectory(path)
    }

    private func directoryExists(at path: String) -> Bool {
        if FileManager.default.fileExists(atPath: path) {
            var isDirectory = ObjCBool(false)
            if FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) {
                return isDirectory.boolValue
            }
        }
        guard exploit.kfsReady else { return false }
        return helper.kfsFileSizeNC(path) >= -2
    }

    func apply() async {
        guard !appHash.isEmpty else {
            append("Enter the PosterBoard app hash first.")
            return
        }
        guard !selectedFiles.isEmpty else {
            append("Select at least one .tendies file.")
            return
        }

        isApplying = true
        defer { isApplying = false }
        do {
            try removeLink()
            for file in selectedFiles {
                append("Extracting \(file.lastPathComponent)…")
                let root = try extract(file)
                try applyRoot(root)
            }
            try? removeLink()
            append("Done. Open the native Lock Screen wallpaper picker to choose it.")
            selectedFiles.removeAll()
        } catch {
            try? removeLink()
            append("ERROR: \(error.localizedDescription)")
        }
    }

    private func append(_ line: String) {
        DispatchQueue.main.async { self.log.append(line) }
    }

    private func extract(_ file: URL) throws -> URL {
        let work = documents.appendingPathComponent("AirCard17-Tendies-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        let archive = work.appendingPathComponent(file.lastPathComponent)
        let scoped = file.startAccessingSecurityScopedResource()
        defer { if scoped { file.stopAccessingSecurityScopedResource() } }
        try FileManager.default.copyItem(at: file, to: archive)
        let output = work.appendingPathComponent("unpacked", isDirectory: true)
        try FileManager.default.unzipItem(at: archive, to: output)
        return output
    }

    private func applyRoot(_ root: URL) throws {
        let children = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
        for child in children {
            let name = child.lastPathComponent.lowercased()
            if name == "container" {
                let extensions = child.appendingPathComponent("Library/Application Support/PRBPosterExtensionDataStore/\(extensionVersion)/Extensions", isDirectory: true)
                let extFolders = try FileManager.default.contentsOfDirectory(at: extensions, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
                for ext in extFolders {
                    try installDescriptors(ext.appendingPathComponent("descriptors", isDirectory: true), extensionID: ext.lastPathComponent)
                }
            } else if ["descriptor", "descriptors", "ordered-descriptor", "ordered-descriptors"].contains(name) {
                try installDescriptors(child, extensionID: "com.apple.WallpaperKit.CollectionsPoster")
            } else if ["video-descriptor", "video-descriptors"].contains(name) {
                try installDescriptors(child, extensionID: "com.apple.PhotosUIPrivate.PhotosPosterProvider")
            }
        }
    }

    private func installDescriptors(_ source: URL, extensionID: String) throws {
        let target = "/var/mobile/Containers/Data/Application/\(appHash)/Library/Application Support/PRBPosterExtensionDataStore/\(extensionVersion)/Extensions/\(extensionID)/descriptors"
        try removeLink()
        try FileManager.default.createSymbolicLink(at: trashLink, withDestinationURL: URL(fileURLWithPath: target, isDirectory: true))
        defer { try? FileManager.default.removeItem(at: trashLink) }

        let descriptors = try FileManager.default.contentsOfDirectory(at: source, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
        for descriptor in descriptors where descriptor.lastPathComponent != "__MACOSX" {
            try randomizeIdentifiers(in: descriptor)
            let staging = documents.appendingPathComponent("AirCard17-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.moveItem(at: descriptor, to: staging)
            append("Installing \(descriptor.lastPathComponent) → \(extensionID)")
            try FileManager.default.trashItem(at: staging, resultingItemURL: nil)
        }
    }

    private func randomizeIdentifiers(in folder: URL) throws {
        let identifier = Int.random(in: 10_000...99_999)
        guard let enumerator = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: [.isRegularFileKey], options: .skipsHiddenFiles) else { return }
        for case let file as URL in enumerator {
            switch file.lastPathComponent {
            case "com.apple.posterkit.provider.descriptor.identifier":
                try Data(String(identifier).utf8).write(to: file)
            case "com.apple.posterkit.provider.contents.userInfo", "Wallpaper.plist":
                guard let data = try? Data(contentsOf: file),
                      var plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else { continue }
                if file.lastPathComponent == "Wallpaper.plist" { plist["identifier"] = identifier }
                else if plist["wallpaperRepresentingIdentifier"] != nil { plist["wallpaperRepresentingIdentifier"] = identifier }
                let updated = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
                try updated.write(to: file)
            default: continue
            }
        }
    }

    private func removeLink() throws {
        try? FileManager.default.removeItem(at: trashLink)
    }
}

struct ExperimentalWallpapersView: View {
    @StateObject private var manager = ExperimentalPosterBoardManager()
    @State private var showImporter = false

    var body: some View {
            NavigationView {
            Form {
                Section("Experimental iOS 17 Wallpapers") {
                    Text("Uses the legacy PosterBoard .Trash method. Keep a backup and test one wallpaper at a time.")
                        .font(.caption)
                        .foregroundColor(.orange)
                    TextField("PosterBoard app hash", text: $manager.appHash)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button(manager.isDetecting ? "Detecting…" : "Detect PosterBoard Automatically") {
                        Task { await manager.detectPosterBoardHash() }
                    }
                    Button("Save Hash") { manager.saveHash() }
                }
                Section("Wallpapers") {
                    Button("Import .tendies") { showImporter = true }
                    ForEach(manager.selectedFiles, id: \.self) { Text($0.lastPathComponent) }
                        .onDelete { manager.selectedFiles.remove(atOffsets: $0) }
                    Button(manager.isApplying ? "Applying…" : "Apply Wallpapers") {
                        Task { await manager.apply() }
                    }
                    .disabled(manager.isApplying || manager.selectedFiles.isEmpty)
                }
                Section("Log") {
                    Text(manager.log.isEmpty ? "No activity yet." : manager.log.joined(separator: "\n"))
                        .font(.system(size: 11, design: .monospaced))
                }
            }
            .navigationTitle("Wallpapers")
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [UTType(filenameExtension: "tendies") ?? .data], allowsMultipleSelection: true) { result in
                if case .success(let urls) = result { manager.addFiles(urls) }
            }
        }
    }
}
