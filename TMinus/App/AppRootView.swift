//
//  AppRootView.swift
//  TMinus
//
//  Created by Sadegh on 30/06/2026.
//

import SwiftUI

struct AppRootView: View {
    let launchesRootView: LaunchesRootView
    let newsRootView: NewsRootView

    var body: some View {
        TabView {
            launchesRootView
                .tabItem {
                    Label(L10n.Tabs.launches, systemImage: Constants.Icon.launches)
                }

            newsRootView
                .tabItem {
                    Label(L10n.Tabs.news, systemImage: Constants.Icon.news)
                }
        }
    }
}

// MARK: - Constants

extension AppRootView {
    private enum Constants {
        enum Icon {
            static let launches = "airplane.departure"
            static let news = "newspaper"
        }
    }
}
