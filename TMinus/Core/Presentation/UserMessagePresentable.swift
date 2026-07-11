//
//  UserMessagePresentable.swift
//  TMinus
//
//  Created by Sadegh on 01/07/2026.
//

import Foundation

// MARK: - UserMessagePresentable

/// An error that can present a localised, user-facing message.
/// ViewModels catch this protocol rather than any feature-specific error type,
/// keeping the presentation layer decoupled from domain error details.
protocol UserMessagePresentable: Error {
    var userMessage: String { get }
}
