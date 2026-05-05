//
//  NetworkSession.swift
//  TMinus
//
//  Created by Sadegh on 05/05/2026.
//

import Foundation

protocol NetworkSession {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: NetworkSession {}
