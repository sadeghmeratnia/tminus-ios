# tminus-ios
A native iOS app for tracking rocket launches, space events &amp; astronauts. built with Clean Architecture, MVVM-C, and SwiftUI.

## Architecture

Each feature (`Launches`, `News`) is organized into three layers:

- **Data**: `DTOs` (wire format, `Decodable`), `DataSources` (remote via `URLSession`, local via
  SwiftData), `Mappers` (DTO ↔ domain, and domain ↔ SwiftData local model), and a `Repository`
  that composes the two data sources: a `.useCache` request is served from the SwiftData cache
  first (falling back to network on a miss), and any read may fall back to a stale cached row if
  the network fails. See the doc comment on `LaunchRepository`/`NewsRepository` for the full
  caching rationale, including how this relates to the separate response-level `DataCache` inside
  `URLSessionNetworkClient`.
- **Domain**: plain `Entities` (no framework dependencies), a `RepositoryProtocol` each
  Repository conforms to, and one `UseCase` per screen-level operation. Use cases are thin
  pass-throughs today; they exist as the seam ViewModels depend on instead of a concrete
  repository, so a feature's business rules have somewhere to live if they grow past "call the
  repository."
- **Presentation**: a `State`/`Action`/`Effect` reducer (pure, testable in isolation) paired with
  a `@MainActor` ViewModel that translates UI `Trigger`s into `Action`s, runs the `Effect`s a
  reducer step returns, and republishes the resulting `State` for SwiftUI. Shared plumbing all
  features build on lives in `Core/Presentation`: `ListPhase`/`DetailPhase` (the loading/loaded/
  error state machine), `ListLoadGenerations`/`LoadGeneration` (guards against a superseded
  request's response clobbering newer state), and `TaskCoordinator` (tracks and cancels the named
  concurrent workloads a screen runs, e.g. a paginated list's `fresh` vs. `loadMore` loads).

Navigation is MVVM-C: each feature owns a `Coordinator` conforming to `CoordinatorProtocol`,
driving a `StackCoordinator`-managed `NavigationStack` via a feature-specific `Destination` enum.
`AppCoordinator` composes the per-feature coordinators into the app's root.

`Core/DI/AppContainer.swift` is the composition root, it's where concrete `URLSessionNetworkClient`,
`ModelContainer`, repositories, use cases, and coordinators actually get wired together.
`TMinusApp.bootstrap()` builds one `AppContainer` at launch (see `TMinusApp.swift` for how a
failed bootstrap, e.g. an unrecoverable SwiftData store, is surfaced instead of crashing).

### Adding a new feature

Following the shape of `Launches`/`News` end to end is the fastest way to see the full pattern:
DTO → local model → mapper → data source → repository → use case → reducer → ViewModel → view →
coordinator. Shared, feature-agnostic pieces (pagination, list/detail phase state machines, retry
policy, network client) belong in `Core`; anything specific to one feature's domain stays inside
that feature's own folder.

## Setup

- Requires Xcode 16+ (Swift 6 language mode, iOS 17.0 deployment target).
- Open `TMinus.xcodeproj` and build. Signing is set to Automatic, Xcode will prompt you to select
  your own team under the target's Signing & Capabilities tab before it can build for a device;
  the project ships pointing at the original author's team, which won't resolve on your machine.

## Testing

Both `TMinusTests` (unit) and `TMinusUITests` (UI) run via the `TMinus.xctestplan` test plan,
which is wired as the shared `TMinus` scheme's default plan, `cmd+U` or `xcodebuild test -scheme
TMinus` runs both. Unit tests use Swift Testing (`@Test`/`#expect`); UI tests use XCTest, as
required for `XCUIApplication` automation.

## Known landmines

- **Never put `.contains`/`.localizedStandardContains` inside a SwiftData `#Predicate`.** ICU
  string-collation support in compiled predicates crashes at runtime (a SIGSEGV, not a catchable
  Swift error). Both local data sources (`LaunchLocalDataSource`, `NewsLocalDataSource`) work
  around this by fetching first and filtering the search text in plain Swift afterwards, using a
  pre-lowercased field (`nameLowercased`/`titleLowercased`) stored alongside the searchable column
  specifically so that Swift-side filter never needs to re-lowercase per row. Keep new local-search
  code on the same pattern, a predicate that compiles and passes review can still crash at the
  first fetch.
