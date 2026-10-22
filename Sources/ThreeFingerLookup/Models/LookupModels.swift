import Foundation

enum DictionaryTarget: String, CaseIterable, Identifiable {
    case eudic
    case goldenDict

    var id: String { rawValue }

    var title: String {
        switch self {
        case .eudic: return "欧路词典"
        case .goldenDict: return "GoldenDict-ng"
        }
    }

    var scheme: String {
        switch self {
        case .eudic: return "eudic"
        case .goldenDict: return "goldendict"
        }
    }

    var bundleIdentifier: String {
        switch self {
        case .eudic: return "com.eusoft.eudic"
        case .goldenDict: return "org.xiaoyifang"
        }
    }
}

enum PermissionState {
    case granted
    case missing
    case unknown

    var title: String {
        switch self {
        case .granted: return "已允许"
        case .missing: return "需要授权"
        case .unknown: return "检查中"
        }
    }
}

enum GestureCheckFrequency: String, CaseIterable, Identifiable {
    case veryFrequent
    case frequent
    case normal
    case infrequent

    var id: String { rawValue }

    var title: String {
        switch self {
        case .veryFrequent: return "非常频繁"
        case .frequent: return "频繁"
        case .normal: return "正常"
        case .infrequent: return "不频繁"
        }
    }

    var interval: TimeInterval {
        switch self {
        case .veryFrequent: return 1
        case .frequent: return 5
        case .normal: return 15
        case .infrequent: return 60
        }
    }

    var intervalTitle: String {
        switch self {
        case .veryFrequent: return "1 秒"
        case .frequent: return "5 秒"
        case .normal: return "15 秒"
        case .infrequent: return "60 秒"
        }
    }
}

struct LookupStatus {
    var message = "等待三指轻点"
    var isError = false
}
