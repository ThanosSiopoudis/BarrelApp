/*
 Copyright (c) 2011, OpenEmu Team
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
     * Redistributions of source code must retain the above copyright
       notice, this list of conditions and the following disclaimer.
     * Redistributions in binary form must reproduce the above copyright
       notice, this list of conditions and the following disclaimer in the
       documentation and/or other materials provided with the distribution.
     * Neither the name of the OpenEmu Team nor the
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
#import "OEPrefLibraryController.h"
#import "OEApplicationDelegate.h"
#import "OELibraryDatabase.h"
#import "OEDBSystem.h"
#import "OESystemPlugin.h"
#import "OECorePlugin.h"
#import "OESidebarOutlineView.h"

#import "OEButton.h"
#import "OEHUDAlert.h"

@interface OEPrefLibraryController ()
{
    CGFloat height;
}

- (void)OE_rebuildAvailableLibraries;
- (void)OE_calculateHeight;
@end

#define baseViewHeight 321.0
#define librariesContainerHeight 0.0
@implementation OEPrefLibraryController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]))
    {
        [self OE_calculateHeight];
    }
    
    return self;
}

- (void)awakeFromNib
{
    height = baseViewHeight - librariesContainerHeight;
    [self OE_rebuildAvailableLibraries];
    
	NSString *path = [[NSUserDefaults standardUserDefaults] objectForKey:OEDatabasePathKey];
	[[self pathField] setStringValue:[path stringByAbbreviatingWithTildeInPath]];
}

- (void)dealloc
{
}
#pragma mark ViewController Overrides

- (NSString *)nibName
{
	return @"OEPrefLibraryController";
}

#pragma mark OEPreferencePane Protocol

- (NSImage *)icon
{
	return [NSImage imageNamed:@"library_tab_icon"];
}

- (NSString *)title
{
	return @"Library";
}

- (NSString *)localizedTitle
{
    return NSLocalizedString([self title], "");
}

- (NSSize)viewSize
{
	return NSMakeSize(423, height);
}

#pragma mark -
#pragma mark UI Actions

- (IBAction)resetLibraryFolder:(id)sender
{
    NSString *databasePath = [[NSUserDefaults standardUserDefaults] valueForKey:OEDefaultDatabasePathKey];
    
    [[NSUserDefaults standardUserDefaults] setValue:databasePath forKey:OEDatabasePathKey];
    [[self pathField] setStringValue:[databasePath stringByAbbreviatingWithTildeInPath]];
}

- (IBAction)changeLibraryFolder:(id)sender
{
    NSOpenPanel *openDlg = [NSOpenPanel openPanel];
    
    openDlg.canChooseFiles = NO;
    openDlg.canChooseDirectories = YES;
    openDlg.canCreateDirectories = YES;
    
    [openDlg beginSheetModalForWindow:self.view.window completionHandler:
     ^(NSInteger result)
     {
         if(NSFileHandlingPanelOKButton == result)
         {
             NSString *databasePath = [[openDlg URL] path];
             
             if(databasePath != nil && ![databasePath isEqualToString:[[NSUserDefaults standardUserDefaults] valueForKey:OEDatabasePathKey]])
             {
                 [[NSUserDefaults standardUserDefaults] setValue:databasePath forKey:OEDatabasePathKey];
                 // [[[NSApplication sharedApplication] delegate] loadDatabase];
                 [[self pathField] setStringValue:[databasePath stringByAbbreviatingWithTildeInPath]];
             }
         }
     }];
}

#pragma mark -

- (void)OE_calculateHeight
{
    [self OE_rebuildAvailableLibraries];
}

- (void)OE_rebuildAvailableLibraries
{
    [[[[self librariesView] subviews] copy] makeObjectsPerformSelector:@selector(removeFromSuperviewWithoutNeedingDisplay)];
    
    // get all system plugins, ordered them by name
    NSArray *systems = [OEDBSystem allSystems];
    
    // calculate number of rows (using 2 columns)
    NSInteger rows = ceil([systems count] / 2.0);

    // set some spaces and dimensions
    CGFloat vSpace = 10;
    CGFloat iHeight = 18;
    
    // calculate complete view height
    height = baseViewHeight;
    
    if([self librariesView] == nil) return;
    
    [[self librariesView] setFrameSize:(NSSize){ [[self librariesView] frame].size.width, (iHeight * rows + (rows - 1) * vSpace)}];
}

@end
