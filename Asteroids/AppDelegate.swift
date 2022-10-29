//
//  AppDelegate.swift
//  Asteroids
//
//  Copyright © 2020 Daniel Long and David Long
//
//  License: MIT
//
//  See LICENSE.md in the top-level directory for full terms and discussion.
//

import UIKit
import os.log

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
  var window: UIWindow?

  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    // Override point for customization after application launch.
    let buildVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
    os_log("Rock Rats build version %{public}s starts", log: .app, type: .info, buildVersion)
    // Set up iCloud key-value store
    NSUbiquitousKeyValueStore.default.synchronize()
    window?.overrideUserInterfaceStyle = .dark
    return true
  }

  func applicationWillResignActive(_ application: UIApplication) {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    os_log("applicationWillResignActive", log: .app, type: .debug)
    // SpriteKit has its automatic pause stuff going on behind the scenes ;-), which
    // generally seems to work OK.  The one issue is that if I've explicitly paused
    // some scene and then the user puts the app in the background and later brings
    // it back to the foreground.  SpriteKit would normally unpause then, which is
    // cute, but wrong.  I fix this up by squashing the unpause; see the discussion
    // under isPaused in BasicScene.
  }

  func applicationDidEnterBackground(_ application: UIApplication) {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    os_log("applicationDidEnterBackground", log: .app, type: .debug)
  }

  func applicationWillEnterForeground(_ application: UIApplication) {
    // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    os_log("applicationWillEnterForeground", log: .app, type: .debug)
    // Resync iCloud key-value storage on coming back to the foreground
    NSUbiquitousKeyValueStore.default.synchronize()
  }

  func applicationDidBecomeActive(_ application: UIApplication) {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    os_log("applicationDidBecomeActive", log: .app, type: .debug)
    // Look for game controllers
    Globals.controller.findController()
  }

  func applicationWillTerminate(_ application: UIApplication) {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    os_log("applicationWillTerminate", log: .app, type: .debug)
  }
}
