#if os(iOS)
import UIKit
public typealias PlatformViewController = UIViewController
#elseif os(macOS)
import AppKit
public typealias PlatformViewController = NSWindow
#endif
