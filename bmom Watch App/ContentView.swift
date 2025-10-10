//
//  ContentView.swift
//  bmom Watch App
//

import SwiftUI
import Combine
import WatchConnectivity

struct ContentView: View {
    @StateObject private var generator = WatchHealthGenerator()
    var body: some View {
        VStack(spacing: 12) {
            Text("Watch Simulator")
                .font(.headline)
            if let sample = generator.latestSample {
                VStack(spacing: 6) {
                    Text("Heart Rate: \(sample.heartRate) bpm")
                        .font(.title3)
                    Text("Steps: \(sample.steps)")
                        .foregroundStyle(.secondary)
                    Text("SpO₂: \(sample.spo2)%")
                        .foregroundStyle(.secondary)
                    Text("BP: \(sample.systolic)/\(sample.diastolic) mmHg")
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("No data yet")
                    .foregroundStyle(.secondary)
            }
            HStack {
                Button(generator.isRunning ? "Stop" : "Start") {
                    generator.isRunning ? generator.stop() : generator.start()
                }
                .buttonStyle(.borderedProminent)

                Button("Send Now") {
                    generator.sendCurrentSample()
                }
                .buttonStyle(.bordered)
                .disabled(generator.latestSample == nil)
            }
        }
        .padding()
        .onAppear { generator.activateSession() }
    }
}

#Preview {
    ContentView()
}

@MainActor
final class WatchHealthGenerator: NSObject, ObservableObject, WCSessionDelegate {
    struct HealthSample {
        let heartRate: Int
        let steps: Int
        let spo2: Int
        let systolic: Int
        let diastolic: Int
    }

    @Published var latestSample: HealthSample?
    @Published var isRunning: Bool = false

    private var timer: Timer?

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

    func start() {
        guard !isRunning else { return }
        isRunning = true
        generateAndSend()
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.generateAndSend()
        }
    }

    func stop() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }

    func sendCurrentSample() {
        guard let sample = latestSample else { return }
        send(sample: sample)
    }

    private func generateAndSend() {
        let new = HealthSample(
            heartRate: Int.random(in: 60...140),
            steps: Int.random(in: 0...50),
            spo2: Int.random(in: 95...100),
            systolic: Int.random(in: 100...135),
            diastolic: Int.random(in: 60...85)
        )
        DispatchQueue.main.async { [weak self] in
            self?.latestSample = new
        }
        send(sample: new)
    }

    private func send(sample: HealthSample) {
        let payload: [String: Any] = [
            "type": "health",
            "heartRate": sample.heartRate,
            "steps": sample.steps,
            "spo2": sample.spo2,
            "systolic": sample.systolic,
            "diastolic": sample.diastolic,
            "time": Date().timeIntervalSince1970
        ]

        let session = WCSession.default
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil, errorHandler: nil)
        } else {
            session.transferUserInfo(payload)
        }
    }

    // MARK: - WCSessionDelegate
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
}
