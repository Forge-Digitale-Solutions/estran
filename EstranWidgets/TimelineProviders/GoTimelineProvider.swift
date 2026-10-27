import Foundation
import WidgetKit

struct GoTimelineProvider: TimelineProvider {
    func placeholder(in _: Context) -> GoEntry {
        .placeholder
    }

    func getSnapshot(in _: Context, completion: @escaping (GoEntry) -> Void) {
        completion(.placeholder)
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<GoEntry>) -> Void) {
        completion(Timeline(entries: [.placeholder], policy: .never))
    }
}

extension GoEntry {
    static let placeholder = GoEntry(
        date: Date(),
        title: "Estran",
        answer: "—",
        detail: "M0 — Setup")
}
