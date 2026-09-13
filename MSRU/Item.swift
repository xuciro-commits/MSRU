//
//  Item.swift
//  MSRU
//
//  Created by 许强 on 9/14/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
