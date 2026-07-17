//
//  NetworkClientProtocol.swift
//  TMinus
//
//  Created by Sadegh on 22/04/2026.
//

import Foundation

// MARK: - NetworkClientProtocol

protocol NetworkClientProtocol: Sendable {
    func requestData(endpoint: Endpoint, cachePolicy: FetchPolicy) async throws -> Data
    func request<T: Decodable & Sendable>(_ type: T.Type, endpoint: Endpoint, cachePolicy: FetchPolicy) async throws -> T
}

extension NetworkClientProtocol {
    func requestData(endpoint: Endpoint) async throws -> Data {
        try await requestData(endpoint: endpoint, cachePolicy: .useCache)
    }

    func request<T: Decodable & Sendable>(_ type: T.Type, endpoint: Endpoint) async throws -> T {
        try await request(type, endpoint: endpoint, cachePolicy: .useCache)
    }
}
