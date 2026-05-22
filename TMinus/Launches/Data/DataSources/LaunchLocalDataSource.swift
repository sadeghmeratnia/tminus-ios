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
        return try fetchLaunches(
            query: query,
            maxAge: maxAge,
            predicate: #Predicate<LaunchLocalModel> { $0.windowStart >= now },
            sortBy: [SortDescriptor(\LaunchLocalModel.windowStart, order: .forward)])
    }

    func fetchPreviousLaunches(query: LaunchListQuery, maxAge: TimeInterval?) async throws -> [Launch] {
        let now = Date()
        return try fetchLaunches(
            query: query,
            maxAge: maxAge,
            predicate: #Predicate<LaunchLocalModel> { $0.windowStart < now },
            sortBy: [SortDescriptor(\LaunchLocalModel.windowStart, order: .reverse)])
    }

    func fetchLaunchDetail(id: String, maxAge: TimeInterval?) async throws -> Launch? {
        var descriptor = FetchDescriptor<LaunchLocalModel>(
            predicate: #Predicate<LaunchLocalModel> { $0.id == id })
        descriptor.fetchLimit = 1
        guard let model = try context.fetch(descriptor).first else {
            return nil
        }
        guard isFresh(model: model, maxAge: maxAge, referenceDate: Date()) else {
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
                               maxAge: TimeInterval?,
                               predicate: Predicate<LaunchLocalModel>,
                               sortBy: [SortDescriptor<LaunchLocalModel>]) throws -> [Launch] {
        var descriptor = FetchDescriptor<LaunchLocalModel>(predicate: predicate, sortBy: sortBy)
        descriptor.fetchOffset = max((query.page - 1) * query.limit, 0)
        descriptor.fetchLimit = max(query.limit, 1)
        let referenceDate = Date()

        let allModels = try context.fetch(descriptor)
        let freshModels = allModels.filter { self.isFresh(model: $0, maxAge: maxAge, referenceDate: referenceDate) }

        if let searchText = query.searchText, searchText.isEmpty == false {
            let normalizedSearch = searchText.localizedLowercase
            return freshModels
                .filter { $0.name.localizedLowercase.contains(normalizedSearch) }
                .map(LaunchLocalModelMapper.map(_:))
        }

        return freshModels.map(LaunchLocalModelMapper.map(_:))
    }

    private func isFresh(model: LaunchLocalModel, maxAge: TimeInterval?, referenceDate: Date) -> Bool {
        guard let maxAge else { return true }
        return model.fetchedAt.addingTimeInterval(maxAge) > referenceDate
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
