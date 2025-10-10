//
//  bmomApp.swift
//  bmom
//

import SwiftUI

@main
struct bmomApp: App {
    private let connectivityModel = PhoneConnectivityModel()
    var body: some Scene {
        WindowGroup {
            ContentView(connectivityModel: connectivityModel)
        }
    }
}
