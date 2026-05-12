//
//  ReducingStoreProtocol.swift
//  TMinus
//
//  Created by Sadegh on 07/05/2026.
//

import Foundation

public protocol ReducerProtocol {
    associatedtype State
    associatedtype Action
    associatedtype Effect

    static func reduce(state: State, action: Action) -> (state: State, effect: Effect?)
}

public protocol ReducingStoreProtocol: ViewModelProtocol {
    associatedtype Action
    associatedtype Effect
    associatedtype Reducer: ReducerProtocol
        where Reducer.State == State, Reducer.Action == Action, Reducer.Effect == Effect

    func send(_ action: Action)
    func run(_ effect: Effect)
}
