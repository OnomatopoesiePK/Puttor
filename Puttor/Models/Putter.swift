//
//  Putter.swift
//  Puttor
//

import Foundation
import SwiftData

@Model
final class Putter {
    var id: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date()

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
    }
}
