//
//  LaunchLocalDataSource.swift
//  TMinus
//
//  Created by Sadegh on 19/05/2026.
//

import SwiftData
import Foundation

// MARK: - LaunchLocalDataSource

protocol LaunchLocalDataSource {
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
        for launch in launches {
            try upsert(launch, fetchedAt: fetchedAt)
        }
        try self.context.save()
    }

    func save(_ launch: Launch, fetchedAt: Date) async throws {
        try upsert(launch, fetchedAt: fetchedAt)
        try self.context.save()
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
            self.update(existing, with: launch, fetchedAt: fetchedAt)
            return
        }

        let model = LaunchLocalModelMapper.map(launch, fetchedAt: fetchedAt)
        self.context.insert(model)
    }

    private func fetchModel(id: String) throws -> LaunchLocalModel? {
        var descriptor = FetchDescriptor<LaunchLocalModel>(
            predicate: #Predicate<LaunchLocalModel> { $0.id == id })
        descriptor.fetchLimit = 1
        return try self.context.fetch(descriptor).first
    }

    private func update(_ model: LaunchLocalModel, with launch: Launch, fetchedAt: Date) {
        let mapped = LaunchLocalModelMapper.map(launch, fetchedAt: fetchedAt)
        model.name = mapped.name
        model.statusCode = mapped.statusCode
        model.statusLabel = mapped.statusLabel
        model.windowStart = mapped.windowStart
        model.windowEnd = mapped.windowEnd
        model.rocketID = mapped.rocketID
        model.rocketName = mapped.rocketName
        model.padID = mapped.padID
        model.padName = mapped.padName
        model.padLatitude = mapped.padLatitude
        model.padLongitude = mapped.padLongitude
        model.padLocationName = mapped.padLocationName
        model.missionID = mapped.missionID
        model.missionName = mapped.missionName
        model.missionDescriptionText = mapped.missionDescriptionText
        model.missionType = mapped.missionType
        model.missionOrbit = mapped.missionOrbit
        model.imageURLString = mapped.imageURLString
        model.webcastURLString = mapped.webcastURLString
        model.fetchedAt = mapped.fetchedAt
    }
}
