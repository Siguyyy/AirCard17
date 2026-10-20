from pathlib import Path

root = Path(".")
airlift = root / "airlift"
legacy = root / "AirCard17"

content = airlift / "ios-app" / "ContentView.swift"
additions = []
for name in ("CommunityView.swift", "ImagePicker.swift", "LanguageManager.swift", "GitHubService.swift"):
    source = legacy / name
    text = source.read_text(encoding="utf-8-sig")
    text = "\n".join(line for line in text.splitlines() if not line.startswith("import "))
    additions.append("\n\n// Legacy AirCard17 UI overlay: " + name + "\n" + text)
content.write_text(content.read_text(encoding="utf-8") + "".join(additions), encoding="utf-8")

models = airlift / "ios-app" / "Models.swift"
text = models.read_text(encoding="utf-8")
text = text.replace(
    'case pairing = "Pairing"\n    case walletCards = "Wallet Cards"',
    'case walletCards = "Wallet Cards"\n    case community = "Community"\n    case pairing = "Pairing"'
)
models.write_text(text, encoding="utf-8")

vm = airlift / "ios-app" / "AppViewModel.swift"
text = vm.read_text(encoding="utf-8")
text = text.replace(
    '@Published var selectedTab: AppTab = .pairing',
    '@Published var selectedTab: AppTab = .walletCards'
)
vm.write_text(text, encoding="utf-8")

text = content.read_text(encoding="utf-8")
start = text.index('        TabView(selection: $vm.selectedTab) {')
end = text.index('        .alert("Notice", isPresented: Binding(', start)
shell = """        TabView(selection: $vm.selectedTab) {
            WalletCardsTab()
                .tabItem { Label("Cards", systemImage: "creditcard.fill") }
                .tag(AppTab.walletCards)

            CommunityView()
                .tabItem { Label("Community", systemImage: "globe") }
                .tag(AppTab.community)

            PairingTab()
                .tabItem { Label("Pairing", systemImage: "antenna.radiowaves.left.and.right") }
                .tag(AppTab.pairing)

            PasscodeThemeTab()
                .tabItem { Label("Passcode", systemImage: "lock.circle.fill") }
                .tag(AppTab.passcodeThemes)

            TendiesView()
                .tabItem { Label("Wallpapers", systemImage: "photo.stack.fill") }
                .tag(AppTab.wallpapers)
        }
"""
text = text[:start] + shell + text[end:]
text = text.replace(
    '        .sheet(isPresented: $showSupportPopup) {\n            SupportPopupSheet(dontShowOnLaunch: $dontShowSupportOnLaunch)\n        }\n',
    ''
)
content.write_text(text, encoding="utf-8")

info = airlift / "ios-app" / "Info.plist"
text = info.read_text(encoding="utf-8")
info.write_text(text.replace("<string>AirCard-iOS</string>", "<string>AirCard17</string>"), encoding="utf-8")
