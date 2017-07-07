//: Playground - noun: a place where people can play

import Cocoa
import Guise

_ = Guise.register(name: UUID(), container: Container.plugin, metadata: PluginType.editor) { Plugin1() as Plugin }
_ = Guise.register(name: UUID(), container: Container.plugin, metadata: PluginType.viewer) { Plugin2() as Plugin }
_ = Guise.register(name: UUID(), container: Container.plugin, metadata: PluginType.viewer) { Plugin3() as Plugin }

var viewerKeys = Guise.filter(metadata: PluginType.viewer)
viewerKeys.count

