//
//  OrientationLock.swift
//  Puttor
//
//  Which ways the app may turn. The tutorial holds it upright while it runs,
//  so its openings stay over what they point at; otherwise it turns the ways
//  the app supports.
//

import UIKit

enum OrientationLock {
    private(set) static var mask: UIInterfaceOrientationMask = defaultMask

    /// What the app turns to when nothing holds it: every way on an iPad,
    /// every way but upside down on a phone.
    static var defaultMask: UIInterfaceOrientationMask {
        UIDevice.current.userInterfaceIdiom == .pad ? .all : .allButUpsideDown
    }

    static func lock(portrait: Bool) {
        let newMask: UIInterfaceOrientationMask = portrait ? .portrait : defaultMask
        guard newMask != mask else { return }
        mask = newMask
        for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
            for window in scene.windows {
                window.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            }
            if portrait {
                scene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait)) { _ in }
            }
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        OrientationLock.mask
    }
}
