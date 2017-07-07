import Foundation

public enum Container {
    case plugin
}

public protocol Plugin {
    
}

public enum PluginType {
    case viewer
    case editor
}

public struct Plugin1: Plugin {
    public init() {}
}

public struct Plugin2: Plugin {
    public init() {}
}

public struct Plugin3: Plugin {
    public init() {}
}
