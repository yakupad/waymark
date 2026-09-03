//  AboutView.swift
//  waymark
//
//  Spec §5.1 / Ek A: the attribution screen is mandatory.

import SwiftUI
import DesignSystem

struct AboutView: View {
    var body: some View {
        List {
            Section("Map & administrative boundary data") {
                Text("© OpenStreetMap contributors. Used under the ODbL 1.0 license.")
                Link("openstreetmap.org/copyright",
                     destination: URL(string: "https://www.openstreetmap.org/copyright")!)
            }
            Section("Population data") {
                Text("Turkish Statistical Institute (TÜİK), Address-Based Population Registration System.")
            }
            Section("Place information") {
                Text("From Wikipedia. Used under the CC BY-SA 4.0 license. Each place's detail page links to its source article.")
                Link("creativecommons.org/licenses/by-sa/4.0",
                     destination: URL(string: "https://creativecommons.org/licenses/by-sa/4.0/")!)
            }
            Section("Elevation") {
                Text("SRTM / OpenStreetMap \u{2018}ele\u{2019} tags.")
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}
