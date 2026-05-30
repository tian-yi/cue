import AppKit
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
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    appModel.disableRemoteControl()
                }
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

                Button("Show Remote") {
                    appModel.selectedSection = .remote
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
            }
        }

        Settings {
            SettingsView()
                .environmentObject(appModel)
                .frame(width: 560)
        }
    }
}
