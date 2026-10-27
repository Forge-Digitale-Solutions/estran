import EstranCore
import SwiftData
import SwiftUI

@main
struct EstranApp: App {
    private let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try EstranModelContainer.make()
        } catch {
            fatalError("Unable to create the Estran SwiftData container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(modelContainer)
    }
}
