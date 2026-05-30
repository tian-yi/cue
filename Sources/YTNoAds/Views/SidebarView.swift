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
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("YT No Ads")
    }
}
