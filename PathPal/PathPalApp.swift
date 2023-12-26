//
//  PathPalApp.swift
//  PathPal
//
//  Created by Suji Lee on 12/26/23.
//

import SwiftUI
import GoogleMaps

@main
struct PathPalApp: App {
    init() {
        if let googleMapsAPIKey = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_MAPS_API_KEY") as? String {
            GMSServices.provideAPIKey(googleMapsAPIKey)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
