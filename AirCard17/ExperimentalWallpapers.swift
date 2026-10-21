import SwiftUI
import UniformTypeIdentifiers
import ZIPFoundation
import SQLite3

/// Experimental iOS 17 PosterBoard installer.
///
/// This intentionally uses the same .Trash symlink workflow as Pocket Poster.
/// It is isolated from the Wallet exploit and requires the PosterBoard app hash
/// supplied by Nugget's Pocket Poster Helper.
final class ExperimentalPosterBoardManager: ObservableObject {
    private struct PosterRegistration {
        let uuid: String
        let provider: String
    }

    @Published var selectedFiles: [URL] = []
    @Published var appHash = UserDefaults.standard.string(forKey: "aircard17.posterboard_hash") ?? ""
    @Published var log: [String] = []
    @Published var isApplying = false
    @Published var isDetecting = false

    private let extensionVersion = "61" // iOS 17+ PosterBoard layout
    private let databaseName = "PBFPosterExtensionDataStoreSQLiteDatabase.sqlite3"

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
            var registrations: [PosterRegistration] = []
            for file in selectedFiles {
                append("Extracting \(file.lastPathComponent)…")
                let root = try extract(file)
                registrations.append(contentsOf: try applyRoot(root))
            }
            if !registrations.isEmpty {
                append("Registering \(registrations.count) wallpaper(s) in PosterBoard Collections…")
                try registerInCollections(registrations)
            }
            try? removeLink()
            append("Done. Refreshing PosterBoard…")
            if openPosterBoard() {
                append("PosterBoard opened. Close it from the app switcher, then open the native wallpaper picker.")
            } else {
                append("PosterBoard could not be opened automatically. Reboot the phone, then open the native wallpaper picker.")
            }
            selectedFiles.removeAll()
        } catch {
            try? removeLink()
            append("ERROR: \(error.localizedDescription)")
        }
    }

    /// PosterBoard caches its collection list. Pocket Poster refreshes that
    /// cache by opening PosterBoard and asking the user to close it once.
    /// Keep this as a separate action so a user can retry the refresh without
    /// reinjecting the wallpaper descriptors.
    @discardableResult
    func openPosterBoard() -> Bool {
        guard let workspaceClass = objc_getClass("LSApplicationWorkspace") as? NSObject,
              let workspace = workspaceClass.perform(Selector(("defaultWorkspace")))?.takeUnretainedValue() as? NSObject,
              let result = workspace.perform(Selector(("openApplicationWithBundleID:")), with: "com.apple.PosterBoard")
        else { return false }
        return result != nil
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

    private func applyRoot(_ root: URL) throws -> [PosterRegistration] {
        var registrations: [PosterRegistration] = []
        let children = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
        for child in children {
            let name = child.lastPathComponent.lowercased()
            if name == "container" {
                let extensions = child.appendingPathComponent("Library/Application Support/PRBPosterExtensionDataStore/\(extensionVersion)/Extensions", isDirectory: true)
                let extFolders = try FileManager.default.contentsOfDirectory(at: extensions, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
                for ext in extFolders {
                    registrations.append(contentsOf: try installDescriptors(ext.appendingPathComponent("descriptors", isDirectory: true), extensionID: ext.lastPathComponent))
                }
            } else if ["descriptor", "descriptors", "ordered-descriptor", "ordered-descriptors"].contains(name) {
                registrations.append(contentsOf: try installDescriptors(child, extensionID: "com.apple.WallpaperKit.CollectionsPoster"))
            } else if ["video-descriptor", "video-descriptors"].contains(name) {
                registrations.append(contentsOf: try installDescriptors(child, extensionID: "com.apple.PhotosUIPrivate.PhotosPosterProvider"))
            }
        }
        return registrations
    }

    private func installDescriptors(_ source: URL, extensionID: String) throws -> [PosterRegistration] {
        var registrations: [PosterRegistration] = []
        let target = "/var/mobile/Containers/Data/Application/\(appHash)/Library/Application Support/PRBPosterExtensionDataStore/\(extensionVersion)/Extensions/\(extensionID)/descriptors"
        try removeLink()
        try FileManager.default.createSymbolicLink(at: trashLink, withDestinationURL: URL(fileURLWithPath: target, isDirectory: true))
        defer { try? FileManager.default.removeItem(at: trashLink) }

        let descriptors = try FileManager.default.contentsOfDirectory(at: source, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
        for descriptor in descriptors where descriptor.lastPathComponent != "__MACOSX" {
            let registration = try randomizeIdentifiers(in: descriptor, provider: extensionID)
            let staging = documents.appendingPathComponent(registration.uuid, isDirectory: true)
            try FileManager.default.moveItem(at: descriptor, to: staging)
            append("Installing \(registration.uuid) → \(extensionID)")
            try FileManager.default.trashItem(at: staging, resultingItemURL: nil)
            registrations.append(registration)
        }
        return registrations
    }

    private func randomizeIdentifiers(in folder: URL, provider: String) throws -> PosterRegistration {
        let descriptorUUID = UUID().uuidString.uppercased()
        let identifier = Int.random(in: 10_000...99_999)
        guard let enumerator = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: [.isRegularFileKey], options: .skipsHiddenFiles) else {
            return PosterRegistration(uuid: descriptorUUID, provider: provider)
        }
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
        return PosterRegistration(uuid: descriptorUUID, provider: provider)
    }

    /// The legacy .Trash method copies descriptor files, but iOS does not add
    /// those descriptors to the lock-screen carousel by itself. PosterBoard's
    /// local SQLite store needs one row per imported descriptor. This mirrors
    /// Nugget's config-registration path while reaching the database through
    /// the same symlink escape used for the descriptor install.
    private func registerInCollections(_ registrations: [PosterRegistration]) throws {
        let targetRoot = "/var/mobile/Containers/Data/Application/\(appHash)/Library/Application Support/PRBPosterExtensionDataStore/\(extensionVersion)"
        try removeLink()
        try FileManager.default.createSymbolicLink(at: trashLink, withDestinationURL: URL(fileURLWithPath: targetRoot, isDirectory: true))
        defer { try? FileManager.default.removeItem(at: trashLink) }

        let databaseURL = trashLink.appendingPathComponent(databaseName)
        guard FileManager.default.fileExists(atPath: databaseURL.path) else {
            append("PosterBoard database was not reachable; descriptors were installed but not registered.")
            throw WallpaperError.databaseUnavailable
        }

        var database: OpaquePointer?
        let openResult = sqlite3_open_v2(databaseURL.path, &database, SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil)
        guard openResult == SQLITE_OK, let database else {
            let message = database.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "unknown SQLite error"
            if database != nil { sqlite3_close(database) }
            append("Could not open PosterBoard database: \(message)")
            throw WallpaperError.databaseUnavailable
        }
        defer { sqlite3_close(database) }

        try execute(database, "PRAGMA busy_timeout=5000;")
        try execute(database, "BEGIN IMMEDIATE TRANSACTION;")
        do {
            var sequence = try scalarInt(database, "SELECT COALESCE(seq, 0) FROM sqlite_sequence WHERE name = 'poster' LIMIT 1")
            var sortKey = try scalarInt(database, "SELECT COALESCE(MAX(roleSortKey), 0) FROM posterRoleMembership WHERE roleId = 'PRPosterRoleLockScreen'")
            var added = 0

            for registration in registrations {
                if try hasPoster(database, uuid: registration.uuid) { continue }
                sequence += 1
                sortKey += 1
                try insertPoster(database, posterID: sequence, uuid: registration.uuid, provider: registration.provider)
                try insertUsageMetadata(database, uuid: registration.uuid)
                try insertRoleMembership(database, uuid: registration.uuid, sortKey: sortKey)
                added += 1
            }

            try execute(database, "UPDATE sqlite_sequence SET seq = \(sequence) WHERE name = 'poster';")
            try execute(database, "COMMIT;")
            append("PosterBoard Collections database updated (\(added) added).")
        } catch {
            try? execute(database, "ROLLBACK;")
            throw error
        }
    }

    private enum WallpaperError: LocalizedError {
        case databaseUnavailable
        var errorDescription: String? {
            switch self {
            case .databaseUnavailable:
                return "PosterBoard's Collections database could not be opened through the iOS 17 filesystem bridge."
            }
        }
    }

    private func execute(_ database: OpaquePointer?, _ sql: String) throws {
        var errorMessage: UnsafeMutablePointer<Int8>?
        let result = sqlite3_exec(database, sql, nil, nil, &errorMessage)
        guard result == SQLITE_OK else {
            let message = errorMessage.map { String(cString: $0) } ?? "SQLite error \(result)"
            sqlite3_free(errorMessage)
            throw NSError(domain: "AirCard17.PosterBoard", code: Int(result), userInfo: [NSLocalizedDescriptionKey: message])
        }
    }

    private func scalarInt(_ database: OpaquePointer?, _ sql: String) throws -> Int {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw NSError(domain: "AirCard17.PosterBoard", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not prepare SQLite query."])
        }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int64(statement, 0))
    }

    private func hasPoster(_ database: OpaquePointer?, uuid: String) throws -> Bool {
        var statement: OpaquePointer?
        let sql = "SELECT 1 FROM poster WHERE UUID = ? LIMIT 1;"
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw NSError(domain: "AirCard17.PosterBoard", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not prepare PosterBoard lookup."])
        }
        defer { sqlite3_finalize(statement) }
        try bindText(statement, index: 1, value: uuid)
        return sqlite3_step(statement) == SQLITE_ROW
    }

    private func insertPoster(_ database: OpaquePointer?, posterID: Int, uuid: String, provider: String) throws {
        var statement: OpaquePointer?
        let sql = "INSERT INTO poster (posterId, UUID, providerId) VALUES (?, ?, ?);"
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw NSError(domain: "AirCard17.PosterBoard", code: 3, userInfo: [NSLocalizedDescriptionKey: "Could not prepare PosterBoard poster insert."])
        }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_int64(statement, 1, sqlite3_int64(posterID))
        try bindText(statement, index: 2, value: uuid)
        try bindText(statement, index: 3, value: provider)
        guard sqlite3_step(statement) == SQLITE_DONE else { throw sqliteError(database) }
    }

    private func insertUsageMetadata(_ database: OpaquePointer?, uuid: String) throws {
        var statement: OpaquePointer?
        let sql = "INSERT INTO posterAttributes (posterUUID, roleId, attributeIdentifier, attributePayload) VALUES (?, ?, ?, ?);"
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw NSError(domain: "AirCard17.PosterBoard", code: 4, userInfo: [NSLocalizedDescriptionKey: "Could not prepare PosterBoard metadata insert."])
        }
        defer { sqlite3_finalize(statement) }
        let now = Date().timeIntervalSince1970
        let payload = "{\"creationDate\":\(now),\"extensionAvailable\":true,\"attributeType\":\"PRPosterRoleAttributeTypeUsageMetadata\",\"lastActivatedDate\":\(now + 0.0001),\"lastSelectedDate\":\(now + 0.00001)}"
        try bindText(statement, index: 1, value: uuid)
        try bindText(statement, index: 2, value: "PRPosterRoleLockScreen")
        try bindText(statement, index: 3, value: "PRPosterRoleAttributeTypeUsageMetadata")
        try bindText(statement, index: 4, value: payload)
        guard sqlite3_step(statement) == SQLITE_DONE else { throw sqliteError(database) }
    }

    private func insertRoleMembership(_ database: OpaquePointer?, uuid: String, sortKey: Int) throws {
        var statement: OpaquePointer?
        let sql = "INSERT INTO posterRoleMembership (posterUUID, roleId, roleSortKey) VALUES (?, ?, ?);"
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw NSError(domain: "AirCard17.PosterBoard", code: 5, userInfo: [NSLocalizedDescriptionKey: "Could not prepare PosterBoard membership insert."])
        }
        defer { sqlite3_finalize(statement) }
        try bindText(statement, index: 1, value: uuid)
        try bindText(statement, index: 2, value: "PRPosterRoleLockScreen")
        sqlite3_bind_int64(statement, 3, sqlite3_int64(sortKey))
        guard sqlite3_step(statement) == SQLITE_DONE else { throw sqliteError(database) }
    }

    private func bindText(_ statement: OpaquePointer?, index: Int32, value: String) throws {
        let destructor = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        let result = value.withCString { sqlite3_bind_text(statement, index, $0, -1, destructor) }
        guard result == SQLITE_OK else {
            throw NSError(domain: "AirCard17.PosterBoard", code: Int(result), userInfo: [NSLocalizedDescriptionKey: "Could not bind SQLite value."])
        }
    }

    private func sqliteError(_ database: OpaquePointer?) -> Error {
        let message = database.map { String(cString: sqlite3_errmsg($0)) } ?? "SQLite error"
        return NSError(domain: "AirCard17.PosterBoard", code: 6, userInfo: [NSLocalizedDescriptionKey: message])
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
                    Button("Refresh PosterBoard") {
                        if manager.openPosterBoard() {
                            manager.log.append("PosterBoard opened. Close it from the app switcher, then reopen the wallpaper picker.")
                        } else {
                            manager.log.append("PosterBoard could not be opened. Reboot the phone and try again.")
                        }
                    }
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
