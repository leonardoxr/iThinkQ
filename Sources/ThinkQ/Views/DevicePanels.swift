import SwiftUI

struct ClimatePanel: View {
    let status: DeviceStatus?

    var body: some View {
        HStack(spacing: 16) {
            GaugeCard(title: "Current", value: status?.firstNumber("temperature.currentTemperature", "temperatureInUnits[0].currentTemperature") ?? 24, range: 0...40, unit: unit, tint: .cyan)
            GaugeCard(title: "Target", value: status?.firstNumber("temperature.targetTemperature", "temperatureInUnits[0].targetTemperature") ?? 23, range: 16...30, unit: unit, tint: .orange)
            AirflowCard(strength: status?.firstText("airFlow.windStrengthDetail", "airFlow.windStrength") ?? "AUTO")
            MetricCard(title: "Mode", value: (status?.firstText("operation.airConOperationMode", "airConJobMode.currentJobMode") ?? "Ready").thinkQTitleCasedValue, symbol: "power", tint: .green)
        }
    }

    private var unit: String {
        status?.firstText("temperature.unit", "temperatureInUnits[0].unit") ?? "C"
    }
}

struct AirPanel: View {
    let status: DeviceStatus?

    var body: some View {
        HStack(spacing: 16) {
            AirflowCard(strength: status?.values["airFlow.windStrength"]?.displayText ?? "AUTO")
            MetricCard(title: "Humidity", value: status?.values["airQualitySensor.humidity"]?.displayText ?? "Balanced", symbol: "humidity", tint: .green)
            MetricCard(title: "Filter", value: status?.values["filterInfo.filterRemainPercent"]?.displayText ?? "Healthy", symbol: "aqi.medium", tint: .mint)
        }
    }
}

struct LaundryPanel: View {
    let status: DeviceStatus?

    var body: some View {
        HStack(spacing: 16) {
            CycleProgressCard(progress: 0.64, remaining: status?.values["timer.remaining"]?.displayText ?? "42 min")
            MetricCard(title: "State", value: (status?.firstText("runState.currentState", "connection.error") ?? "Ready").thinkQTitleCasedValue, symbol: "washer", tint: status?.isAvailable == false ? .orange : .indigo)
            MetricCard(title: "Remote", value: (status?.firstText("remoteControlEnable.remoteControlEnabled") ?? "Unknown").thinkQTitleCasedValue, symbol: "dot.radiowaves.left.and.right", tint: .green)
        }
    }
}

struct RefrigeratorPanel: View {
    let status: DeviceStatus?

    var body: some View {
        HStack(spacing: 16) {
            GaugeCard(title: "Fridge", value: number("temperature.fridgeTargetTemperature") ?? 3, range: -2...8, unit: "C", tint: .mint)
            GaugeCard(title: "Freezer", value: number("temperature.freezerTargetTemperature") ?? -18, range: -24...0, unit: "C", tint: .blue)
            MetricCard(title: "Fresh Filter", value: "Normal", symbol: "leaf", tint: .green)
        }
    }

    private func number(_ key: String) -> Double? {
        if case .number(let value)? = status?.values[key] { value } else { nil }
    }
}

struct RobotPanel: View {
    let status: DeviceStatus?

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.regularMaterial)
                VStack(spacing: 12) {
                    Image(systemName: "map")
                        .font(.largeTitle)
                        .foregroundStyle(.teal)
                    Text("Docked and ready")
                        .font(.headline)
            Text((status?.values["operation.mode"]?.displayText ?? "Route clear").thinkQTitleCasedValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(minHeight: 160)
            MetricCard(title: "Battery", value: "86%", symbol: "battery.75percent", tint: .green)
            MetricCard(title: "Cleaning", value: "Quiet", symbol: "sparkles", tint: .teal)
        }
    }
}

struct GenericDevicePanel: View {
    let profile: DeviceProfile?
    let status: DeviceStatus?

    var body: some View {
        HStack(spacing: 16) {
            MetricCard(title: "Capabilities", value: "\(profile?.capabilities.count ?? 0)", symbol: "switch.2", tint: .blue)
            MetricCard(title: "Writable", value: "\(profile?.writableCapabilities.count ?? 0)", symbol: "slider.horizontal.3", tint: .orange)
            MetricCard(title: "Status", value: "\(status?.values.count ?? 0) values", symbol: "waveform.path.ecg", tint: .green)
        }
    }
}

struct GaugeCard: View {
    let title: String
    let value: Double
    let range: ClosedRange<Double>
    let unit: String
    let tint: Color

    var body: some View {
        VStack(spacing: 12) {
            Gauge(value: value, in: range) {
                Text(title)
            } currentValueLabel: {
                Text("\(Int(value)) \(unit)")
                    .font(.title2.bold())
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .tint(tint)
            Text(title)
                .font(.headline)
            Text("\(Int(range.lowerBound))-\(Int(range.upperBound)) \(unit)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 160)
        .padding()
        .thinkQGlassSurface()
    }
}

struct AirflowCard: View {
    let strength: String

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                ForEach(0..<3) { index in
                    Circle()
                        .trim(from: 0.12, to: 0.88)
                        .stroke(.cyan.opacity(0.25 + Double(index) * 0.18), lineWidth: 4)
                        .frame(width: CGFloat(62 + index * 22), height: CGFloat(62 + index * 22))
                        .rotationEffect(.degrees(Double(index) * 18))
                }
                Image(systemName: "wind")
                    .font(.title)
                    .foregroundStyle(.cyan)
            }
            .frame(height: 92)
            Text("Air Flow")
                .font(.headline)
            Text(strength.thinkQTitleCasedValue)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 160)
        .padding()
        .thinkQGlassSurface()
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: symbol)
                .font(.title)
                .foregroundStyle(tint)
            Spacer()
            Text(value)
                .font(.title2.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 160, alignment: .leading)
        .padding()
        .thinkQGlassSurface()
    }
}

struct CycleProgressCard: View {
    let progress: Double
    let remaining: String

    var body: some View {
        VStack(spacing: 12) {
            Gauge(value: progress) {
                Text("Cycle")
            } currentValueLabel: {
                Text("\(Int(progress * 100))%")
                    .font(.title2.bold())
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .tint(.indigo)
            Text("Laundry Cycle")
                .font(.headline)
            Text("\(remaining) remaining")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 160)
        .padding()
        .thinkQGlassSurface()
    }
}
