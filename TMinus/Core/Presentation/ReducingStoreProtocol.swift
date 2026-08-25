//
//  ReducingStoreProtocol.swift
//  TMinus
//
//  Created by Sadegh on 07/05/2026.
//

import Foundation

// MARK: - ReducerProtocol

protocol ReducerProtocol {
    associatedtype State
    associatedtype Action
    associatedtype Effect

    static func reduce(state: State, action: Action) -> (state: State, effect: Effect?)
}

// MARK: - ReducingStoreProtocol

/// Names a store's reducer types without exposing its private `send` and `run` methods.
/// Public callers must go through `onTrigger`, where the ViewModel enforces its state guards.
protocol ReducingStoreProtocol: ViewModelProtocol {
    associatedtype Action
    associatedtype Effect
    associatedtype Reducer: ReducerProtocol
        where Reducer.State == State, Reducer.Action == Action, Reducer.Effect == Effect
}
