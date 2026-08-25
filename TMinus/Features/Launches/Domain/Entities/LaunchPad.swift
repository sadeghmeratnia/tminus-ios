//
//  LaunchPad.swift
//  TMinus
//
//  Created by Sadegh on 07/05/2026.
//

import Foundation

struct LaunchPad: Equatable, Sendable {
    let id: String
    let name: String
    /// `nil` when the API didn't supply a coordinate, kept optional rather than defaulted to
    /// `0`, since `(0, 0)` ("Null Island") is itself a real, valid coordinate and would otherwise
    /// be indistinguishable from an actual pad located there.
    let latitude: Double?
    let longitude: Double?
    let locationName: String?
}
