//
//  LaunchLocalDataSource.swift
//  TMinus
//
//  Created by Sadegh on 19/05/2026.
//

import SwiftData
import Foundation

// MARK: - LaunchLocalDataSource

protocol LaunchLocalDataSource: Sendable {
    func fetchUpcomingLaunches(query: LaunchListQuery, maxAge: TimeInterval?) async throws -> [Launch]
    func fetchPreviousLaunches(query: LaunchListQuery, maxAge: TimeInterval?) async throws -> [Launch]
    func fetchLaunchDetail(id: String, maxAge: TimeInterval?) async throws -> Launch?
    func save(_ launches: [Launch], fetchedAt: Date) async throws
    func save(_ launch: Launch, fetchedAt: Date) async throws
}

// MARK: - SwiftDataLaunchLocalDataSource

actor SwiftDataLaunchLocalDataSource: LaunchLocalDataSource {
    private let context: ModelContext

    init(container: ModelContainer) {
        self.context = ModelContext(container)
    }

    func fetchUpcomingLaunches(query: LaunchListQuery, maxAge: TimeInterval?) async throws -> [Launch] {
        let now = Date()
        let cutoff = cutoffDate(maxAge: maxAge)
        let searchText = query.searchText?.localizedLowercase

        let predicate: Predicate<LaunchLocalModel>
        if let searchText, !searchText.isEmpty {
            predicate = #Predicate<LaunchLocalModel> {
                $0.windowStart >= now
                    && $0.fetchedAt >= cutoff
                    && $0.name.localizedStandardContains(searchText)
            }
        } else {
            predicate = #Predicate<LaunchLocalModel> {
                $0.windowStart >= now
                    && $0.fetchedAt >= cutoff
            }
        }

        return try fetchLaunches(
            query: query,
            predicate: predicate,
            sortBy: [SortDescriptor(\LaunchLocalModel.windowStart, order: .forward)])
    }

    func fetchPreviousLaunches(query: LaunchListQuery, maxAge: TimeInterval?) async throws -> [Launch] {
        let now = Date()
        let cutoff = cutoffDate(maxAge: maxAge)
        let searchText = query.searchText?.localizedLowercase

        let predicate: Predicate<LaunchLocalModel>
        if let searchText, !searchText.isEmpty {
            predicate = #Predicate<LaunchLocalModel> {
                $0.windowStart < now
                    && $0.fetchedAt >= cutoff
                    && $0.name.localizedStandardContains(searchText)
            }
        } else {
            predicate = #Predicate<LaunchLocalModel> {
                $0.windowStart < now
                    && $0.fetchedAt >= cutoff
            }
        }

        return try fetchLaunches(
            query: query,
            predicate: predicate,
            sortBy: [SortDescriptor(\LaunchLocalModel.windowStart, order: .reverse)])
    }

    func fetchLaunchDetail(id: String, maxAge: TimeInterval?) async throws -> Launch? {
        let cutoff = cutoffDate(maxAge: maxAge)
        var descriptor = FetchDescriptor<LaunchLocalModel>(
            predicate: #Predicate<LaunchLocalModel> {
                $0.id == id && $0.fetchedAt >= cutoff
            })
        descriptor.fetchLimit = 1
        guard let model = try context.fetch(descriptor).first else {
            return nil
        }
        return LaunchLocalModelMapper.map(model)
    }

    func save(_ launches: [Launch], fetchedAt: Date) async throws {
        // One batch fetch for all existing rows instead of one fetch per launch, so saving a
        // page of N launches costs a single query rather than N. Mutated in place as we iterate
        // so a duplicate id within the same batch is treated as an update to the row just
        // inserted/updated in this loop, not a second insert of the same id.
        var existingByID = try fetchModels(ids: Set(launches.map(\.id)))

        for launch in launches {
            if let existing = existingByID[launch.id] {
                LaunchLocalModelMapper.update(existing, from: launch, fetchedAt: fetchedAt)
            } else {
                let model = LaunchLocalModelMapper.map(launch, fetchedAt: fetchedAt)
                context.insert(model)
                existingByID[launch.id] = model
            }
        }
        try context.save()
    }

    func save(_ launch: Launch, fetchedAt: Date) async throws {
        try upsert(launch, fetchedAt: fetchedAt)
        try context.save()
    }
}

extension SwiftDataLaunchLocalDataSource {
    private func fetchLaunches(query: LaunchListQuery,
                               predicate: Predicate<LaunchLocalModel>,
                               sortBy: [SortDescriptor<LaunchLocalModel>]) throws -> [Launch] {
        var descriptor = FetchDescriptor<LaunchLocalModel>(predicate: predicate, sortBy: sortBy)
        descriptor.fetchOffset = max((query.page - 1) * query.limit, 0)
        descriptor.fetchLimit = max(query.limit, 1)

        return try context.fetch(descriptor).map(LaunchLocalModelMapper.map(_:))
    }

    private func cutoffDate(maxAge: TimeInterval?) -> Date {
        guard let maxAge else { return .distantPast }
        return Date().addingTimeInterval(-maxAge)
    }

    private func upsert(_ launch: Launch, fetchedAt: Date) throws {
        if let existing = try fetchModel(id: launch.id) {
            LaunchLocalModelMapper.update(existing, from: launch, fetchedAt: fetchedAt)
            return
        }

        let model = LaunchLocalModelMapper.map(launch, fetchedAt: fetchedAt)
        context.insert(model)
    }

    private func fetchModel(id: String) throws -> LaunchLocalModel? {
        var descriptor = FetchDescriptor<LaunchLocalModel>(
            predicate: #Predicate<LaunchLocalModel> { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    /// Batch equivalent of `fetchModel(id:)` — one query for all ids instead of one query each.
    private func fetchModels(ids: Set<String>) throws -> [String: LaunchLocalModel] {
        guard ids.isEmpty == false else { return [:] }
        let descriptor = FetchDescriptor<LaunchLocalModel>(
            predicate: #Predicate<LaunchLocalModel> { ids.contains($0.id) })
        let models = try context.fetch(descriptor)
        // uniquingKeysWith rather than uniqueKeysWithValues: if the store ever already has two
        // rows sharing an id (e.g. from data created before this method existed), this must not
        // crash — last-one-wins is an acceptable degradation for a cache, not corruption.
        return Dictionary(models.map { ($0.id, $0) }, uniquingKeysWith: { _, latest in latest })
    }
}
