//
//  NetworkSession.swift
//  TMinus
//
//  Created by Sadegh on 05/05/2026.
//

import Foundation

// MARK: - NetworkSession

protocol NetworkSession {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

// MARK: - URLSession + NetworkSession

extension URLSession: NetworkSession { }
