//
//  NewsListViewModelProtocol.swift
//  TMinus
//
//  Created by Sadegh on 09/07/2026.
//

import Foundation

@MainActor
protocol NewsListViewModelProtocol: ViewModelProtocol
    where State == NewsListState, Trigger == NewsListTrigger {}

extension NewsListViewModel: NewsListViewModelProtocol {}

extension StaticViewModel: NewsListViewModelProtocol
    where State == NewsListState, Trigger == NewsListTrigger {}
