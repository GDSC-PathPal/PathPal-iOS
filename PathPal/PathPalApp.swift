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
        if let GOOGLE_MAPS_API_KEY = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_MAPS_API_KEY") as? String {
            GMSServices.provideAPIKey(GOOGLE_MAPS_API_KEY)
        }
        //        if let GOOGLE_PLACES_API_KEY = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_PLACES_API_KEY") as? String {
        //            GMSPlacesClient.provideAPIKey(GOOGLE_PLACES_API_KEY)
        //        }
        //        if let GOOGLE_DIRECTIONS_API_KEY = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_DIRECTIONS_API_KEY") as? String {
        //            GMSServices.provideAPIKey(GOOGLE_DIRECTIONS_API_KEY)
        //        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
