import SwiftUI

if CommandLine.arguments.count > 1 { NativeHost.serve() }
NativeHost.installManifest()
GiveMeSubApp.main()
