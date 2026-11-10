import Foundation

/// One file in a sequential batch. The view only needs the name and state.
struct QueueItem: Equatable, Sendable {
    enum State: Equatable, Sendable {
        case pending
        case active
        case done
        case failed
    }

    let name: String
    var state: State
}
