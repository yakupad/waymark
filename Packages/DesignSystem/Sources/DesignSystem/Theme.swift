//  Theme.swift
//  DesignSystem
//
//  Design tokens for Waymark (spec 6.1 module `DesignSystem`). Kept deliberately small:
//  a spacing scale, corner radii, a brand accent, and two rounded display fonts.

import SwiftUI

public enum Spacing {
    public static let xs: CGFloat = 4
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 16
    public static let lg: CGFloat = 24
    public static let xl: CGFloat = 40
}

public enum Radius {
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 14
    public static let lg: CGFloat = 22
}

public extension Color {
    /// Brand accent — the "start a trip" call to action. A fixed hue that reads well in
    /// both light and dark; no asset catalog needed.
    static let brand = Color(red: 0.15, green: 0.44, blue: 0.90)
}

public extension Font {
    /// The big "current place" headline on the active-trip screen.
    static var placeHeadline: Font { .system(.largeTitle, design: .rounded, weight: .bold) }
    static var placeTitle: Font { .system(.title2, design: .rounded, weight: .semibold) }
}
