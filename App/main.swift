import SwiftUI

if CommandLine.arguments.last == NativeHost.extensionID { NativeHost.serve() }
NativeHost.installManifest()
GiveMeSubApp.main()
