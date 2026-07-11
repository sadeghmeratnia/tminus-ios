//
//  NewsDetailViewModelProtocol.swift
//  TMinus
//
//  Created by Sadegh on 09/07/2026.
//

import Foundation

@MainActor
protocol NewsDetailViewModelProtocol: ViewModelProtocol
    where State == NewsDetailState, Trigger == NewsDetailTrigger {}

extension NewsDetailViewModel: NewsDetailViewModelProtocol {}

extension StaticViewModel: NewsDetailViewModelProtocol
    where State == NewsDetailState, Trigger == NewsDetailTrigger {}
