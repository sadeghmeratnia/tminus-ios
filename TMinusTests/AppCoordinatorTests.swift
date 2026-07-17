//
//  AppCoordinatorTests.swift
//  TMinusTests
//
//  Created by Sadegh on 13/07/2026.
//

@testable import TMinus
import Testing
import Foundation

@MainActor
@Suite("AppCoordinator")
struct AppCoordinatorTests {
    @Test("makeRootView wires Launches and News together without crashing")
    func makeRootViewWiresBothFeatures() {
        let coordinator = AppCoordinator(container: .preview())

        _ = coordinator.makeRootView()
    }
}
