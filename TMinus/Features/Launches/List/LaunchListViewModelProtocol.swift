//
//  LaunchListViewModelProtocol.swift
//  TMinus
//
//  Created by Sadegh on 28/05/2026.
//

import Foundation

@MainActor
protocol LaunchListViewModelProtocol: ViewModelProtocol
    where State == LaunchListState, Trigger == LaunchListTrigger {}

extension LaunchListViewModel: LaunchListViewModelProtocol {}

extension StaticViewModel: LaunchListViewModelProtocol
    where State == LaunchListState, Trigger == LaunchListTrigger {}
