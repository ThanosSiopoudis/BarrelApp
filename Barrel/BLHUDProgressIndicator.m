//
//  BLHUDProgressIndicator.m
//  Barrel
//
//  Created by Thanos Siopoudis on 29/04/2013.
//
//

#import "BLHUDProgressIndicator.h"

@implementation BLHUDProgressIndicator

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}

- (void)drawRect:(NSRect)dirtyRect
{
    NSRect rect = NSInsetRect([self bounds], 1.0, 1.0);
    CGFloat radius = rect.size.height / 2;
    NSBezierPath *bz = [NSBezierPath bezierPathWithRoundedRect:rect xRadius:radius yRadius:radius];
    [bz setLineWidth:2.0];
    [[NSColor whiteColor] set];
    [bz stroke];
    
    rect = NSInsetRect(rect, 2.0, 2.0);
    radius = rect.size.height / 2;
    bz = [NSBezierPath bezierPathWithRoundedRect:rect xRadius:radius yRadius:radius];
    [bz setLineWidth:1.0];
    [bz addClip];
    rect.size.width = floor(rect.size.width * ([self doubleValue] / [self maxValue]));
    NSRectFill(rect);
}

@end
