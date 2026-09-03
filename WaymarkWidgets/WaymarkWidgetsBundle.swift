//  WaymarkWidgetsBundle.swift
//  WaymarkWidgets
//
//  The widget extension bundle. v1 ships only the trip Live Activity (spec 8.2); home
//  screen / lock screen widgets are a later addition.

import WidgetKit
import SwiftUI

@main
struct WaymarkWidgetsBundle: WidgetBundle {
    var body: some Widget {
        TripLiveActivity()
    }
}
