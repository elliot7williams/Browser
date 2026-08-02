//
//  AppDelegate.swift
//  Browser
//
//  Created by Elliot Williams on 2025-06-29.
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        let defaults = UserDefaults.standard
        let mobileMode = defaults.bool(forKey: "MobileMode")
        
        if mobileMode {
            let userAgent = "Mozilla/5.0 (iPad; CPU OS 12_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.0 Mobile/15E148 Safari/604.1"
            defaults.register(defaults: ["UserAgent": userAgent])
            defaults.set(true, forKey: "MobileMode")
        } else {
            let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_6) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.0 Safari/605.1.15"
            defaults.register(defaults: ["UserAgent": userAgent])
            defaults.set(false, forKey: "MobileMode")
        }
        
        if let cookieData = defaults.data(forKey: "ApplicationCookie"),
           let cookies = try? NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSArray.self, NSHTTPCookie.self], from: cookieData) as? [HTTPCookie] {
            cookies.forEach { HTTPCookieStorage.shared.setCookie($0) }
        }
        
        defaults.synchronize()
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        saveCookies()
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        saveCookies()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        restoreCookies()
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        restoreCookies()
    }

    func applicationWillTerminate(_ application: UIApplication) {
        saveCookies()
    }
    
    private func saveCookies() {
        let cookies = HTTPCookieStorage.shared.cookies ?? []
        if let cookieData = try? NSKeyedArchiver.archivedData(withRootObject: cookies, requiringSecureCoding: true) {
            let defaults = UserDefaults.standard
            defaults.set(cookieData, forKey: "ApplicationCookie")
            defaults.synchronize()
        }
    }
    
    private func restoreCookies() {
        let defaults = UserDefaults.standard
        if let cookieData = defaults.data(forKey: "ApplicationCookie"),
           let cookies = try? NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSArray.self, NSHTTPCookie.self], from: cookieData) as? [HTTPCookie] {
            cookies.forEach { HTTPCookieStorage.shared.setCookie($0) }
        }
    }
}
