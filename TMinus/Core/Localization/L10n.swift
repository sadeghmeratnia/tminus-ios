//
//  L10n.swift
//  TMinus
//
//  Created by Sadegh on 07/05/2026.
//

import Foundation

/// Every accessor resolves through `Localizable.xcstrings`' Xcode-generated `LocalizedStringResource`
/// symbols (`STRING_CATALOG_GENERATE_SYMBOLS = YES` on the app target) rather than a hand-maintained
/// string-keyed lookup, a catalog key that's renamed or removed fails the *build*, not a DEBUG-only
/// runtime assert, since each `.foo` below is a compiler-checked member of that generated extension.
enum L10n {
    enum Common {
        static var unknown: String {
            String(localized: .commonUnknown)
        }

        static var loadingMore: String {
            String(localized: .commonLoadingMore)
        }
    }

    enum AppLaunch {
        static var title: String {
            String(localized: .appLaunchTitle)
        }

        static var description: String {
            String(localized: .appLaunchDescription)
        }

        static var retryAction: String {
            String(localized: .appLaunchRetryAction)
        }
    }

    enum Error {
        enum Network {
            static var unauthorized: String {
                String(localized: .errorNetworkUnauthorized)
            }

            static var rateLimited: String {
                String(localized: .errorNetworkRateLimited)
            }

            static var serverUnavailable: String {
                String(localized: .errorNetworkServerUnavailable)
            }

            static var transport: String {
                String(localized: .errorNetworkTransport)
            }

            static var timeout: String {
                String(localized: .errorNetworkTimeout)
            }

            static var decoding: String {
                String(localized: .errorNetworkDecoding)
            }

            static var clientError: String {
                String(localized: .errorNetworkClientError)
            }

            static var unknown: String {
                String(localized: .errorNetworkUnknown)
            }
        }
    }

    enum Launches {
        static var navigationTitle: String {
            String(localized: .launchesNavigationTitle)
        }

        static var loading: String {
            String(localized: .launchesLoading)
        }

        static var errorTitle: String {
            String(localized: .launchesErrorTitle)
        }

        static var emptyTitle: String {
            String(localized: .launchesEmptyTitle)
        }

        static var emptyDescription: String {
            String(localized: .launchesEmptyDescription)
        }

        static var noResultsTitle: String {
            String(localized: .launchesNoResultsTitle)
        }

        static var noResultsDescription: String {
            String(localized: .launchesNoResultsDescription)
        }

        static var modePicker: String {
            String(localized: .launchesModePicker)
        }

        static var retryAction: String {
            String(localized: .launchesRetryAction)
        }

        static var searchPrompt: String {
            String(localized: .launchesSearchPrompt)
        }

        enum Mode {
            static var upcoming: String {
                String(localized: .launchesModeUpcoming)
            }

            static var previous: String {
                String(localized: .launchesModePrevious)
            }
        }

        enum Status {
            static var go: String {
                String(localized: .launchesStatusGo)
            }

            static var tbd: String {
                String(localized: .launchesStatusTbd)
            }

            static var hold: String {
                String(localized: .launchesStatusHold)
            }

            static var success: String {
                String(localized: .launchesStatusSuccess)
            }

            static var failure: String {
                String(localized: .launchesStatusFailure)
            }

            static var unknown: String {
                String(localized: .launchesStatusUnknown)
            }

            /// Prefix for `StatusPill`'s accessibility label, the pill's plain visible text
            /// (e.g. "Go", "Hold") reads as a bare, context-free word to VoiceOver wherever
            /// nothing nearby already establishes it's a launch status.
            static var accessibilityLabelPrefix: String {
                String(localized: .launchesStatusAccessibilityLabelPrefix)
            }
        }

        enum Detail {
            static var rocket: String {
                String(localized: .launchesDetailRocket)
            }

            static var launchPad: String {
                String(localized: .launchesDetailLaunchPad)
            }

            static var location: String {
                String(localized: .launchesDetailLocation)
            }

            static var windowStart: String {
                String(localized: .launchesDetailWindowStart)
            }

            static var windowEnd: String {
                String(localized: .launchesDetailWindowEnd)
            }

            static var mission: String {
                String(localized: .launchesDetailMission)
            }

            static var missionType: String {
                String(localized: .launchesDetailMissionType)
            }

            static var missionDescription: String {
                String(localized: .launchesDetailMissionDescription)
            }

            static var orbit: String {
                String(localized: .launchesDetailOrbit)
            }

            static var watchWebcast: String {
                String(localized: .launchesDetailWatchWebcast)
            }

            static var relatedNewsTitle: String {
                String(localized: .launchesDetailRelatedNewsTitle)
            }
        }
    }

    enum News {
        static var navigationTitle: String {
            String(localized: .newsNavigationTitle)
        }

        static var loading: String {
            String(localized: .newsLoading)
        }

        static var errorTitle: String {
            String(localized: .newsErrorTitle)
        }

        static var emptyTitle: String {
            String(localized: .newsEmptyTitle)
        }

        static var emptyDescription: String {
            String(localized: .newsEmptyDescription)
        }

        static var noResultsTitle: String {
            String(localized: .newsNoResultsTitle)
        }

        static var noResultsDescription: String {
            String(localized: .newsNoResultsDescription)
        }

        static var retryAction: String {
            String(localized: .newsRetryAction)
        }

        static var searchPrompt: String {
            String(localized: .newsSearchPrompt)
        }

        enum Detail {
            static var readFullArticle: String {
                String(localized: .newsDetailReadFullArticle)
            }
        }
    }

    enum Tabs {
        static var launches: String {
            String(localized: .tabsLaunches)
        }

        static var news: String {
            String(localized: .tabsNews)
        }
    }
}
