//  Theme.swift
//  DesignSystem
//
//  Design tokens for Waymark. The visual language is Turkish intercity road
//  signage: white-on-blue direction panels, milestone chevrons, distance figures
//  set like the km on a sign, and heavy uppercase labels.

import SwiftUI

public enum Spacing {
    public static let xs: CGFloat = 4
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 16
    public static let lg: CGFloat = 24
    public static let xl: CGFloat = 40
}

public enum Radius {
    /// Sign corners are gently rounded, not pill-shaped.
    public static let sm: CGFloat = 6
    public static let md: CGFloat = 12
    public static let lg: CGFloat = 18
}

public extension Color {
    /// Deep highway-direction-sign blue — the primary surface for "where you are".
    static let signBlue = Color(red: 0.03, green: 0.24, blue: 0.52)
    /// A darker blue for gradients / pressed states.
    static let signBlueDeep = Color(red: 0.02, green: 0.15, blue: 0.36)
    /// State-road green — a confirmed crossing.
    static let signGreen = Color(red: 0.04, green: 0.40, blue: 0.26)
    /// Caution amber — a place that's detected but not confirmed yet.
    static let signAmber = Color(red: 0.83, green: 0.58, blue: 0.02)

    /// Kept for existing call sites; the brand colour is the sign blue.
    static let brand = Color.signBlue
}

public extension ShapeStyle where Self == Color {
    static var signBlue: Color { .signBlue }
    static var signGreen: Color { .signGreen }
    static var signAmber: Color { .signAmber }
}

public extension Font {
    /// The big place name on a direction panel.
    static var placeHeadline: Font { .system(size: 38, weight: .black) }
    static var placeTitle: Font { .system(size: 24, weight: .heavy) }
    /// A distance / count figure, set large like the km on a sign.
    static var signFigure: Font { .system(size: 30, weight: .black).monospacedDigit() }
    /// Small hard-working labels — always paired with `.signCaps()`.
    static var signLabel: Font { .system(size: 12, weight: .bold) }
}

public extension View {
    /// Uppercase, tracked, the way text is set on a sign.
    func signCaps(_ tracking: CGFloat = 1.1) -> some View {
        self.textCase(.uppercase).tracking(tracking)
    }
}
