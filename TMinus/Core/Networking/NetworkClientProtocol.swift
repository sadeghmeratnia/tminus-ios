//
//  NetworkClientProtocol.swift
//  TMinus
//
//  Created by Sadegh on 22/04/2026.
//

import Foundation

protocol NetworkClientProtocol {
    func requestData(endpoint: Endpoint) async throws -> Data
    func request<T: Decodable & Sendable>(_ type: T.Type, endpoint: Endpoint) async throws -> T
}
