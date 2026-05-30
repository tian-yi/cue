import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 260)
        } detail: {
            mainSurface
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HelperBadge(status: appModel.helperStatus)
            }
        }
    }

    @ViewBuilder
    private var mainSurface: some View {
        if shouldShowPlayerSplit {
            HSplitView {
                sectionView
                    .frame(minWidth: 520, idealWidth: 680)

                VideoDetailView()
                    .frame(minWidth: 520)
            }
        } else {
            sectionView
        }
    }

    @ViewBuilder
    private var sectionView: some View {
        switch appModel.selectedSection {
        case .search:
            SearchResultsView()
        case .downloads:
            DownloadsView()
        case .library:
            LibraryView()
        }
    }

    private var shouldShowPlayerSplit: Bool {
        guard appModel.selectedVideo != nil else {
            return false
        }

        switch appModel.selectedSection {
        case .search, .library:
            return true
        case .downloads:
            return false
        }
    }
}

private struct HelperBadge: View {
    let status: HelperStatus

    var body: some View {
        Label(status.title, systemImage: status.isAvailable ? "checkmark.circle" : "exclamationmark.triangle")
            .labelStyle(.titleAndIcon)
            .foregroundStyle(status.isAvailable ? Color.secondary : Color.orange)
    }
}
