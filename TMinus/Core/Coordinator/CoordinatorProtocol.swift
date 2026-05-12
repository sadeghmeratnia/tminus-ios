//
//  CoordinatorProtocol.swift
//  TMinus
//
//  Created by Sadegh on 07/05/2026.
//

import SwiftUI

@MainActor
protocol CoordinatorProtocol {
    associatedtype RootView: View
    @ViewBuilder
    func makeRootView() -> RootView
}
