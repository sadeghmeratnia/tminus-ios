//
//  LaunchDetailViewModel.swift
//  TMinus
//
//  Created by Sadegh on 28/05/2026.
//

import Combine
import Foundation

@MainActor
final class LaunchDetailViewModel: ReducingStoreProtocol {
    typealias State = LaunchDetailState
    typealias Trigger = LaunchDetailTrigger
    typealias Action = LaunchDetailAction
    typealias Effect = LaunchDetailEffect
    typealias Reducer = LaunchDetailReducer

    @Published private(set) var state: State

    private let fetchLaunchDetailUseCase: FetchLaunchDetailUseCase
    private let fetchRelatedNewsUseCase: FetchRelatedNewsUseCase
    private var hasAppeared = false
    private let loadTasks = DetailLoadTaskCoordinator()
    /// The most recently started main-load `Task`, captured purely so `refresh()` can await it,
    /// see `ViewModelProtocol.refresh()`. Deliberately doesn't await the best-effort related-news
    /// load: that one never blocks the main content today (see `loadRelatedNews`'s doc comment),
    /// and `.refreshable`'s spinner shouldn't either.
    private var mainLoadTask: Task<Void, Never>?

    init(launchID: String,
         fetchLaunchDetailUseCase: FetchLaunchDetailUseCase,
         fetchRelatedNewsUseCase: FetchRelatedNewsUseCase)
    {
        state = .initial(launchID: launchID)
        self.fetchLaunchDetailUseCase = fetchLaunchDetailUseCase
        self.fetchRelatedNewsUseCase = fetchRelatedNewsUseCase
    }

    func onTrigger(_ trigger: Trigger) {
        switch trigger {
        case .onAppear:
            guard hasAppeared == false else { return }
            hasAppeared = true
            send(.appear)
            loadRelatedNews(fetchPolicy: .useCache)

        case .retry:
            // Mirrors `LaunchDetailReducer`'s own `.retry` guard (`case .error = state.phase`),
            // see `.refresh` below for why this ViewModel checks it too rather than trusting the
            // view to only ever send `.retry` from the error state.
            guard case .error = state.phase else { return }
            send(.retry)
            // `.retry` only ever fires because the *main* load errored, related news is loaded
            // independently on `.onAppear` and may well have already succeeded before that
            // happened. Re-fetching it here unconditionally would redundantly repeat a request
            // for data that's already correct on screen; only retry it if it never completed.
            // Checked via `relatedNewsHasLoaded`, not `relatedArticles.isEmpty`, a launch that
            // genuinely has zero related articles would otherwise look identical to "never
            // loaded" and get silently re-fetched on every single retry tap.
            if state.relatedNewsHasLoaded == false {
                loadRelatedNews(fetchPolicy: .useCache)
            }

        case .refresh:
            // Mirrors `LaunchDetailReducer`'s own `.refresh` guard (`case .loaded = state.phase`)
            // rather than sending the action unconditionally and relying on it being a no-op:
            // the view only ever exposes pull-to-refresh once `state.phase == .loaded`, but this
            // ViewModel shouldn't depend on the view being the sole thing enforcing that, without
            // this guard, a `.refresh` trigger reaching here in any other phase would still kick
            // off a network-only related-news reload even though the main refresh never started.
            guard case .loaded = state.phase else { return }
            send(.refresh)
            // Related news is best-effort and never blocks the main refresh, but a pull-to-
            // refresh should still bypass its cache the same way the launch itself does,
            // otherwise this section could sit stale for its full TTL with no way for the user
            // to force it, even though they just explicitly asked this screen to refresh.
            loadRelatedNews(fetchPolicy: .networkOnly)
        }
    }

    func cancelInFlightWork() {
        loadTasks.cancelAll()
        // A cancelled `.loading` main load means `hasAppeared` can no longer be trusted: the
        // `.task { onTrigger(.onAppear) }` that fires the next time this screen appears is this
        // screen's only way back out of `.idle`, and it's a silent no-op while `hasAppeared` stays
        // true. See `LaunchDetailReducer.cancelled` for the matching phase reset.
        if case .loading = state.phase {
            hasAppeared = false
        }
        send(.cancelled)
    }

    func refresh() async {
        onTrigger(.refresh)
        await mainLoadTask?.value
    }

    private func send(_ action: LaunchDetailAction) {
        let (newState, effect) = Reducer.reduce(state: state, action: action)
        state = newState
        if let effect {
            run(effect)
        }
    }

    private func run(_ effect: LaunchDetailEffect) {
        switch effect {
        case let .load(id, fetchPolicy, kind, generation):
            mainLoadTask = loadTasks.start(.main, owner: self) { `self` in
                let result: LaunchDetailLoadOutcome
                do {
                    result = try .success(await self.fetchLaunchDetailUseCase.execute(id: id, fetchPolicy: fetchPolicy))
                } catch is CancellationError {
                    return
                } catch let presentable as UserMessagePresentable {
                    result = .failure(presentable.userMessage)
                } catch {
                    result = .failure(L10n.Error.Network.unknown)
                }

                self.send(.loadResponse(result, kind: kind, generation: generation))
            }

        case let .loadRelatedNews(launchID, fetchPolicy, generation):
            loadTasks.start(.secondary, owner: self) { `self` in
                guard let articles = try? await self.fetchRelatedNewsUseCase.execute(
                    launchID: launchID,
                    fetchPolicy: fetchPolicy
                ) else {
                    return
                }

                guard Task.isCancelled == false else { return }
                self.send(.relatedNewsResponse(articles, generation: generation))
            }
        }
    }
}

// MARK: - Related news

extension LaunchDetailViewModel {
    /// Best-effort: never gates the main launch load, and a failure is silently dropped rather
    /// than surfaced, leaving whatever was already in `state.relatedArticles` untouched. That
    /// matters now that this can run as part of a refresh (not just the first load): overwriting
    /// with `[]` on failure would blank out articles that were already showing, just because the
    /// refresh happened to fail. On the first load `relatedArticles` is already `[]`, so silently
    /// doing nothing produces the same visible outcome it always did.
    ///
    /// Goes through `send`/`Reducer.reduce` like every other state transition rather than
    /// mutating `state` directly, see `LaunchDetailAction.startRelatedNewsLoad`'s doc comment.
    private func loadRelatedNews(fetchPolicy: FetchPolicy) {
        send(.startRelatedNewsLoad(fetchPolicy: fetchPolicy))
    }
}
