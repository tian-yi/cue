import SwiftUI

@main
struct YTNoAdsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appModel = AppModel()

    var body: some Scene {
        WindowGroup("YT No Ads") {
            ContentView()
                .environmentObject(appModel)
                .frame(minWidth: 1040, minHeight: 680)
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("Search") {
                    appModel.performSearch()
                }
                .keyboardShortcut("l", modifiers: [.command])

                Button("Show Downloads") {
                    appModel.selectedSection = .downloads
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])
            }
        }

        Settings {
            SettingsView()
                .environmentObject(appModel)
                .frame(width: 560)
        }
    }
}

