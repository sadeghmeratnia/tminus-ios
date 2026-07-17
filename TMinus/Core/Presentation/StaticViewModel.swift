//
//  StaticViewModel.swift
//  TMinus
//
//  Created by Sadegh on 28/05/2026.
//

import Combine

@MainActor
final class StaticViewModel<State, Trigger>: ViewModelProtocol {
    @Published private(set) var state: State
    init(state: State) {
        self.state = state
    }

    func onTrigger(_: Trigger) {}
}
