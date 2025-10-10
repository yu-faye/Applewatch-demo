//
//  ContentView.swift
//  bmom
//

import SwiftUI
import WatchConnectivity
import Combine

struct ContentView: View {
    @ObservedObject var connectivityModel: PhoneConnectivityModel

    var body: some View {
        VStack(spacing: 16) {
            Text("Health Data (from Watch)")
                .font(.headline)

            if let sample = connectivityModel.latestSample {
                VStack(spacing: 8) {
                    Text("Heart Rate: \(sample.heartRate) bpm")
                        .font(.title2)
                    Text("Steps: \(sample.steps)")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text("Time: \(formatted(date: sample.timestamp))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if let spo2 = sample.spo2 {
                        Text("SpO₂: \(spo2)%")
                            .foregroundStyle(.secondary)
                    }
                    if let sys = sample.systolic, let dia = sample.diastolic {
                        Text("BP: \(sys)/\(dia) mmHg")
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text("Waiting for watch data…")
                    .foregroundStyle(.secondary)
            }

            Button("Connect Watch") {
                connectivityModel.activateSession()
            }
            .buttonStyle(.borderedProminent)
            Divider()

            PregnancyDashboard()
        }
        .padding()
        .onAppear {
            connectivityModel.activateSession()
        }
    }

    private func formatted(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}
// MARK: - Pregnancy Dashboard

struct PregnancyDashboard: View {
    @State private var dueDate: Date = Calendar.current.date(byAdding: .day, value: 100, to: Date()) ?? Date()
    @State private var hydrationMl: Int = 0
    @State private var kicks: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pregnancy Essentials")
                .font(.headline)

            // Gestational age
            VStack(alignment: .leading, spacing: 6) {
                Text("Gestational Age")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(gestationalAgeString())
                    .font(.title3)
            }

            // Daily Tip
            VStack(alignment: .leading, spacing: 6) {
                Text("Daily Tip")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(dailyTip())
            }

            // Hydration tracker
            VStack(alignment: .leading, spacing: 6) {
                Text("Hydration")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack {
                    Button("+250ml") { hydrationMl += 250 }
                        .buttonStyle(.bordered)
                    Button("Reset") { hydrationMl = 0 }
                        .buttonStyle(.bordered)
                    Spacer()
                    Text("\(hydrationMl) ml")
                        .font(.title3)
                }
            }

            // Kick counter
            VStack(alignment: .leading, spacing: 6) {
                Text("Kick Counter")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack {
                    Button("+1") { kicks += 1 }
                        .buttonStyle(.borderedProminent)
                    Button("Reset") { kicks = 0 }
                        .buttonStyle(.bordered)
                    Spacer()
                    Text("\(kicks)")
                        .font(.title3)
                }
            }
        }
        .padding(.top, 8)
    }

    private func gestationalAgeString() -> String {
        let now = Date()
        let totalDays = 280 // 40w * 7
        let daysUntilDue = Calendar.current.dateComponents([.day], from: now, to: dueDate).day ?? 0
        let daysSinceConception = max(0, totalDays - max(0, daysUntilDue))
        let weeks = daysSinceConception / 7
        let days = daysSinceConception % 7
        return "\(weeks)w \(days)d (\(max(0, daysUntilDue)) days to due)"
    }

    private func dailyTip() -> String {
        let tips = [
            "Stay hydrated and take short walks.",
            "Practice gentle stretches and deep breathing.",
            "Aim for balanced meals rich in protein and fiber.",
            "Monitor fetal movements and rest when needed.",
            "Keep prenatal vitamins consistent each day."
        ]
        let idx = Calendar.current.component(.day, from: Date()) % tips.count
        return tips[idx]
    }
}

@MainActor
final class PhoneConnectivityModel: NSObject, ObservableObject, WCSessionDelegate {
    struct HealthSample {
        let heartRate: Int
        let steps: Int
        let timestamp: Date
        let spo2: Int?
        let systolic: Int?
        let diastolic: Int?
    }

    @Published var latestSample: HealthSample?

    func activateSession() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        if session.delegate == nil || !(session.delegate === self) {
            session.delegate = self
        }
        if session.activationState != .activated {
            session.activate()
        }
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        // No-op; ready to receive
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { WCSession.default.activate() }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        handleIncoming(payload: message)
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        handleIncoming(payload: userInfo)
    }

    private func handleIncoming(payload: [String: Any]) {
        guard let type = payload["type"] as? String, type == "health" else { return }
        let hr = payload["heartRate"] as? Int ?? 0
        let steps = payload["steps"] as? Int ?? 0
        let spo2 = payload["spo2"] as? Int
        let systolic = payload["systolic"] as? Int
        let diastolic = payload["diastolic"] as? Int
        let timeInterval = payload["time"] as? TimeInterval ?? Date().timeIntervalSince1970
        let date = Date(timeIntervalSince1970: timeInterval)
        let sample = HealthSample(heartRate: hr, steps: steps, timestamp: date, spo2: spo2, systolic: systolic, diastolic: diastolic)
        DispatchQueue.main.async { [weak self] in
            self?.latestSample = sample
        }
    }
}

#Preview {
    ContentView(connectivityModel: PhoneConnectivityModel())
}
