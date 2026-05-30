import SwiftUI

struct QualityPicker: View {
    @Binding var selection: DownloadQuality

    var body: some View {
        Menu {
            ForEach(DownloadQuality.allCases) { quality in
                Button {
                    selection = quality
                } label: {
                    Label(quality.title, systemImage: selection == quality ? "checkmark" : "circle")
                }
                .help(quality.detail)
            }
        } label: {
            Label(selection.title, systemImage: "slider.horizontal.3")
        }
        .menuStyle(.borderlessButton)
        .help(selection.detail)
    }
}

