import SwiftUI
import CinderPlatform

@MainActor struct DeviceView: View {
    @ObservedObject var model: AppModel
    @State private var deviceDetails = false
    @State private var references = false

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 16) {
                VStack(spacing: 12) {
                    Panel(title: model.t("Output device"), compact: true) {
                        DevicePicker(model: model)
                        if let device = model.device {
                            Text(device.name).font(.headline).textSelection(.enabled)
                            OutputInfoRow(model: model, title: "Connection", value: model.t(device.connectionLabel))
                            OutputInfoRow(model: model, title: "Manufacturer", value: model.outputDetails?.manufacturer)
                            OutputInfoRow(model: model, title: "Current sample rate", value: model.outputDetails?.sampleRate.map(OutputDeviceInfoView.rate))
                            OutputInfoRow(model: model, title: "Device output channels", value: model.outputDetails?.outputChannels.map(String.init))
                            if model.audiophile {
                                OutputInfoRow(model: model, title: "Device identifier", value: device.uid)
                            }
                            HStack {
                                Text(model.t("Selected for Cinder playback")).font(.caption).foregroundStyle(.secondary)
                                Spacer()
                                Button(model.t("Device details…")) { deviceDetails = true }
                            }
                        } else {
                            Text(model.t("Choose an output to see its connection and audio format.")).foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, minHeight: 110, alignment: .center)
                        }
                        Text(model.t("Output selection is shared with Quick Play and the menu bar.")).font(.caption).foregroundStyle(.secondary)
                    }
                    Panel(title: model.t("Mac information"), compact: true) {
                        Text(model.macProfile?.name ?? model.modelIdentifier).font(.headline)
                        if model.audiophile { Text(model.modelIdentifier).font(.caption).textSelection(.enabled) }
                        Text(PlatformCompatibility.osDescription).foregroundStyle(.secondary)
                    }
                    Panel(title: model.t("Reference specifications"), compact: true) {
                        HStack {
                            Text(model.selectedDAC?.name ?? model.t("No reference profile")).lineLimit(2)
                            Spacer()
                            Button(model.t("View specifications…")) { references = true }
                        }
                        Text(model.t("Reference profiles are selected manually; they are not detected device information."))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }.frame(maxWidth: .infinity)
                VStack(spacing: 12) {
                    DigitalOutputView(model: model, detailed: true)
                    GainPresetView(model: model)
                }.frame(maxWidth: .infinity)
            }
            if !model.message.isEmpty {
                Text(model.message).font(.caption).foregroundStyle(.secondary).textSelection(.enabled).lineLimit(2).help(model.message)
            }
        }
        .onAppear { model.refreshOutputInfo() }
        .sheet(isPresented: $deviceDetails) {
            DetailSheet(title: model.t("Device information"), done: model.t("Done")) {
                OutputDeviceInfoView(model: model)
            }
        }
        .sheet(isPresented: $references) {
            DetailSheet(title: model.t("Reference specifications"), done: model.t("Done")) {
                OutputReferenceView(model: model)
            }
        }
    }
}

@MainActor private struct OutputInfoRow: View {
    @ObservedObject var model: AppModel
    let title: String
    let value: String?
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(model.t(title)).foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value ?? model.t("Not reported")).multilineTextAlignment(.trailing)
                .lineLimit(2).textSelection(.enabled).help(value ?? model.t("Not reported"))
        }
    }
}

@MainActor private struct OutputDeviceInfoView: View {
    @ObservedObject var model: AppModel
    static func rate(_ value: Double) -> String { String(format: "%.0f Hz", value) }
    private var availableRates: String {
        guard let ranges = model.outputDetails?.availableSampleRates, !ranges.isEmpty else { return model.t("Not reported") }
        return ranges.map { range in
            range.lowerBound == range.upperBound ? Self.rate(range.lowerBound) : Self.rate(range.lowerBound) + " – " + Self.rate(range.upperBound)
        }.joined(separator: " · ")
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let device = model.device {
                HStack {
                    Text(device.name).font(.title3.weight(.semibold))
                    Spacer()
                    Button(model.t("Refresh"), action: model.refreshOutputInfo)
                }
                OutputInfoRow(model: model, title: "Connection", value: model.t(device.connectionLabel))
                OutputInfoRow(model: model, title: "Manufacturer", value: model.outputDetails?.manufacturer)
                OutputInfoRow(model: model, title: "Current sample rate", value: model.outputDetails?.sampleRate.map(Self.rate))
                OutputInfoRow(model: model, title: "Device output channels", value: model.outputDetails?.outputChannels.map(String.init))
                Divider()
                Text(model.t("Device-supported sample rates")).font(.headline)
                Text(availableRates).textSelection(.enabled).lineLimit(5).help(availableRates)
                Text(model.t("Cinder plays stereo PCM at 32–192 kHz. Device-supported rates may extend beyond this range."))
                    .foregroundStyle(.secondary)
                Text(model.t("Device identifier")).font(.headline)
                Text(device.uid).font(.callout.monospaced()).textSelection(.enabled).lineLimit(3).help(device.uid)
                Text(model.t("Device information is reported by macOS. It does not measure sound pressure, analog voltage or a Bluetooth codec."))
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Text(model.t("Choose an output to see its connection and audio format.")).foregroundStyle(.secondary)
            }
        }
    }
}

@MainActor private struct OutputReferenceView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        HStack(alignment: .top, spacing: 22) {
            Panel(title: model.t("Reference specifications"), compact: true) {
                Picker(model.t("Reference specifications"), selection: $model.dacSelection) {
                    Text(model.t("No reference profile")).tag("")
                    ForEach(model.dacProfiles) { profile in Text(profile.name).tag(profile.name) }
                }.disabled(model.isLocked)
                if let profile = model.selectedDAC {
                    Text(profile.specification).textSelection(.enabled)
                    if let url = URL(string: profile.source) { Link(model.t("Specification source"), destination: url) }
                }
                Text(model.t("Reference profiles are selected manually; they are not detected device information."))
                Text(model.t("Profiles show reference specifications only. Selecting a device or profile does not change app gain."))
                Button(model.t("Save connected device"), action: model.saveConnectedDevice).disabled(model.device == nil)
                if !model.message.isEmpty { Text(model.message).foregroundStyle(.secondary).textSelection(.enabled) }
            }
            Panel(title: model.t("Mac information"), compact: true) {
                Text(model.macProfile?.name ?? model.modelIdentifier).font(.headline)
                Text(model.modelIdentifier + " · " + PlatformCompatibility.osDescription)
                Text(model.macProfile?.output ?? model.t("Unknown output specifications.")).textSelection(.enabled)
                if let source = model.macProfile?.source, let url = URL(string: source) { Link(model.t("Specification source"), destination: url) }
                Text(model.t("Published specifications are not measured sound pressure or current analog voltage."))
            }
        }
    }
}
