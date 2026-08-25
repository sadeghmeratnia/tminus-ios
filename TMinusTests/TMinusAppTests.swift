//
//  TMinusAppTests.swift
//  TMinusTests
//
//  Created by Sadegh on 23/07/2026.
//

import Foundation
import SwiftData
import Testing
@testable import TMinus

@Suite("TMinusApp")
struct TMinusAppTests {
    @Test("makeModelContainer succeeds for a fresh, non-existent store")
    func makeModelContainerSucceedsForFreshStore() throws {
        let storeURL = Self.makeTemporaryStoreURL()
        defer { Self.removeStoreFiles(at: storeURL) }

        let schema = Schema([LaunchLocalModel.self])
        let configuration = ModelConfiguration(schema: schema, url: storeURL)

        _ = try TMinusApp.makeModelContainer(schema: schema, configuration: configuration, storeURL: storeURL)
    }

    @Test("makeModelContainer recovers by resetting a corrupted store instead of throwing")
    func makeModelContainerRecoversFromCorruptedStore() throws {
        let storeURL = Self.makeTemporaryStoreURL()
        defer { Self.removeStoreFiles(at: storeURL) }

        // Not a valid SQLite store, simulates disk corruption / an unmigratable on-disk file.
        try Data("not a real store".utf8).write(to: storeURL)

        let schema = Schema([LaunchLocalModel.self])
        let configuration = ModelConfiguration(schema: schema, url: storeURL)

        _ = try TMinusApp.makeModelContainer(schema: schema, configuration: configuration, storeURL: storeURL)
    }
}

private extension TMinusAppTests {
    static func makeTemporaryStoreURL() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "TMinusAppTests-\(UUID().uuidString).store")
    }

    static func removeStoreFiles(at storeURL: URL) {
        // See `TMinusApp.makeModelContainer`, SQLite's real WAL sidecar files are
        // "<name>-shm"/"-wal" (suffixed onto the full filename), not a dot extension.
        try? FileManager.default.removeItem(at: storeURL)
        try? FileManager.default.removeItem(at: URL(fileURLWithPath: storeURL.path + "-shm"))
        try? FileManager.default.removeItem(at: URL(fileURLWithPath: storeURL.path + "-wal"))
    }
}
