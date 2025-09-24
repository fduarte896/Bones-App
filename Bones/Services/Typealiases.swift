//
//  Typealiases.swift
//  Bones
//
//  Created by Felipe Duarte on 30/07/25.
//

import Foundation
import SwiftData

typealias Pred<T> = T where T: BasicEvent & PersistentModel
