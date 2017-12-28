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
        let grey:NSColor = NSColor(calibratedRed: 0.15, green: 0.17, blue: 0.2, alpha: 1.0);
        let black:NSColor = NSColor.blackColor();
        
        let background:NSGradient = NSGradient(startingColor: grey, endingColor: black)!;
        
        let innerRadius:CGFloat = self.bounds.size.width * 1.5;
        let outerRadius:CGFloat = innerRadius + (self.bounds.size.height * 0.5);
        let center:NSPoint = NSMakePoint(NSMidX(self.bounds), (self.bounds.size.height * 0.15) - innerRadius);
        
        background.drawFromCenter(center, radius: innerRadius,
                                  toCenter: center, radius: outerRadius,
                                  options: NSGradientDrawsBeforeStartingLocation | NSGradientDrawsAfterEndingLocation);
    }
}