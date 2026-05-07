//
//  L10n.swift
//  TMinus
//
//  Created by Sadegh on 07/05/2026.
//

import Foundation

enum L10n {
    enum Error {
        enum Network {
            static var requestCreation: String {
                tr(.errorNetworkRequestCreation)
            }

            static var invalidResponse: String {
                tr(.errorNetworkInvalidResponse)
            }

            static var unauthorized: String {
                tr(.errorNetworkUnauthorized)
            }

            static var rateLimited: String {
                tr(.errorNetworkRateLimited)
            }

            static var serverUnavailable: String {
                tr(.errorNetworkServerUnavailable)
            }

            static var genericLoad: String {
                tr(.errorNetworkGenericLoad)
            }

            static var transport: String {
                tr(.errorNetworkTransport)
            }

            static var decoding: String {
                tr(.errorNetworkDecoding)
            }

            static var unknown: String {
                tr(.errorNetworkUnknown)
            }
        }
    }

    enum Launches {
        static var navigationTitle: String {
            tr(.launchesNavigationTitle)
        }

        static var loading: String {
            tr(.launchesLoading)
        }

        static var errorTitle: String {
            tr(.launchesErrorTitle)
        }

        static var emptyTitle: String {
            tr(.launchesEmptyTitle)
        }

        static var emptyDescription: String {
            tr(.launchesEmptyDescription)
        }

        static var modePicker: String {
            tr(.launchesModePicker)
        }

        enum Mode {
            static var upcoming: String {
                tr(.launchesModeUpcoming)
            }

            static var previous: String {
                tr(.launchesModePrevious)
            }
        }

        enum Status {
            static var go: String {
                tr(.launchesStatusGo)
            }

            static var tbd: String {
                tr(.launchesStatusTBD)
            }

            static var hold: String {
                tr(.launchesStatusHold)
            }

            static var success: String {
                tr(.launchesStatusSuccess)
            }

            static var failure: String {
                tr(.launchesStatusFailure)
            }

            static var unknown: String {
                tr(.launchesStatusUnknown)
            }
        }
    }

    private enum Key: String {
        case errorNetworkRequestCreation = "error.network.request_creation"
        case errorNetworkInvalidResponse = "error.network.invalid_response"
        case errorNetworkUnauthorized = "error.network.unauthorized"
        case errorNetworkRateLimited = "error.network.rate_limited"
        case errorNetworkServerUnavailable = "error.network.server_unavailable"
        case errorNetworkGenericLoad = "error.network.generic_load"
        case errorNetworkTransport = "error.network.transport"
        case errorNetworkDecoding = "error.network.decoding"
        case errorNetworkUnknown = "error.network.unknown"
        case launchesNavigationTitle = "launches.navigation.title"
        case launchesLoading = "launches.loading"
        case launchesErrorTitle = "launches.error.title"
        case launchesEmptyTitle = "launches.empty.title"
        case launchesEmptyDescription = "launches.empty.description"
        case launchesModePicker = "launches.mode.picker"
        case launchesModeUpcoming = "launches.mode.upcoming"
        case launchesModePrevious = "launches.mode.previous"
        case launchesStatusGo = "launches.status.go"
        case launchesStatusTBD = "launches.status.tbd"
        case launchesStatusHold = "launches.status.hold"
        case launchesStatusSuccess = "launches.status.success"
        case launchesStatusFailure = "launches.status.failure"
        case launchesStatusUnknown = "launches.status.unknown"
    }

    private static func tr(_ key: Key) -> String {
        let localized = NSLocalizedString(key.rawValue, tableName: nil, bundle: .main, value: "", comment: "")
        #if DEBUG
            assert(localized.isEmpty == false, "Missing localization key: \(key.rawValue)")
        #endif
        return localized.isEmpty ? key.rawValue : localized
    }
}
