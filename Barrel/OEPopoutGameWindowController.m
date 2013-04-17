/*
 Copyright (c) 2012, OpenEmu Team

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 *Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 *Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.
 *Neither the name of the OpenEmu Team nor the
 names of its contributors may be used to endorse or promote products
 derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY OpenEmu Team ''AS IS'' AND ANY
 EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL OpenEmu Team BE LIABLE FOR ANY
 DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "OEPopoutGameWindowController.h"

#import "OEHUDWindow.h"
#import "NSViewController+OEAdditions.h"
#import "NSWindow+OEFullScreenAdditions.h"
#import <QuartzCore/QuartzCore.h>
#import "OEUtilities.h"

#import "OEDBRom.h"
#import "OEDBGame.h"
#import "OEDBSystem.h"

#pragma mark - Private variables

static const NSSize       _OEPopoutGameWindowMinSize = {100, 100};
static const NSSize       _OEScreenshotWindowMinSize = {100, 100};
static const unsigned int _OEFitToWindowScale        = 0;

// User defaults
static NSString *const _OESystemIntegralScaleKeyFormat = @"OEIntegralScale.%@";
static NSString *const _OEIntegralScaleKey             = @"integralScale";
static NSString *const _OELastWindowSizeKey            = @"lastPopoutWindowSize";

typedef enum
{
    _OEPopoutGameWindowFullScreenStatusNonFullScreen = 0,
    _OEPopoutGameWindowFullScreenStatusFullScreen,
    _OEPopoutGameWindowFullScreenStatusEntering,
    _OEPopoutGameWindowFullScreenStatusExiting,
} OEPopoutGameWindowFullScreenStatus;



@interface OEScreenshotWindow : NSWindow
@property(nonatomic, unsafe_unretained) NSImageView *screenshotView;
@property(nonatomic, unsafe_unretained) NSImage     *screenshot;
@end



@implementation OEPopoutGameWindowController
{
    NSScreen                           *_screenBeforeWindowMove;
    unsigned int                        _integralScale;

    // Full screen
    NSRect                              _frameForNonFullScreenMode;
    OEScreenshotWindow                 *_screenshotWindow;
    OEPopoutGameWindowFullScreenStatus  _fullScreenStatus;
    BOOL                                _resumePlayingAfterFullScreenTransition;
}

#pragma mark - NSWindowController overridden methods

- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if(!self)
        return nil;

    [window setDelegate:self];
    [window setCollectionBehavior:NSWindowCollectionBehaviorFullScreenPrimary];
    [window setAnimationBehavior:NSWindowAnimationBehaviorDocumentWindow];
    [window setMinSize:_OEPopoutGameWindowMinSize];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(OE_constrainIntegralScaleIfNeeded) name:NSApplicationDidChangeScreenParametersNotification object:nil];

    return self;
}

- (void)dealloc
{
    [[self window] setDelegate:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSApplicationDidChangeScreenParametersNotification object:nil];
}

- (void)setDocument:(NSDocument *)document
{

    
}

- (void)showWindow:(id)sender
{
    NSWindow *window = [self window];
    const BOOL needsToggleFullScreen = (!![self isWindowFullScreen] != !![window isFullScreen]);

    if(![window isVisible])
    {

        // We disable window animation if we need to toggle full screen because two parallel animations
        // (window being ordered front and toggling full-screen) looks painfully ugly. The animation
        // behaviour is restored in -windowDidExitFullScreen:.
        if(needsToggleFullScreen)
            [window setAnimationBehavior:NSWindowAnimationBehaviorNone];
        
        [window makeKeyAndOrderFront:sender];
    }

    if(needsToggleFullScreen)
        [window toggleFullScreen:self];
}

#pragma mark - Actions

- (IBAction)changeIntegralScale:(id)sender
{
    if(![sender respondsToSelector:@selector(representedObject)])
        return;
    if(![[sender representedObject] respondsToSelector:@selector(unsignedIntValue)])
        return;

    const unsigned int newScale = [[sender representedObject] unsignedIntValue];
    if(newScale > [self maximumIntegralScale])
        return;

    [self OE_changeGameViewIntegralScale:newScale];
}

#pragma mark - OEGameIntegralScalingDelegate

- (unsigned int)maximumIntegralScale
{
    NSScreen *screen             = ([[self window] screen] ? : [NSScreen mainScreen]);
    const NSSize maxContentSize   = [OEHUDWindow mainContentRectForFrameRect:[screen visibleFrame]].size;

    return 1;
}

- (BOOL)shouldAllowIntegralScaling
{
    return ![[self window] isFullScreen];
}

#pragma mark - Private methods

- (NSSize)OE_windowContentSizeForGameViewIntegralScale:(unsigned int)gameViewIntegralScale
{

    return NSSizeFromString(@"500");
}

- (NSSize)OE_windowSizeForGameViewIntegralScale:(unsigned int)gameViewIntegralScale
{
    const NSSize contentSize = [self OE_windowContentSizeForGameViewIntegralScale:gameViewIntegralScale];
    const NSSize windowSize  = [OEHUDWindow frameRectForMainContentRect:(NSRect){.size = contentSize}].size;

    return windowSize;
}

- (void)OE_changeGameViewIntegralScale:(unsigned int)newScale
{
    if(_fullScreenStatus != _OEPopoutGameWindowFullScreenStatusNonFullScreen)
        return;
    
    _integralScale = newScale;

    if(newScale != _OEFitToWindowScale)
    {
        const NSRect screenFrame = [[[self window] screen] visibleFrame];
        NSRect newWindowFrame    = [[self window] frame];
        newWindowFrame.size      = [self OE_windowSizeForGameViewIntegralScale:newScale];

        // Make sure the entire window is visible, centering it in case it isn’t
        if(NSMinY(newWindowFrame) < NSMinY(screenFrame) || NSMaxY(newWindowFrame) > NSMaxY(screenFrame))
            newWindowFrame.origin.y = NSMinY(screenFrame) + ((screenFrame.size.height - newWindowFrame.size.height) / 2);

        if(NSMinX(newWindowFrame) < NSMinX(screenFrame) || NSMaxX(newWindowFrame) > NSMaxX(screenFrame))
            newWindowFrame.origin.x = NSMinX(screenFrame) + ((screenFrame.size.width - newWindowFrame.size.width) / 2);

        [[[self window] animator] setFrame:newWindowFrame display:YES];
    }
}

- (void)OE_constrainIntegralScaleIfNeeded
{
    if(_fullScreenStatus != _OEPopoutGameWindowFullScreenStatusNonFullScreen || _integralScale == _OEFitToWindowScale)
        return;

    const unsigned int newMaxScale = [self maximumIntegralScale];
    const NSRect newScreenFrame    = [[[self window] screen] visibleFrame];
    const NSRect currentFrame      = [[self window] frame];

    if(newScreenFrame.size.width < currentFrame.size.width || newScreenFrame.size.height < currentFrame.size.height)
        [self OE_changeGameViewIntegralScale:newMaxScale];
}

- (OEGameDocument *)OE_gameDocument
{
    return (OEGameDocument *)[self document];
}

- (void)OE_buildScreenshotWindow
{
    NSRect windowFrame = {.size = _OEScreenshotWindowMinSize};
    NSScreen *mainScreen                     = [[NSScreen screens] objectAtIndex:0];
    const NSRect screenFrame                 = [mainScreen frame];
    _screenshotWindow  = [[OEScreenshotWindow alloc] initWithContentRect:screenFrame
                                                               styleMask:NSBorderlessWindowMask
                                                                 backing:NSBackingStoreBuffered
                                                                   defer:NO];
    [_screenshotWindow setBackgroundColor:[NSColor clearColor]];
    [_screenshotWindow setOpaque:NO];
    [_screenshotWindow setAnimationBehavior:NSWindowAnimationBehaviorNone];

    
    const NSRect  contentFrame = {NSZeroPoint, windowFrame.size};
    NSImageView  *imageView    = [[NSImageView alloc] initWithFrame:contentFrame];
    [[imageView cell] setImageAlignment:NSImageAlignBottomLeft];
    [[imageView cell] setImageScaling:NSImageScaleAxesIndependently];
    [imageView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [imageView setWantsLayer:YES];
    [imageView setLayerContentsRedrawPolicy:NSViewLayerContentsRedrawOnSetNeedsDisplay];
    [imageView.layer setOpaque:YES];
    _screenshotWindow.screenshotView = imageView;

    [_screenshotWindow setContentView:imageView];
}

- (NSRect)OE_screenshotWindowFrameForOriginalFrame:(NSRect)frame
{
    return NSRectFromString(@"blah");
}

- (void)OE_hideScreenshotWindow
{
    [_screenshotWindow orderOut:self];

    // Reduce the memory footprint of the screenshot window when it’s not visible
    [_screenshotWindow setScreenshot:nil];
    [_screenshotWindow.screenshotView.layer setFrame:(NSRect){.size = _OEScreenshotWindowMinSize}];
}

- (void)OE_forceLayerReposition:(CALayer *)layer toFrame:(NSRect)frame
{
    // This forces the CALayer to reposition
    // without this we see the previous state for a split second
    CABasicAnimation *moveToPosition = [CABasicAnimation animationWithKeyPath:@"position"];
    moveToPosition.fromValue = [NSValue valueWithPoint:frame.origin];
    moveToPosition.toValue = [NSValue valueWithPoint:frame.origin];
    moveToPosition.duration = 0;
    moveToPosition.fillMode = kCAFillModeForwards;
    moveToPosition.removedOnCompletion = NO;

    CABasicAnimation *scaleToSize = [CABasicAnimation animationWithKeyPath:@"bounds.size"];
    scaleToSize.fromValue = [NSValue valueWithSize:frame.size];
    scaleToSize.toValue = [NSValue valueWithSize:frame.size];
    scaleToSize.duration = 0;
    scaleToSize.fillMode = kCAFillModeForwards;
    scaleToSize.removedOnCompletion = NO;

    [_screenshotWindow.screenshotView.layer addAnimation:moveToPosition forKey:@"moveToPosition"];
    [_screenshotWindow.screenshotView.layer addAnimation:scaleToSize forKey:@"scaleToSize"];
}

#pragma mark - NSWindowDelegate

- (void)windowWillMove:(NSNotification *)notification
{
    if(_fullScreenStatus != _OEPopoutGameWindowFullScreenStatusNonFullScreen)
        return;

    _screenBeforeWindowMove = [[self window] screen];
}

- (void)windowDidMove:(NSNotification *)notification
{
    if(_fullScreenStatus != _OEPopoutGameWindowFullScreenStatusNonFullScreen)
        return;

    if(_screenBeforeWindowMove != [[self window] screen])
        [self OE_constrainIntegralScaleIfNeeded];

    _screenBeforeWindowMove = nil;
}

- (void)windowDidChangeScreen:(NSNotification *)notification
{
    if(_fullScreenStatus != _OEPopoutGameWindowFullScreenStatusNonFullScreen)
        return;

    [self OE_constrainIntegralScaleIfNeeded];
}

- (void)windowWillClose:(NSNotification *)notification
{
}

- (NSSize)windowWillResize:(NSWindow *)sender toSize:(NSSize)frameSize
{
    const NSSize windowSize  = [OEHUDWindow frameRectForMainContentRect:(NSRect){.size = frameSize}].size;

    return windowSize;
}

- (void)cancelOperation:(id)sender
{
    if([[self window] isFullScreen])
        [[self window] toggleFullScreen:self];
}

#pragma mark - NSWindowDelegate Full Screen

/* Since resizing OEGameView produces choppy animation, we do the following:
 *
 * - Take a screenshot of the game viewport inside OEGameView and build a borderless window from that
 * - The screenshot window is the one whose resizing to/from full screen is animated
 * - The actual window is faded out and resized to its final animation size
 * - When the animation ends, the actual window is faded in and the screenshot window is removed
 *
 * Emulation is paused when the animation begins and resumed when the animation ends (unless emulation
 * was already paused in the first place).
 */

- (void)windowWillEnterFullScreen:(NSNotification *)notification
{
}

- (NSArray *)customWindowsToEnterFullScreenForWindow:(NSWindow *)window
{
    return @[[self window], _screenshotWindow];
}

- (void)window:(NSWindow *)window startCustomAnimationToEnterFullScreenWithDuration:(NSTimeInterval)duration
{
    }

- (void)windowDidEnterFullScreen:(NSNotification *)notification
{
    
}

- (void)windowWillExitFullScreen:(NSNotification *)notification
{
    
}

- (NSArray *)customWindowsToExitFullScreenForWindow:(NSWindow *)window
{
    return @[[self window], _screenshotWindow];
}

- (void)window:(NSWindow *)window startCustomAnimationToExitFullScreenWithDuration:(NSTimeInterval)duration
{
    }

- (void)windowDidExitFullScreen:(NSNotification *)notification
{
    
}

- (void)windowDidFailToEnterFullScreen:(NSWindow *)window
{
    
}

- (void)windowDidFailToExitFullScreen:(NSWindow *)window
{
    
}

- (void)windowWillStartLiveResize:(NSNotification *)notification
{
    [self OE_changeGameViewIntegralScale:_OEFitToWindowScale];
}

@end





@implementation OEScreenshotWindow

- (void)setScreenshot:(NSImage *)screenshot
{
    [[self screenshotView] setImage:screenshot];
}

@end
