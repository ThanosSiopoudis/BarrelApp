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

#import "OELibraryController.h"
#import "OELibraryDatabase.h"

#import "OESidebarItem.h"
#import "OESidebarController.h"
#import "OELibrarySplitView.h"

#import "OELibrarySubviewController.h"
#import "BLGameImporter.h"

#import "OEDBGame.h"
#import "OESystemPlugin.h"
#import "OEDBSmartCollection.h"

#import "NSViewController+OEAdditions.h"
#import "NSArray+OEAdditions.h"
#import "NSWindow+OEFullScreenAdditions.h"

#import "OEPreferencesController.h"
#import "OEHUDAlert+DefaultAlertsAdditions.h"
#import "BLSystemCommand.h"
#import "OEDBImage.h"

#import "AppCakeAPI.h"
#import "BL_GenericAPIResponse.h"

#pragma mark - Exported variables
NSString * const OELastCollectionSelectedKey = @"lastCollectionSelected";

#pragma mark - Imported variables
extern NSString * const OESidebarSelectionDidChangeNotificationName;

#pragma mark - Private variables
static const CGFloat _OEToolbarHeight = 44;

@interface OELibraryController ()
- (void)OE_showFullscreen:(BOOL)fsFlag animated:(BOOL)animatedFlag;

@property NSMutableDictionary *subviewControllers;
- (NSViewController <OELibrarySubviewController>*)viewControllerWithClassName:(NSString*)className;
@end

@implementation OELibraryController
@synthesize database;
@synthesize currentViewController;
@synthesize sidebarController, mainSplitView, mainContentPlaceholderView;
@synthesize toolbarFlowViewButton, toolbarGridViewButton, toolbarListViewButton;
@synthesize toolbarSearchField, toolbarSidebarButton, toolbarAddToSidebarButton, toolbarSlider;
@synthesize cachedSnapshot;
@synthesize delegate;
@synthesize subviewControllers;

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark -
#pragma mark NSViewController stuff
- (NSString *)nibName
{
    return @"Library";
}

- (void)loadView
{
    [super loadView];

    [self setSubviewControllers:[NSMutableDictionary dictionary]];

    if([self database] == nil) [self setDatabase:[OELibraryDatabase defaultDatabase]];
    
    [[self sidebarController] view];
    
    // setup sidebar controller
    OESidebarController *sidebarCtrl = [self sidebarController];    
    [sidebarCtrl setDatabase:[self database]];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sidebarSelectionDidChange:) name:OESidebarSelectionDidChangeNotificationName object:nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:OESidebarSelectionDidChangeNotificationName object:sidebarCtrl];
    
    [self updateToggleSidebarButtonState];

    // setup splitview
    OELibrarySplitView *splitView = [self mainSplitView];
    [splitView setDelegate:self];

    // setup hotkeys
    [toolbarSidebarButton setToolTip:NSLocalizedString(@"Toggle Sidebar", @"Tooltip")];
    [toolbarSidebarButton setToolTipStyle:OEToolTipStyleDefault];

    [toolbarGridViewButton setToolTip:NSLocalizedString(@"Switch To Grid View", @"Tooltip")];
    [toolbarGridViewButton setToolTipStyle:OEToolTipStyleDefault];

    [toolbarFlowViewButton setToolTip:NSLocalizedString(@"Switch To Flow View", @"Tooltip")];
    [toolbarFlowViewButton setToolTipStyle:OEToolTipStyleDefault];

    [toolbarListViewButton setToolTip:NSLocalizedString(@"Switch To List View", @"Tooltip")];
    [toolbarListViewButton setToolTipStyle:OEToolTipStyleDefault];

    [toolbarAddToSidebarButton setToolTip:NSLocalizedString(@"New Collection", @"Tooltip")];
    [toolbarAddToSidebarButton setToolTipStyle:OEToolTipStyleDefault];
}

- (void)viewDidAppear
{
    [super viewDidAppear];
    
    [self layoutToolbar];
    
    [[self sidebarController] reloadData];
}

- (void)viewWillDisappear
{
    [super viewWillDisappear];
    
    // Save Current State
    id lastState = [(id <OELibrarySubviewController>)[self currentViewController] encodeCurrentState];
    id itemID    = [[[self currentViewController] representedObject] sidebarID];
    [self OE_storeState:lastState forSidebarItemWithID:itemID];
    
    NSView *toolbarItemContainer = [[self toolbarSearchField] superview];
    
    [toolbarItemContainer setAutoresizingMask:NSViewWidthSizable];
}

#pragma mark -
#pragma mark Toolbar
- (IBAction)toggleSidebar:(id)sender
{
    [[self mainSplitView] toggleSidebar];
}

- (void)updateToggleSidebarButtonState
{
    [[self toolbarSidebarButton] setState:([[self mainSplitView] isSidebarVisible] ? NSOnState : NSOffState)];
    [[self toolbarSidebarButton] display];
}

- (IBAction)switchToGridView:(id)sender
{
    if([[self currentViewController] respondsToSelector:@selector(switchToGridView:)])
       [[self currentViewController] performSelector:@selector(switchToGridView:) withObject:sender];
}

- (IBAction)switchToListView:(id)sender
{
    if([[self currentViewController] respondsToSelector:@selector(switchToListView:)])
        [[self currentViewController] performSelector:@selector(switchToListView:) withObject:sender];
}

- (IBAction)switchToFlowView:(id)sender
{
    if([[self currentViewController] respondsToSelector:@selector(switchToFlowView:)])
        [[self currentViewController] performSelector:@selector(switchToFlowView:) withObject:sender];
}

- (IBAction)search:(id)sender
{
    if([[self currentViewController] respondsToSelector:@selector(search:)])
        [[self currentViewController] performSelector:@selector(search:) withObject:sender];
}

- (IBAction)changeGridSize:(id)sender
{
    if([[self currentViewController] respondsToSelector:@selector(changeGridSize:)])
        [[self currentViewController] performSelector:@selector(changeGridSize:) withObject:sender];
}

- (IBAction)addCollectionAction:(id)sender
{
    [[self sidebarController] addCollectionAction:sender];
}

#pragma mark FileMenu Actions
- (IBAction)newCollection:(id)sender
{
    [[self database] addNewCollection:nil];
    
    [[self sidebarController] reloadData];
}

- (IBAction)newSmartCollection:(id)sender
{
    [[self database] addNewSmartCollection:nil];
    
    [[self sidebarController] reloadData];
}

- (IBAction)newCollectionFolder:(id)sender
{
    [[self database] addNewCollectionFolder:nil];
    
    [[self sidebarController] reloadData];
}

- (IBAction)editSmartCollection:(id)sender
{
    NSLog(@"Edit smart collection: ");
}
#pragma mark Edit Menu
- (IBAction)find:(id)sender
{
	[[[self view] window] makeFirstResponder:toolbarSearchField];
}
#pragma mark -
#pragma mark Menu Items
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
    if([menuItem action] == @selector(newCollectionFolder:)) return NO;
    
    if([menuItem action] == @selector(editSmartCollection:))
        return [[[self sidebarController] selectedSidebarItem] isKindOfClass:[OEDBSmartCollection class]];
    
    if([menuItem action] == @selector(startGame:))
        return [[self currentViewController] respondsToSelector:@selector(selectedGames)] && [[[self currentViewController] selectedGames] count] != 0;
    
    if([menuItem action] == @selector(find:))
    {
        return [[self toolbarSearchField] isEnabled];
    }
    
    NSButton *button = nil;
    if([menuItem action] == @selector(switchToGridView:))
        button = [self toolbarGridViewButton];
    else if([menuItem action] == @selector(switchToFlowView:))
        button = [self toolbarFlowViewButton];
    else if([menuItem action] == @selector(switchToListView:))
        button = [self toolbarListViewButton];
    else return YES;
    
    [menuItem setState:[button state]];
     return [button isEnabled];
}

#pragma mark -
#pragma mark Import
- (IBAction)addToLibrary:(id)sender
{
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    [openPanel setAllowsMultipleSelection:YES];
    [openPanel setCanChooseFiles:YES];
    [openPanel setCanCreateDirectories:NO];
    [openPanel setCanChooseDirectories:YES];
    
    NSWindow *win = [[self view] window];
    
    [openPanel beginSheetModalForWindow:win completionHandler:
     ^(NSInteger result)
     {
         if(result == NSFileHandlingPanelOKButton)
         {
             // exit our initial open panels completion handler
             //[self performSelector:@selector(startImportSheet:) withObject:[openPanel URLs] afterDelay:0.0];
             BLGameImporter *gameImporter = [[self database] importer];
             FIXME("Add importItemsAtURLs method");
             // [gameImporter importItemsAtURLs:[openPanel URLs]];
         }
     }];
}

#pragma mark -
- (IBAction)startGame:(id)sender
{
    NSMutableArray *gamesToStart = [NSMutableArray new];

    if([sender isKindOfClass:[OEDBGame class]]) {
        [gamesToStart addObject:sender];
    }
    else {
        NSAssert([(id)[self currentViewController] respondsToSelector:@selector(selectedGames)], @"Attempt to start a game from a view controller that doesn't announce selectedGames");
        [gamesToStart addObjectsFromArray:[(id <OELibrarySubviewController>)[self currentViewController] selectedGames]];
    }

    NSAssert([gamesToStart count] > 0, @"Attempt to start a game while the selection is empty");
    if([[self delegate] respondsToSelector:@selector(libraryController:didSelectGame:)]) {
        for(OEDBGame *game in gamesToStart) [[self delegate] libraryController:self didSelectGame:game];
    }
}

- (IBAction)startDebugRun:(id)sender {
    NSMutableArray *gamesToStart = [NSMutableArray new];
    
    if([sender isKindOfClass:[OEDBGame class]]) {
        [gamesToStart addObject:sender];
    }
    else {
        NSAssert([(id)[self currentViewController] respondsToSelector:@selector(selectedGames)], @"Attempt to start a game from a view controller that doesn't announce selectedGames");
        [gamesToStart addObjectsFromArray:[(id <OELibrarySubviewController>)[self currentViewController] selectedGames]];
    }
    
    for(OEDBGame *game in gamesToStart) [self setCurrentGame:game];
    
    // Show the Alert for the debug run
    [self setDebugAlert:[OEHUDAlert alertWithMessageAndInputbox:@"Please enter the debug channels that you want to log"]];
    [[self debugAlert] setDefaultButtonAction:@selector(runGameWithDebug:) andTarget:self];
    [[self debugAlert] runModal];
}

- (IBAction)runGameWithDebug:(id)sender {
    [[self debugAlert] closeWithResult:0];
    NSString *bundlePath = [[self currentGame] bundlePath];
    NSMutableDictionary *plistEntries = [[NSMutableDictionary alloc] initWithContentsOfFile:[NSString stringWithFormat:@"%@/Contents/Info.plist", bundlePath]];
    NSString *wineserverName = [plistEntries valueForKey:@"BLWineserverBin"];
    
    [BLSystemCommand runScript:bundlePath withArguments:[NSArray arrayWithObjects:@"--runTest", [[self debugAlert] stringValue], nil] shouldWaitForProcess:NO];
    
    dispatch_queue_t diQueue = dispatch_queue_create("com.appcake.wineserverMonitor", DISPATCH_QUEUE_SERIAL);
    dispatch_queue_t priority = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0);
    dispatch_set_target_queue(diQueue, priority);
    
    dispatch_async(diQueue, ^{
        [BLSystemCommand waitForWineserverToExitWithBinaryName:wineserverName andCallback:^(BOOL result) {
            if (result) {
                [self setDebugAlert:[OEHUDAlert alertWithMessageText:@"Test run finished. Do you want to see the log?" defaultButton:@"Yes" alternateButton:@"No"]];
                [[self debugAlert] setDefaultButtonAction:@selector(showLogFile:) andTarget:self];
                [[self debugAlert] runModal];
            }
        } waitFor:3];
    });
}

- (IBAction)makeGameRecipeAndUpload:(id)sender {
    NSMutableArray *gamesToUpload = [NSMutableArray new];
    
    if ([sender isKindOfClass:[OEDBGame class]]) {
        [gamesToUpload addObject:sender];
    }
    else {
        NSAssert([(id)[self currentViewController] respondsToSelector:@selector(selectedGames)], @"Attempt to upload a game from a view controller that doesn't announce selectedGames");
        [gamesToUpload addObjectsFromArray:[(id <OELibrarySubviewController>)[self currentViewController] selectedGames]];
    }
    
    for (OEDBGame *game in gamesToUpload) [self setCurrentGame:game];
    
    [self makeGameRecipeAndPushToServer];
}

- (IBAction)showLogFile:(id)sender {
    [[self debugAlert] closeWithResult:0];
    NSString *logFilePath = [NSString stringWithFormat:@"%@/Wine.log", [[NSBundle bundleWithPath:[[self currentGame] bundlePath]] resourcePath]];
    [[NSWorkspace sharedWorkspace] openFile:logFilePath withApplication:@"TextEdit"];
}

- (IBAction)startWineConfig:(id)sender {
    NSMutableArray *gamesToStart = [NSMutableArray new];
    
    if([sender isKindOfClass:[OEDBGame class]]) [gamesToStart addObject:sender];
    else
    {
        NSAssert([(id)[self currentViewController] respondsToSelector:@selector(selectedGames)], @"Attempt to start a game from a view controller that doesn't announce selectedGames");
        
        [gamesToStart addObjectsFromArray:[(id <OELibrarySubviewController>)[self currentViewController] selectedGames]];
    }
    
    NSAssert([gamesToStart count] > 0, @"Attempt to start a game while the selection is empty");
    
    if([[self delegate] respondsToSelector:@selector(libraryController:didSelectGameWineCfg:)])
    {
        for(OEDBGame *game in gamesToStart) [[self delegate] libraryController:self didSelectGameWineCfg:game];
    }
}

- (IBAction)startRegedit:(id)sender {
    NSMutableArray *gamesToStart = [NSMutableArray new];
    
    if([sender isKindOfClass:[OEDBGame class]]) [gamesToStart addObject:sender];
    else
    {
        NSAssert([(id)[self currentViewController] respondsToSelector:@selector(selectedGames)], @"Attempt to start a game from a view controller that doesn't announce selectedGames");
        
        [gamesToStart addObjectsFromArray:[(id <OELibrarySubviewController>)[self currentViewController] selectedGames]];
    }
    
    NSAssert([gamesToStart count] > 0, @"Attempt to start a game while the selection is empty");
    
    if([[self delegate] respondsToSelector:@selector(libraryController:didSelectGameRegedit:)])
    {
        for(OEDBGame *game in gamesToStart) [[self delegate] libraryController:self didSelectGameRegedit:game];
    }
}

- (void)startSelectedGameWithSaveState:(id)stateItem
{
    OEDBSaveState *saveState = [stateItem representedObject];
    
    NSAssert(saveState != nil, @"Attempt to start a save state without valid item");

    if([[self delegate] respondsToSelector:@selector(libraryController:didSelectSaveState:)])
        [[self delegate] libraryController:self didSelectSaveState:saveState];
}

- (void)makeGameRecipeAndPushToServer {
    // Create Game recipe file as per Issue #12
    // Link: https://github.com/ThanosSiopoudis/BarrelApp/issues/12
    NSString *recipePlistFilename = [NSString stringWithFormat:@"%@_recipe.plist", [[[self currentGame] name] stringByReplacingOccurrencesOfString:@" " withString:@"_"]];
    
    // Get some of the saved info from the Info.plist of the game
    NSBundle *gameBundle = [NSBundle bundleWithPath:[[self currentGame] bundlePath]];
    NSMutableDictionary *bundleDict = [NSMutableDictionary dictionaryWithContentsOfFile:[NSString stringWithFormat:@"%@/Contents/Info.plist", [[self currentGame] bundlePath]]];

    NSMutableDictionary *gameRecipe = [[NSMutableDictionary alloc] init];
    [gameRecipe setValue:[[self currentGame] name] forKey:@"BLGameName"];
    [gameRecipe setValue:[[self currentGame] genre] forKey:@"BLGameGenre"];
    [gameRecipe setValue:@"1" forKey:@"BLBuildNumber"]; // This is the initial build
    [gameRecipe setValue:[[NSUserDefaults standardUserDefaults] valueForKey:@"userID"] forKey:@"BLAuthorID"];
    [gameRecipe setValue:[bundleDict valueForKey:@"BLEngineID"] forKey:@"BLWineVersionID"];
    [gameRecipe setValue:[bundleDict valueForKey:@"BLVolumeName"] forKey:@"BLImportedVolName"];
    
    // Run winetricks list to get a list of the installed winetricks but notify the user
    OEHUDAlert *uploadAlert = [OEHUDAlert showProgressAlertWithMessage:@"Getting list of winetricks. This may take a while..." andTitle:@"Getting Winetricks" indeterminate:YES];
    [uploadAlert open];
    
    dispatch_queue_t dispatchQueue = dispatch_queue_create("com.appcake.blwinetricslister", DISPATCH_QUEUE_SERIAL);
    dispatch_queue_t priority = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0);
    dispatch_set_target_queue(dispatchQueue, priority);
    
    dispatch_async(dispatchQueue, ^{
        NSString *winetricksResults = [BLSystemCommand runScript:[NSString stringWithFormat:@"%@/BLWineLauncher", [[gameBundle executablePath] stringByDeletingLastPathComponent]] withArguments:@[@"--winetricksList"] shouldWaitForProcess:YES runForMain:NO];
        [uploadAlert setMessageText:@"Uploading data to server... Please wait..."];
        
        // Make a comma seperated list
        winetricksResults = [winetricksResults stringByReplacingOccurrencesOfString:@"\n" withString:@", "];
        winetricksResults = [winetricksResults substringWithRange:NSMakeRange(0, [winetricksResults length] - 2)];
        [gameRecipe setValue:winetricksResults forKey:@"BLWinetricksVerbs"];
        
        [gameRecipe writeToURL:[[[self database] tempFolderURL] URLByAppendingPathComponent:recipePlistFilename] atomically:YES];
        
        // Prepare the Artwork
        NSImage *originalImage = [[[self currentGame] boxImage] originalImage];
        [originalImage lockFocus];
        NSBitmapImageRep *bitmapRep = [[NSBitmapImageRep alloc] initWithFocusedViewRect:NSMakeRect(0, 0, originalImage.size.width, originalImage.size.height)];
        [originalImage unlockFocus];
        NSData *imageData = [bitmapRep representationUsingType:NSPNGFileType properties:Nil];
        [imageData writeToFile:[NSString stringWithFormat:@"%@/%@_artwork.png", [[[self database] tempFolderURL] path], [[[self currentGame] name] stringByReplacingOccurrencesOfString:@" " withString:@"_"]] atomically:NO];
        
        // Now upload the plist, artwork and create the entry in the API's database
        AppCakeAPI *apiConection = [[AppCakeAPI alloc] init];
        [apiConection uploadGame:[[self currentGame] name] fromVolName:[bundleDict valueForKey:@"BLVolumeName"] wineBuildID:[bundleDict valueForKey:@"BLEngineID"] fromAuthor:[[NSUserDefaults standardUserDefaults] valueForKey:@"userID"] recipePath:[[[[self database] tempFolderURL] URLByAppendingPathComponent:recipePlistFilename] path] toBlock:^(RKObjectRequestOperation *operation, RKMappingResult *result) {
            
            [uploadAlert close];
            
            BL_GenericAPIResponse *response = [result firstObject];
            
            if ([response responseCode] != 200) {
                // Upload failed for some reason. Show why
                NSError *resultError = [[NSError alloc] initWithDomain:@"barrel.error" code:[response responseCode] userInfo:nil];
                [resultError setValue:[response responseDescription] forKey:NSLocalizedDescriptionKey];
                OEHUDAlert *errorAlert = [OEHUDAlert alertWithError:resultError];
                [errorAlert runModal];
            }
            else {
                // Successful upload
                [[self currentGame] setApiID:[NSNumber numberWithInteger:[response responseID]]];
                [[self currentGame] setAuthorID:[[NSUserDefaults standardUserDefaults] valueForKey:@"userID"]]; // Set to self
            }
            
        } failBlock:^(RKObjectRequestOperation *operation, NSError *error) {
            [uploadAlert close];
            OEHUDAlert *errorAlert = [OEHUDAlert alertWithError:error];
            [errorAlert runModal];
        }];
    });
}

#pragma mark -
#pragma mark Sidebar Helpers
- (void)showViewController:(NSViewController <OELibrarySubviewController>*)nextViewController
{
    NSViewController <OELibrarySubviewController> *oldViewController = [self currentViewController];
    if(nextViewController == oldViewController) return;
    
    if([nextViewController respondsToSelector:@selector(setLibraryController:)])
        [nextViewController setLibraryController:self];
    
    [oldViewController viewWillDisappear];
    [nextViewController viewWillAppear];
    
    NSView *newView    = [nextViewController view];    
    if(oldViewController)
    {
        NSView *superView = [[oldViewController view] superview];
        NSView *oldView   = [oldViewController view];
        
        [newView setFrame:[oldView frame]];
        [newView setAutoresizingMask:[oldView autoresizingMask]];
        
        [superView replaceSubview:oldView with:newView];
    }
    else
    {
        NSView *mainContentView = [self mainContentPlaceholderView];
        [newView setFrame:[mainContentView bounds]];
        [mainContentView addSubview:newView];
    }
    [self setCurrentViewController:nextViewController];
    
    [nextViewController viewDidAppear];
    [oldViewController viewDidDisappear];
    if([oldViewController respondsToSelector:@selector(setLibraryController:)])
        [oldViewController setLibraryController:nil];
}

- (void)sidebarSelectionDidChange:(NSNotification *)notification
{    
    // Save Current State
    id lastState = [(id <OELibrarySubviewController>)[self currentViewController] encodeCurrentState];
    id itemID    = [[[self currentViewController] representedObject] sidebarID];
    [self OE_storeState:lastState forSidebarItemWithID:itemID];

    // Set new item
    id<OESidebarItem> selectedItem = [[self sidebarController] selectedSidebarItem];
    
    NSString *viewControllerClasName = [selectedItem viewControllerClassName];
    NSViewController <OELibrarySubviewController> *viewController = [self viewControllerWithClassName:viewControllerClasName];

    // Make sure the view is loaded (-showViewController:) before setting the represented object.
    // This prepares the view controller (via its -loadView implementation) so that it can effectively act upon receiving a new
    // represented object
    [self showViewController:viewController];
    [viewController setRepresentedObject:selectedItem];

    itemID = [selectedItem sidebarID];
    [viewController restoreState:[self OE_storedStateForSidebarItemWithID:itemID]];
}

- (void)OE_storeState:(id)state forSidebarItemWithID:(NSString*)itemID
{
    if(!itemID || !state) return;
    
    NSUserDefaults      *standardUserDefaults = [NSUserDefaults standardUserDefaults];
    NSDictionary        *libraryStates        = [standardUserDefaults valueForKey:@"Library States"];
    NSMutableDictionary *mutableLibraryStates = libraryStates ? [libraryStates mutableCopy] : [NSMutableDictionary dictionary];
    
    [mutableLibraryStates setObject:state forKey:itemID];
    [standardUserDefaults setObject:mutableLibraryStates forKey:@"Library States"];
    [standardUserDefaults synchronize];
}

- (id)OE_storedStateForSidebarItemWithID:(NSString*)itemID
{
    if(!itemID) return nil;
    
    NSUserDefaults      *standardUserDefaults = [NSUserDefaults standardUserDefaults];
    NSDictionary        *libraryStates        = [standardUserDefaults valueForKey:@"Library States"];
   
    return [libraryStates objectForKey:itemID];
}


#pragma mark - OELibrarySplitViewDelegate

- (void)librarySplitViewDidToggleSidebar:(NSNotification *)notification
{
    [self layoutToolbar];
}

- (void)splitViewDidResizeSubviews:(NSNotification *)notification
{
    [self layoutToolbar];
}

#pragma mark -
#pragma mark Private
- (void)OE_showFullscreen:(BOOL)fsFlag animated:(BOOL)animatedFlag
{
    [NSApp setPresentationOptions:(fsFlag ? NSApplicationPresentationAutoHideDock | NSApplicationPresentationAutoHideToolbar : NSApplicationPresentationDefault)];
}

- (NSViewController <OELibrarySubviewController>*)viewControllerWithClassName:(NSString*)className
{
    if(![subviewControllers valueForKey:className])
    {
        Class viewControllerClass = NSClassFromString(className);
        if(viewControllerClass)
        {
            NSViewController <OELibrarySubviewController>*viewController = [[viewControllerClass alloc] init];
            [subviewControllers setObject:viewController forKey:className];
        }
    }
    return [subviewControllers valueForKey:className];
}
#pragma mark -
- (void)layoutToolbar
{
    CGFloat splitterPosition = [[self mainSplitView] splitterPosition];
    NSView *toolbarItemContainer = [[self toolbarSearchField] superview];

    NSRect toolbarItemContainerFrame =
    {
        .origin.x = splitterPosition,
        .origin.y = 0,
        .size.width = NSWidth([[toolbarItemContainer superview] bounds]) - splitterPosition,
        .size.height = _OEToolbarHeight
    };

    [toolbarItemContainer setFrame:toolbarItemContainerFrame];
}
@end

