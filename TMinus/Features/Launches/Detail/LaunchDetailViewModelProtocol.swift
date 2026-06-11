//
//  LaunchDetailViewModelProtocol.swift
//  TMinus
//
//  Created by Sadegh on 28/05/2026.
//

import Foundation

@MainActor
protocol LaunchDetailViewModelProtocol: ViewModelProtocol
    where State == LaunchDetailState, Trigger == LaunchDetailTrigger {}

extension LaunchDetailViewModel: LaunchDetailViewModelProtocol {}

extension StaticViewModel: LaunchDetailViewModelProtocol
    where State == LaunchDetailState, Trigger == LaunchDetailTrigger {}
