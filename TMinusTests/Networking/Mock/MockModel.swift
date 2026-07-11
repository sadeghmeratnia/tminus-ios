//
//  MockModel.swift
//  TMinus
//
//  Created by Sadegh on 05/05/2026.
//

@testable import TMinus
import Foundation

struct MockModel: Codable, Equatable, Sendable {
    let id: Int
    let name: String
}
