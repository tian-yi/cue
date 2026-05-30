import AppKit
import CoreImage.CIFilterBuiltins
import SwiftUI

struct RemoteControlView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                pairingPanel
                networkNotes
            }
            .padding(28)
            .frame(maxWidth: 760, alignment: .leading)
        }
        .navigationTitle("Remote")
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("LAN Remote")
                    .font(.largeTitle.weight(.semibold))
                Text("Control playback from a phone on the same Wi-Fi.")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("Enable", isOn: Binding(
                get: { appModel.remoteServerStatus.isEnabled || appModel.remoteServerStatus.isStarting },
                set: { enabled in
                    if enabled {
                        appModel.enableRemoteControl()
                    } else {
                        appModel.disableRemoteControl()
                    }
                }
            ))
            .toggleStyle(.switch)
            .disabled(appModel.remoteServerStatus.isStarting)
        }
    }

    @ViewBuilder
    private var pairingPanel: some View {
        let status = appModel.remoteServerStatus

        if status.isStarting {
            VStack(spacing: 14) {
                ProgressView()
                Text("Starting remote server")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 260)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        } else if status.isEnabled, let url = status.primaryURL {
            HStack(alignment: .top, spacing: 22) {
                QRCodeView(url: url)
                    .frame(width: 220, height: 220)
                    .padding(14)
                    .background(.white, in: RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 16) {
                    Label(connectionTitle, systemImage: status.connectedClients > 0 ? "checkmark.circle" : "iphone")
                        .font(.headline)
                        .foregroundStyle(status.connectedClients > 0 ? .green : .primary)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(url.absoluteString)
                            .font(.callout.monospaced())
                            .textSelection(.enabled)
                            .lineLimit(3)

                        if status.localURLs.count > 1 {
                            Text("Fallback: \(status.localURLs.dropFirst().map(\.absoluteString).joined(separator: ", "))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                                .textSelection(.enabled)
                        }
                    }

                    HStack {
                        Button {
                            copy(url)
                        } label: {
                            Label("Copy Link", systemImage: "doc.on.doc")
                        }

                        Button {
                            appModel.regenerateRemotePairingCode()
                        } label: {
                            Label("New Code", systemImage: "arrow.clockwise")
                        }

                        Button(role: .destructive) {
                            appModel.disableRemoteControl()
                        } label: {
                            Label("Disable", systemImage: "power")
                        }
                    }
                }
            }
            .padding(18)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        } else {
            VStack(alignment: .leading, spacing: 14) {
                Label("Remote is off", systemImage: "wifi.slash")
                    .font(.headline)

                Text("Enable it to show a QR code for your phone.")
                    .foregroundStyle(.secondary)

                Button {
                    appModel.enableRemoteControl()
                } label: {
                    Label("Enable Remote", systemImage: "iphone.radiowaves.left.and.right")
                }
                .buttonStyle(.borderedProminent)

                if let message = status.errorMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private var networkNotes: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Same Wi-Fi only", systemImage: "network")
                .font(.headline)

            Text("The remote is served by this Mac on your local network. The QR code includes a private pairing token, and disabling the remote invalidates it.")
                .foregroundStyle(.secondary)

            Text("If the phone cannot connect, check that both devices are on the same Wi-Fi and allow incoming connections if macOS asks.")
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }

    private var connectionTitle: String {
        let count = appModel.remoteServerStatus.connectedClients
        if count == 0 {
            return "Ready to pair"
        }
        return count == 1 ? "1 device connected" : "\(count) devices connected"
    }

    private func copy(_ url: URL) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.absoluteString, forType: .string)
    }
}

private struct QRCodeView: View {
    let url: URL

    var body: some View {
        if let image = makeQRCode(from: url.absoluteString) {
            Image(nsImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: "qrcode")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.black)
                .padding(28)
        }
    }

    private func makeQRCode(from string: String) -> NSImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else {
            return nil
        }

        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: 12, y: 12))
        let representation = NSCIImageRep(ciImage: scaledImage)
        let image = NSImage(size: representation.size)
        image.addRepresentation(representation)
        return image
    }
}
