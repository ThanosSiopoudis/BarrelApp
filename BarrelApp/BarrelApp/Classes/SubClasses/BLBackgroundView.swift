//
//  BLBackgroundView.swift
//  BarrelApp
//
//  Created by Thanos Siopoudis on 23/08/2014.
//  Copyright (c) 2014 AppCake Limited. All rights reserved.
//

import Cocoa

class BLBackgroundView : NSView {
    
    override func drawRect(rect: CGRect) {
        var grey:NSColor = NSColor(calibratedRed: 0.15, green: 0.17, blue: 0.2, alpha: 1.0);
        var black:NSColor = NSColor.blackColor();
        
        var background:NSGradient = NSGradient(startingColor: grey, endingColor: black);
        
        var innerRadius:CGFloat = self.bounds.size.width * 1.5;
        var outerRadius:CGFloat = innerRadius + (self.bounds.size.height * 0.5);
        var center:NSPoint = NSMakePoint(NSMidX(self.bounds), (self.bounds.size.height * 0.15) - innerRadius);
        
        background.drawFromCenter(center, radius: innerRadius,
                                  toCenter: center, radius: outerRadius,
                                  options: NSGradientDrawsBeforeStartingLocation | NSGradientDrawsAfterEndingLocation);
    }
}