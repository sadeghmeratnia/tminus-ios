//
//  TMinusApp.swift
//  TMinus
//
//  Created by Sadegh on 22/04/2026.
//

import SwiftUI

@main
struct TMinusApp: App {
    private let container = DIContainer()

    var body: some Scene {
        WindowGroup {
            ContentView(container: container)
        }
    }
}
