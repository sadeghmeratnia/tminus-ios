//
//  LaunchStatus.swift
//  TMinus
//
//  Created by Sadegh on 07/05/2026.
//

import Foundation

enum LaunchStatus: Equatable {
    case go
    case toBeDetermined
    case hold
    case success
    case failure
    case unknown(String?)
}
