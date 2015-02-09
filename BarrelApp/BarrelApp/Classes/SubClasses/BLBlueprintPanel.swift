//
//  BLBlueprintPanel.swift
//  BarrelApp
//
//  Created by Thanos Siopoudis on 28/08/2014.
//  Copyright (c) 2014 AppCake Limited. All rights reserved.
//

import Cocoa

class BLBlueprintPanel : NSView {
    override func drawRect(dirtyRect: NSRect) {
        NSBezierPath.clipRect(dirtyRect);
        
        self.drawBlueprintInRect(dirtyRect);
        self.drawLightingInRect(dirtyRect);
        self.drawShadowInRect(dirtyRect);
    }
    
    func drawBlueprintInRect(dirtyRect:NSRect) {
        var pattern:NSImage = NSImage(named: "blueprint-tile")!;
        var blueprintColour:NSColor = NSColor(patternImage: pattern);
        
        var offset:NSPoint = NSView.focusView()!.offsetFromWindowOrigin();
        var panelFrame:NSRect = self.bounds;
        var patternPhase:NSPoint = NSMakePoint(offset.x + ((panelFrame.size.width - pattern.size.width) / 2), offset.y);
        
        NSGraphicsContext.saveGraphicsState();
        NSGraphicsContext.currentContext()!.patternPhase = patternPhase;
        blueprintColour.set();
        NSBezierPath.fillRect(dirtyRect);
        NSGraphicsContext.restoreGraphicsState();
    }
    
    func drawLightingInRect(dirtyRect:NSRect) {
        var lighting:NSGradient = NSGradient(startingColor: NSColor(calibratedWhite: 1.0, alpha: 0.2), endingColor: NSColor(calibratedWhite: 0.0, alpha: 0.4));
        
        var backgroundRect:NSRect   = self.bounds;
        var startPoint:NSPoint      = NSMakePoint(NSMidX(backgroundRect), NSMaxY(backgroundRect));
        var endPoint:NSPoint        = NSMakePoint(NSMidX(backgroundRect), NSMidY(backgroundRect));
        var startRadius:CGFloat     = NSWidth(backgroundRect) * 0.1;
        var endRadius:CGFloat       = NSWidth(backgroundRect) * 0.75;
        
        lighting.drawFromCenter(startPoint, radius: startRadius,
                                            toCenter: endPoint,
                                            radius: endRadius,
                                            options: NSGradientDrawsBeforeStartingLocation | NSGradientDrawsAfterEndingLocation
        );
    }
    
    func drawShadowInRect(dirtyRect:NSRect) {
        var shadowRect:NSRect = self.bounds;
        shadowRect.origin.y += shadowRect.size.height - 6.0;
        shadowRect.size.height = 6.0;
        
        // Draw a 1-pixel groove at the bottom of the view
        var grooveRect:NSRect = self.bounds;
        grooveRect.size.height = 1.0;
        
        if (NSIntersectsRect(dirtyRect, shadowRect)) {
            var topShadow:NSGradient = NSGradient(startingColor: NSColor(calibratedWhite: 0.0, alpha: 0.2), endingColor: NSColor(calibratedWhite: 0.0, alpha: 0.0));
            topShadow.drawInRect(shadowRect, angle: 270.0);
        }
        
        if (NSIntersectsRect(dirtyRect, grooveRect)) {
            var grooveColour:NSColor = NSColor(calibratedWhite: 0.0, alpha: 0.33);
            NSGraphicsContext.saveGraphicsState();
            grooveColour.set();
            NSBezierPath.fillRect(grooveRect);
            NSGraphicsContext.restoreGraphicsState();
        }
    }
}

class BLBlueprintTextFieldCell : NSTextFieldCell {
    
}

class BLBlueprintProgressIndicator : BLSpinningProgressIndicator {
    var dropShadow:NSShadow?
    
    override func awakeFromNib() {
        self.colour = NSColor.whiteColor();
        self.drawsBackground = false;
        self.lineWidth = 2.0;
        self.dropShadow = NSShadow(blurRadius: 2.0, offset: NSMakeSize(0, -1.0), color: NSColor(calibratedWhite: 0.0, alpha: 0.5));
    }
    
    override func drawRect(dirtyRect: NSRect) {
        NSGraphicsContext.saveGraphicsState();
        self.dropShadow?.set();
        super.drawRect(dirtyRect);
        NSGraphicsContext.restoreGraphicsState();
    }
}