//
//  InputUnit.swift
//  Bones
//

import Foundation

enum InputUnit: String, CaseIterable, Identifiable, Codable {
    case kg = "kg"
    case lb = "lb"
    
    var id: Self { self }
    var symbol: String { rawValue }
    
    // Convert a value expressed in this unit to kilograms.
    func toKilograms(_ value: Double) -> Double {
        switch self {
        case .kg: return value
        case .lb: return value * 0.45359237
        }
    }
    
    // Convert a value in kilograms to this unit.
    func fromKilograms(_ kilograms: Double) -> Double {
        switch self {
        case .kg: return kilograms
        case .lb: return kilograms / 0.45359237
        }
    }
}
