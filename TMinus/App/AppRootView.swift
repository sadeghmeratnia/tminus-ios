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
                    Label(L10n.Tabs.launches, systemImage: UIConstants.Icon.launchesTab)
                }

            newsRootView
                .tabItem {
                    Label(L10n.Tabs.news, systemImage: UIConstants.Icon.newsTab)
                }
        }
    }
}
