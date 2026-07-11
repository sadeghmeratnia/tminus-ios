//
//  L10n.swift
//  TMinus
//
//  Created by Sadegh on 07/05/2026.
//

import Foundation

enum L10n {
    enum Common {
        static var unknown: String {
            tr(.commonUnknown)
        }
    }

    enum Error {
        enum Network {
            static var unauthorized: String {
                tr(.errorNetworkUnauthorized)
            }

            static var rateLimited: String {
                tr(.errorNetworkRateLimited)
            }

            static var serverUnavailable: String {
                tr(.errorNetworkServerUnavailable)
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

        static var retryAction: String {
            tr(.launchesRetryAction)
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

        enum Detail {
            static var rocket: String {
                tr(.launchesDetailRocket)
            }

            static var launchPad: String {
                tr(.launchesDetailLaunchPad)
            }

            static var location: String {
                tr(.launchesDetailLocation)
            }

            static var windowStart: String {
                tr(.launchesDetailWindowStart)
            }

            static var mission: String {
                tr(.launchesDetailMission)
            }

            static var missionType: String {
                tr(.launchesDetailMissionType)
            }

            static var missionDescription: String {
                tr(.launchesDetailMissionDescription)
            }

            static var orbit: String {
                tr(.launchesDetailOrbit)
            }

            static var watchWebcast: String {
                tr(.launchesDetailWatchWebcast)
            }

            static var relatedNewsTitle: String {
                tr(.launchesDetailRelatedNewsTitle)
            }
        }
    }

    enum News {
        static var navigationTitle: String {
            tr(.newsNavigationTitle)
        }

        static var loading: String {
            tr(.newsLoading)
        }

        static var errorTitle: String {
            tr(.newsErrorTitle)
        }

        static var emptyTitle: String {
            tr(.newsEmptyTitle)
        }

        static var emptyDescription: String {
            tr(.newsEmptyDescription)
        }

        static var retryAction: String {
            tr(.newsRetryAction)
        }

        static var searchPrompt: String {
            tr(.newsSearchPrompt)
        }

        enum Detail {
            static var readFullArticle: String {
                tr(.newsDetailReadFullArticle)
            }
        }
    }

    enum Tabs {
        static var launches: String {
            tr(.tabsLaunches)
        }

        static var news: String {
            tr(.tabsNews)
        }
    }

    private enum Key: String {
        case commonUnknown = "common.unknown"
        case errorNetworkUnauthorized = "error.network.unauthorized"
        case errorNetworkRateLimited = "error.network.rate_limited"
        case errorNetworkServerUnavailable = "error.network.server_unavailable"
        case errorNetworkTransport = "error.network.transport"
        case errorNetworkDecoding = "error.network.decoding"
        case errorNetworkUnknown = "error.network.unknown"
        case launchesNavigationTitle = "launches.navigation.title"
        case launchesLoading = "launches.loading"
        case launchesErrorTitle = "launches.error.title"
        case launchesEmptyTitle = "launches.empty.title"
        case launchesEmptyDescription = "launches.empty.description"
        case launchesModePicker = "launches.mode.picker"
        case launchesRetryAction = "launches.retry_action"
        case launchesModeUpcoming = "launches.mode.upcoming"
        case launchesModePrevious = "launches.mode.previous"
        case launchesStatusGo = "launches.status.go"
        case launchesStatusTBD = "launches.status.tbd"
        case launchesStatusHold = "launches.status.hold"
        case launchesStatusSuccess = "launches.status.success"
        case launchesStatusFailure = "launches.status.failure"
        case launchesStatusUnknown = "launches.status.unknown"
        case launchesDetailRocket = "launches.detail.rocket"
        case launchesDetailLaunchPad = "launches.detail.launch_pad"
        case launchesDetailLocation = "launches.detail.location"
        case launchesDetailWindowStart = "launches.detail.window_start"
        case launchesDetailMission = "launches.detail.mission"
        case launchesDetailMissionType = "launches.detail.mission_type"
        case launchesDetailMissionDescription = "launches.detail.mission_description"
        case launchesDetailOrbit = "launches.detail.orbit"
        case launchesDetailWatchWebcast = "launches.detail.watch_webcast"
        case launchesDetailRelatedNewsTitle = "launches.detail.related_news_title"
        case newsNavigationTitle = "news.navigation.title"
        case newsLoading = "news.loading"
        case newsErrorTitle = "news.error.title"
        case newsEmptyTitle = "news.empty.title"
        case newsEmptyDescription = "news.empty.description"
        case newsRetryAction = "news.retry_action"
        case newsSearchPrompt = "news.search.prompt"
        case newsDetailReadFullArticle = "news.detail.read_full_article"
        case tabsLaunches = "tabs.launches"
        case tabsNews = "tabs.news"
    }

    private static func tr(_ key: Key) -> String {
        let localized = NSLocalizedString(key.rawValue, tableName: nil, bundle: .main, value: "", comment: "")
        #if DEBUG
            assert(localized.isEmpty == false, "Missing localization key: \(key.rawValue)")
        #endif
        return localized.isEmpty ? key.rawValue : localized
    }
}
