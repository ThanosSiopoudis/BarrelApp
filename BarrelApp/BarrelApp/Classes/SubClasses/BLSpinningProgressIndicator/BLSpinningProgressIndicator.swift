//
//  BLSpinningProgressIndicator.swift
//  BarrelApp
//
//  Created by Thanos Siopoudis on 28/08/2014.
//  Copyright (c) 2014 AppCake Limited. All rights reserved.
//

import Cocoa

class BLSpinningProgressIndicator : NSView {
    // MARK: Public Vars / Accessors
    var animating:Bool! {
        didSet(animate) {
            if (animate == true) {
                self.startAnimation(self);
            }
            else {
                self.stopAnimation(self);
            }
        }
    }
    var indeterminate:Bool! {
        didSet {
            if (self.indeterminate == true && self.animating == true) {
                self.stopAnimation(self);
            }
            self.needsDisplay = true;
        }
    }
    var colour:NSColor? {
        get {
            return self.foreColour;
        }
        set {
            if (self.foreColour != newValue) {
                self.foreColour = newValue?.copy() as NSColor;
                self.needsDisplay = true;
            }
        }
    }
    var backgroundColour:NSColor? {
        get {
            return self.backColour;
        }
        set {
            if (self.backColour != newValue) {
                self.backColour = newValue?.copy() as? NSColor;
                self.needsDisplay = true;
            }
        }
    }
    var drawsBackground:Bool? {
        get {
            return self.drawBackground;
        }
        set {
            if (self.drawBackground != newValue) {
                self.drawBackground = newValue;
            }
            self.needsDisplay = true;
        }
    }
    var doubleValue:Double? {
        get {
            return self.currentValue;
        }
        set {
            if (self.indeterminate == true) {
                self.indeterminate = false;
            }
            self.currentValue = newValue;
            self.needsDisplay = true;
        }
    }
    var maxValue:Double! {
        didSet {
            self.needsDisplay = true;
        }
    }
    var usesThreadedAnimation:Bool? {
        didSet {
            if (self.usesThreadedAnimation != oldValue) {
                if (self.animating == true) {
                    self.stopAnimation(self);
                    self.startAnimation(self);
                }
            }
        }
    }
    var lineWidth:CGFloat!
    var lineStartOffset:CGFloat!
    var lineEndOffset:CGFloat!
    
    // MARK: - Private Vars
    private var position:Int!
    private var numFins:Int!
    private var isFadingOut:Bool!
    private var currentValue:Double!
    private var foreColour:NSColor!
    private var backColour:NSColor?
    private var animationThread:NSThread?
    private var animationTimer:NSTimer?
    private var drawBackground:Bool?
    
    // MARK: - Method Overrides
    override init() {
        super.init();
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder);
    }
    
    override init(frame frameRect: NSRect) {
        self.position = 0;
        self.numFins = 0;
        self.animating = false;
        self.isFadingOut = false;
        self.indeterminate = true;
        self.currentValue = 0.0;
        self.maxValue = 0.0;
        self.foreColour = NSColor.blackColor().copy() as NSColor;
        self.lineWidth = 2.75;
        self.lineStartOffset = 7.5;
        self.lineEndOffset = 13.5;
        
        super.init();
    }
    
    override func viewDidMoveToWindow() {
        if (self.window == nil) {
            self.actuallyStopAnimation();
        }
        else if (self.animating == true) {
            self.actuallyStartAnimation();
        }
    }
    
    override func drawRect(dirtyRect: NSRect) {
        var i:Int = 0;
        var alpha:Float = 1.0;
        
        var size:NSSize = self.bounds.size;
        var diameter:CGFloat = min(size.width, size.height);
        var scale:CGFloat = diameter / 32.0;
        
        if let drawBg = self.drawBackground {
            if (drawBg) {
                self.backColour?.set();
                NSBezierPath.fillRect(self.bounds);
            }
        }
        
        var contextPointer = NSGraphicsContext.currentContext()!.graphicsPort;
        var currentContext = UnsafePointer<CGContext>(contextPointer).memory;
        NSGraphicsContext.saveGraphicsState();
        
        CGContextTranslateCTM(currentContext, self.bounds.size.width / 2, self.bounds.size.height / 2);
        
        if (self.indeterminate == true) {
            
            var anglePerFin:CGFloat = CGFloat(Float(M_PI * 2) / Float(self.numFins));
            
            // Do initial rotation to start place
            var angle:CGFloat = (anglePerFin * CGFloat(self.position));
            CGContextRotateCTM(currentContext, angle);
            
            var lineWidth:CGFloat = self.lineWidth * scale;
            var lineStart:CGFloat = self.lineStartOffset * scale;
            var lineEnd:CGFloat   = self.lineEndOffset * scale;
            
            var path:NSBezierPath = NSBezierPath();
            path.lineWidth = lineWidth;
            path.lineCapStyle = NSLineCapStyle.RoundLineCapStyle;
            path.moveToPoint(NSMakePoint(0, lineStart));
            path.lineToPoint(NSMakePoint(0, lineEnd));
            
            for (i = 0; i < self.numFins; i++) {
                if (self.animating == true) {
                    self.foreColour.colorWithAlphaComponent(CGFloat(alpha)).set();
                }
                else {
                    self.foreColour.colorWithAlphaComponent(0.2).set();
                }
                
                path.stroke();
                
                CGContextRotateCTM(currentContext, angle);
                alpha -= 1.0 / Float(self.numFins);
            }
        }
        else {
            var lineWidth:CGFloat = 1 + (0.01 * diameter);
            var circleRadius:CGFloat = (diameter - lineWidth) / 2.1;
            var circleCenter:NSPoint = NSZeroPoint;
            var completion:Double = self.currentValue / self.maxValue;
            
            self.foreColour.colorWithAlphaComponent(CGFloat(alpha)).set();
            
            var path:NSBezierPath = NSBezierPath();
            path.lineWidth = lineWidth;
            path.appendBezierPathWithOvalInRect(NSMakeRect(-circleRadius, -circleRadius, circleRadius * 2, circleRadius * 2));
            path.stroke();
            
            path = NSBezierPath();
            path.appendBezierPathWithArcWithCenter(circleCenter, radius: circleRadius, startAngle: 90.0, endAngle: 90.0 - (360.0 * CGFloat(completion)), clockwise: true);
            path.lineToPoint(circleCenter);
            path.fill();
        }
        
        NSGraphicsContext.restoreGraphicsState();
    }
    
    
    // MARK: - Class Methods
    func updateFrame(timer:NSTimer?) {
        self.position = (self.position - 1) % self.numFins;
        
        if (self.usesThreadedAnimation == true) {
            self.display();
        }
        else {
            self.needsDisplay = true;
        }
    }
    
    func animateInBackgroundThread() {
        var omega:Int = 100; // RPM
        var animationDelay:Int = 60 * 1000000 / omega / self.numFins;
        
        do {
            self.updateFrame(nil);
            usleep(useconds_t(animationDelay));
        } while(!NSThread.currentThread().cancelled);
    }
    
    func startAnimation(sender:AnyObject?) {
        if (self.indeterminate != true) {
            return;
        }
        if (self.animating == true) {
            return;
        }
        
        self.actuallyStartAnimation();
        self.animating = true;
    }
    
    func actuallyStartAnimation() {
        // Just for safety
        self.actuallyStopAnimation();
        
        if (self.window != nil) {
            if (self.usesThreadedAnimation!) {
                self.animationThread = NSThread(target: self, selector: "animateInBackgroundThread", object: nil);
                if let animThread = self.animationThread {
                    animThread.start();
                }
            }
            else {
                self.animationTimer = NSTimer(timeInterval: NSTimeInterval(0.05), target: self, selector: "updateFrame:", userInfo: nil, repeats: true);
                if let animTimer = self.animationTimer {
                    NSRunLoop.currentRunLoop().addTimer(animTimer, forMode: NSRunLoopCommonModes);
                    NSRunLoop.currentRunLoop().addTimer(animTimer, forMode: NSDefaultRunLoopMode);
                    NSRunLoop.currentRunLoop().addTimer(animTimer, forMode: NSEventTrackingRunLoopMode);
                }
            }
        }
    }
    
    func stopAnimation(sender:AnyObject?) {
        self.actuallyStopAnimation();
        self.animating = false;
    }
    
    func actuallyStopAnimation() {
        if let animThread = self.animationThread {
            animThread.cancel();
            if (animThread.finished) {
                NSRunLoop.currentRunLoop().runMode(NSModalPanelRunLoopMode, beforeDate: NSDate(timeIntervalSinceNow: 0.05));
            }
            self.animationThread = nil;
        }
        else if let animTimer = self.animationTimer {
            animTimer.invalidate();
            self.animationTimer = nil;
        }
    }
}
