//
//  NSPoint+Geometry.swift
//  BarrelApp
//
//  Created by Thanos Siopoudis on 28/08/2014.
//  Copyright (c) 2014 AppCake Limited. All rights reserved.
//

import Cocoa

extension NSPoint {
    static func newPointWithDelta(point:NSPoint, delta:NSPoint) -> NSPoint {
        return NSMakePoint(point.x + delta.x, point.y + delta.y);
    }
}
