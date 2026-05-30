import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        List(selection: $appModel.selectedSection) {
            Section {
                ForEach(AppSection.allCases) { section in
                    Label(section.title, systemImage: section.systemImage)
                        .tag(section)
                }
            }

            Section("Status") {
                Label(appModel.helperStatus.title, systemImage: appModel.helperStatus.isAvailable ? "checkmark.circle" : "exclamationmark.triangle")
                    .foregroundStyle(appModel.helperStatus.isAvailable ? Color.secondary : Color.orange)

                Label("\(appModel.jobs.count) downloads", systemImage: "tray")
                    .foregroundStyle(.secondary)

                Label(remoteStatusTitle, systemImage: appModel.remoteServerStatus.isEnabled ? "wifi" : "wifi.slash")
                    .foregroundStyle(appModel.remoteServerStatus.isEnabled ? Color.green : Color.secondary)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Cue")
    }

    private var remoteStatusTitle: String {
        if appModel.remoteServerStatus.isStarting {
            return "Remote starting"
        }

        if appModel.remoteServerStatus.isEnabled {
            let count = appModel.remoteServerStatus.connectedClients
            return count == 1 ? "1 remote" : "\(count) remotes"
        }

        return "Remote off"
    }
}
