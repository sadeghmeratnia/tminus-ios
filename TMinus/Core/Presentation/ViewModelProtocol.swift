//
//  ViewModelProtocol.swift
//  TMinus
//
//  Created by Sadegh on 07/05/2026.
//

import Combine

@MainActor
protocol ViewModelProtocol: ObservableObject {
    associatedtype State
    associatedtype Trigger

    var state: State { get }
    func onTrigger(_ trigger: Trigger)
}
