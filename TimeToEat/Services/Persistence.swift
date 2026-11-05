import Foundation
import SwiftData

enum Persistence {
    static let container: ModelContainer = {
        let schema = Schema([Medication.self, DoseLog.self])
        let config = ModelConfiguration(schema: schema)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("无法创建数据存储: \(error)")
        }
    }()
}

enum LaunchOptions {
    static var args: [String] { ProcessInfo.processInfo.arguments }
    static var demo: Bool { args.contains("-demo") }
    static var openAdd: Bool { args.contains("-add") }
    static var openRecord: Bool { args.contains("-record") }
    static var initialTab: Int {
        if let i = args.firstIndex(of: "-tab"), i + 1 < args.count, let v = Int(args[i + 1]) { return v }
        return 0
    }
}
