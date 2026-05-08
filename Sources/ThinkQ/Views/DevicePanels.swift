import SwiftUI

struct ClimatePanel: View {
    let status: DeviceStatus?

    var body: some View {
        PanelGrid {
            GaugeCard(title: "Room", value: status?.firstNumber("temperature.currentTemperature", "temperatureInUnits[0].currentTemperature"), fallback: "Waiting for sensor", range: 0...40, unit: unit, tint: .cyan)
            GaugeCard(title: "Target", value: status?.firstNumber(["temperature.targetTemperature", "temperature.coolTargetTemperature", "temperature.autoTargetTemperature", "temperatureInUnits[0].targetTemperature"]), fallback: "No target shared", range: 16...30, unit: unit, tint: .orange)
            AirflowCard(strength: status?.firstText("airFlow.windStrengthDetail", "airFlow.windStrength"))
            MetricCard(title: "Mode", value: status?.firstText("operation.airConOperationMode", "airConJobMode.currentJobMode")?.thinkQTitleCasedValue ?? "Waiting for status", symbol: "power", tint: status?.isAvailable == false ? .orange : .green)
        }
    }

    private var unit: String {
        status?.firstText("temperature.unit", "temperatureInUnits[0].unit") ?? "°C"
    }
}

struct AirPanel: View {
    let status: DeviceStatus?

    var body: some View {
        PanelGrid {
            AirflowCard(strength: status?.firstText("airFlow.windStrengthDetail", "airFlow.windStrength", "fanSpeed.currentFanSpeed"))
            MetricCard(title: "Humidity", value: status?.firstText("airQualitySensor.humidity", "humidity.currentHumidity") ?? "Waiting for sensor", symbol: "humidity", tint: .green)
            MetricCard(title: "Air Quality", value: status?.firstText("airQualitySensor.pm1", "airQualitySensor.pm25", "airQualitySensor.totalPollution") ?? "No reading", symbol: "aqi.medium", tint: .mint)
            MetricCard(title: "Filter", value: status?.firstText("filterInfo.filterRemainPercent", "filter.filterUsage", "filter.dustFilter") ?? "Not reported", symbol: "line.3.horizontal.decrease.circle", tint: .blue)
        }
    }
}

struct LaundryPanel: View {
    let status: DeviceStatus?

    var body: some View {
        PanelGrid {
            CycleProgressCard(progress: progress, remaining: remaining)
            MetricCard(title: "State", value: (status?.firstText("runState.currentState", "operation.currentState", "connection.error") ?? "Waiting for status").thinkQTitleCasedValue, symbol: "washer", tint: status?.isAvailable == false ? .orange : .indigo)
            MetricCard(title: "Cycle", value: (status?.firstText("course.currentCourse", "cycle.currentCycle", "process.currentCourse") ?? "Not reported").thinkQTitleCasedValue, symbol: "dial.medium", tint: .purple)
            MetricCard(title: "Remote", value: (status?.firstText("remoteControlEnable.remoteControlEnabled", "remoteControl.remoteControlEnabled") ?? "Unknown").thinkQTitleCasedValue, symbol: "dot.radiowaves.left.and.right", tint: .green)
        }
    }

    private var remaining: String {
        status?.firstText("timer.remaining", "timer.remainingTime", "time.remainingTime") ?? "No timer"
    }

    private var progress: Double? {
        if let percent = status?.firstNumber("cycle.progress", "process.progress", "timer.progress") {
            return percent > 1 ? percent / 100 : percent
        }
        return nil
    }
}

struct RefrigeratorPanel: View {
    let status: DeviceStatus?

    var body: some View {
        PanelGrid {
            GaugeCard(title: "Fridge", value: number("temperature.fridgeTargetTemperature", "temperature.fridgeCurrentTemperature"), fallback: "No fridge reading", range: -2...8, unit: "°C", tint: .mint)
            GaugeCard(title: "Freezer", value: number("temperature.freezerTargetTemperature", "temperature.freezerCurrentTemperature"), fallback: "No freezer reading", range: -24...0, unit: "°C", tint: .blue)
            MetricCard(title: "Door", value: (status?.firstText("doorState.doorState", "door.doorState", "doorState") ?? "Not reported").thinkQTitleCasedValue, symbol: "door.left.hand.open", tint: .orange)
            MetricCard(title: "Fresh Filter", value: (status?.firstText("filterInfo.freshAirFilter", "freshAirFilter.filterState", "filterInfo.filterRemainPercent") ?? "Not reported").thinkQTitleCasedValue, symbol: "leaf", tint: .green)
        }
    }

    private func number(_ keys: String...) -> Double? {
        status?.firstNumber(keys)
    }
}

struct RobotPanel: View {
    let status: DeviceStatus?

    var body: some View {
        PanelGrid {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.regularMaterial)
                VStack(spacing: 12) {
                    Image(systemName: "map")
                        .font(.largeTitle)
                        .foregroundStyle(.teal)
                    Text((status?.firstText("runState.currentState", "cleaningRobotState.currentState", "operation.mode") ?? "Waiting for status").thinkQTitleCasedValue)
                        .font(.headline)
                    Text((status?.firstText("location.currentPosition", "map.currentMap", "cleaning.currentMap") ?? "Map not shared").thinkQTitleCasedValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(minHeight: 160)
            MetricCard(title: "Battery", value: battery, symbol: "battery.75percent", tint: .green)
            MetricCard(title: "Cleaning", value: (status?.firstText("cleaning.mode", "cleaningMode.currentCleaningMode", "suctionPower.currentSuctionPower") ?? "Not reported").thinkQTitleCasedValue, symbol: "sparkles", tint: .teal)
        }
    }

    private var battery: String {
        if let value = status?.firstNumber("battery.percent", "battery.batteryPercent", "batteryStatus.batteryPercent") {
            return "\(Int(value))%"
        }
        return status?.firstText("battery.status", "batteryStatus.currentState")?.thinkQTitleCasedValue ?? "Unknown"
    }
}

struct GenericDevicePanel: View {
    let profile: DeviceProfile?
    let status: DeviceStatus?

    var body: some View {
        PanelGrid {
            MetricCard(title: "Capabilities", value: "\(profile?.capabilities.count ?? 0)", symbol: "switch.2", tint: .blue)
            MetricCard(title: "Writable", value: "\(profile?.writableCapabilities.count ?? 0)", symbol: "slider.horizontal.3", tint: .orange)
            MetricCard(title: "Status", value: "\(status?.values.count ?? 0) values", symbol: "waveform.path.ecg", tint: .green)
        }
    }
}

struct PanelGrid<Content: View>: View {
    @ViewBuilder var content: Content

    private let columns = [
        GridItem(.adaptive(minimum: 210, maximum: 280), spacing: 16)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
            content
        }
    }
}

struct GaugeCard: View {
    let title: String
    let value: Double?
    let fallback: String
    let range: ClosedRange<Double>
    let unit: String
    let tint: Color

    var body: some View {
        VStack(spacing: 12) {
            Gauge(value: value ?? range.lowerBound, in: range) {
                Text(title)
            } currentValueLabel: {
                Text(value.map { "\(Int($0)) \(unit)" } ?? "--")
                    .font(.title2.bold())
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .tint(tint)
            Text(title)
                .font(.headline)
            Text(value == nil ? fallback : "\(Int(range.lowerBound))-\(Int(range.upperBound)) \(unit)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 160)
        .padding()
        .thinkQGlassSurface()
    }
}

struct AirflowCard: View {
    let strength: String?

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
            Text((strength ?? "Waiting for status").thinkQTitleCasedValue)
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
    let progress: Double?
    let remaining: String

    var body: some View {
        VStack(spacing: 12) {
            Gauge(value: progress ?? 0) {
                Text("Cycle")
            } currentValueLabel: {
                Text(progress.map { "\(Int($0 * 100))%" } ?? "--")
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
