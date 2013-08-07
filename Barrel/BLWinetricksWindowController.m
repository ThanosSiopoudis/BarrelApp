/*
 Copyright (c) 2013, Barrel Team
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.
 * Neither the name of the Barrel Team nor the
 names of its contributors may be used to endorse or promote products
 derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY Barrel Team ''AS IS'' AND ANY
 EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL Barrel Team BE LIABLE FOR ANY
 DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "OEButtonCell.h"
#import "OETableTextFieldCell.h"
#import "OEButton.h"
#import "OEProgressIndicator.h"

#import "BLWinetricksWindowController.h"
#import "BLSystemCommand.h"

#import "OEHUDAlert+DefaultAlertsAdditions.h"

@interface BLWinetricksWindowController () {
    IBOutlet NSView                 *winetricksView;
    IBOutlet NSOutlineView          *winetricksOutline;
    IBOutlet OEButton               *executeWinetricksBtn;
    IBOutlet OEButton               *cancelWindowBtn;
    IBOutlet NSTextView             *winetricksOutput;
    IBOutlet OEProgressIndicator    *winetricksBusyIndicator;
    
    BOOL                            wineIsRunning;
    
    NSString                        *winetricksPlistPath;
    NSString                        *winetricksFinalCommand;
    NSString                        *bundlePath;
    
    NSMutableArray                  *winetricksArgs;
    NSMutableDictionary             *winetricksDatasource;
    OEHUDAlert                      *warning;
}

@property (nonatomic, readwrite) NSString *winetricksPlistPath, *bundlePath, *winetricksFinalCommand;
@property (nonatomic, readwrite) NSMutableDictionary *winetricksDatasource;
@property (nonatomic, readwrite) NSMutableArray *winetricksArgs;
@property (readwrite)            BOOL wineIsRunning;

@end

@implementation BLWinetricksWindowController
@synthesize winetricksPlistPath, winetricksDatasource, bundlePath, winetricksFinalCommand, winetricksArgs, wineIsRunning;

- (id)init
{
    self = [super initWithWindowNibName:@"Winetricks"];
    if (self) {
        // Read the winetricks .plist file
        
    }
    
    return self;
}

- (id)initWithPlistPath:(NSString *)plistPath
{
    self = [super initWithWindowNibName:@"Winetricks"];
    if (self) {
        [self setWinetricksPlistPath:plistPath];
        [self setWinetricksDatasource:[[NSMutableDictionary alloc] init] ];
        
        // Read the plist file and render the items in the outline view
        NSMutableDictionary *infoPlist = [[NSMutableDictionary alloc] initWithContentsOfFile:[self winetricksPlistPath]];
        
        // Create a compatible array
        NSArray *items = [infoPlist objectForKey:@"winetricks"];
        for (NSMutableDictionary *item in items) {
            if ([[self winetricksDatasource] objectForKey:[item objectForKey:@"category"]] == nil) {
                [[self winetricksDatasource] setObject:[NSMutableArray arrayWithObject:item] forKey:[item objectForKey:@"category"]];
            }
            else {
                NSMutableArray *inArray = [[self winetricksDatasource] objectForKey:[item objectForKey:@"category"]];
                [item setObject:[NSNumber numberWithBool:NO] forKey:@"selected"];
                [inArray addObject:item];
            }
        }
        
        // Initialise variables
        [self setWinetricksArgs:[[NSMutableArray alloc] init]];
        [self setWineIsRunning:NO];
    }
    
    return self;
}

- (id)initWithPlistPath:(NSString *)plistPath andBundlePath:(NSString *)bPath {
    [self setBundlePath:bPath];
    return [self initWithPlistPath:plistPath];
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    [[[winetricksOutline tableColumns] objectAtIndex:0] setIdentifier:@"install"];
    [[[winetricksOutline tableColumns] objectAtIndex:1] setIdentifier:@"winetrick"];
    [[[winetricksOutline tableColumns] objectAtIndex:2] setIdentifier:@"description"];
    [winetricksOutput setFont:[NSFont fontWithName:@"Monaco" size:10]];
    [winetricksOutput setTextColor:[NSColor whiteColor]];
    
    [cancelWindowBtn setAction:@selector(closeWinetricksWindow:)];
}

- (IBAction)closeWinetricksWindow:(id)sender {
    [self close];
}

#pragma mark Datasource and Delegate methods
// Method returns count of children for given tree node item
- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item {
    NSInteger cnt = 0;
    if (item == nil) { // root
        cnt = [[winetricksDatasource allKeys] count];
    }
    else {
        cnt = [[[self winetricksDatasource] objectForKey:item] count];
    }
    return cnt;
}

// Method returns flag, whether we can expand given tree node item or not
// (here is the simple rule, we can expand only nodes having one and more children)
- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item {
    NSInteger children = [[[self winetricksDatasource] objectForKey:item] count];
    return children > 1 ? YES : NO;
}

// Method returns value to be shown for given column of the tree node item
- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item {
    OETableTextFieldCell *cell = [tableColumn dataCell];
    
    if ([[[self winetricksDatasource] objectForKey:item] isKindOfClass:[NSArray class]]) {
        if ([[[tableColumn headerCell] stringValue] isEqualToString:@"Winetrick"]) {
            return [item capitalizedString];
        }
        else if ([[[tableColumn headerCell] stringValue] isEqualToString:@"Install"]) {
            return nil;
        }
        else {
            return @"";
        }
    }
    else {
        if ([[tableColumn identifier] isEqualToString:@"winetrick"]) {
            return [item objectForKey:@"winetrick"];
        }
        else if ([[tableColumn identifier] isEqualToString:@"description"]) {
            return [item objectForKey:@"title"];
        }
        else {
            [cell setState:[[item objectForKey:@"selected"] integerValue]];
            return cell;
        }
    }
}

- (OETableTextFieldCell *)outlineView:(NSOutlineView *)outlineView dataCellForTableColumn:(NSTableColumn *)tableColumn item:(id)item {
    OETableTextFieldCell *returnCell = [tableColumn dataCell];
    
    if ([[[tableColumn headerCell] stringValue] isEqualToString:@"Install"] && [item isKindOfClass:[NSString class]]) {
        returnCell = [[OETableTextFieldCell alloc] initTextCell:@""];
    }
    
    return returnCell;
}

// Method returns children item for given tree node item by given index
- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item {
    if (item == nil) {
        // Get the key by index
        NSArray *keys = [[self winetricksDatasource] allKeys];
        NSString *theKey = [keys objectAtIndex:index];
        return theKey;
    }
    else {
        NSArray *items = [[self winetricksDatasource] objectForKey:item];
        return [items objectAtIndex:index];
    }
}

- (void)outlineView:(NSOutlineView *)outlineView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn byItem:(id)item {
    if ([[tableColumn identifier] isEqualToString:@"install"]) {
        [item setObject:object forKey:@"selected"];
    }
}

- (void)receivedData:(NSNotification *)notif {
    NSFileHandle *fh = [notif object];
    NSData *data = [fh availableData];
    NSString *str = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
    
    NSString *strOut = [NSString stringWithFormat:@"%@%@", [winetricksOutput string], str];
    [winetricksOutput setString:strOut];
    
    // Scroll to bottom
    [winetricksOutput scrollRangeToVisible:NSMakeRange([[winetricksOutput string] length], 0)];
    
    NSLog(@"%@",str);
    if ([self wineIsRunning]) {
        [fh waitForDataInBackgroundAndNotify];
    }
    else {
        [winetricksOutline setEnabled:YES];
        [executeWinetricksBtn setEnabled:YES];
        [winetricksBusyIndicator setHidden:YES];
        [winetricksBusyIndicator stopAnimation:self];
        [executeWinetricksBtn setTitle:@"Execute Winetricks"];
        [executeWinetricksBtn setAction:@selector(executeWinetricks:)];
        [executeWinetricksBtn setThemeKey:@"hud_button_blue"];
        [cancelWindowBtn setHidden:NO];
        NSLog(@"Winetricks Finished");
    }
}

#pragma mark ---
#pragma mark Interface Actions
- (IBAction)executeWinetricks:(id)sender {
    // Clean up the output
    [winetricksOutput setString:@""];
    [self setWinetricksArgs:[[NSMutableArray alloc] init]];
    
    // Get the selected winetricks
    NSString *winetricksVerbs = @"winetricks";
    [[self winetricksArgs] addObject:@"--runWinetricks"];
    
    NSArray *categories = [winetricksDatasource allKeys];
    for (NSString *category in categories) {
        NSMutableArray *categoryItems = [winetricksDatasource objectForKey:category];
        for (NSMutableDictionary *item in categoryItems) {
            if ([item objectForKey:@"selected"] && [(NSNumber *)[item objectForKey:@"selected"] integerValue] == 1) {
                winetricksVerbs = [winetricksVerbs stringByAppendingFormat:@" %@", (NSString *)[item objectForKey:@"winetrick"]];
                [[self winetricksArgs] addObject:(NSString *)[item objectForKey:@"winetrick"]];
            }
        }
    }
    
    if (![winetricksVerbs isEqualToString:@"winetricks"]) {
        [self setWinetricksFinalCommand:[NSString stringWithFormat:@"%@/Contents/MacOs/BLWineLauncher", [self bundlePath]]];
        
        // Show a confirmation dialog
        warning = [OEHUDAlert alertWithMessageText:[NSString stringWithFormat:@"The following command will be executed:\n%@\nAre you sure you want to proceed?", winetricksVerbs] defaultButton:@"Yes" alternateButton:@"No"];
        [warning setDefaultButtonAction:@selector(runWinetricksCommand:) andTarget:self];
        [warning runModal];
    }
}

- (IBAction)runWinetricksCommand:(id)sender {
    [warning closeWithResult:0];
    
    // Disable the buttons and the tableview
    [winetricksOutline setEnabled:NO];
    
    [winetricksBusyIndicator setIndeterminate:YES];
    [winetricksBusyIndicator startAnimation:self];
    [winetricksBusyIndicator setHidden:NO];
    [executeWinetricksBtn setTitle:@"Stop!"];
    [executeWinetricksBtn setAction:@selector(forceTerminateWinetrick:)];
    [executeWinetricksBtn setThemeKey:@"hud_button_red"];
    [cancelWindowBtn setHidden:YES];

    [self startTaskAndMonitor:[self winetricksFinalCommand] arguments:[self winetricksArgs]];
}

- (void)startTaskAndMonitor:(NSString *)command arguments:(NSArray *)args {
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath: command];
    [task setArguments: args];
    
    NSPipe *standardOut = [NSPipe pipe];
    NSPipe *standardErr = [NSPipe pipe];
    
    [task setStandardOutput:standardOut];
    [task setStandardError:standardErr];
    
    NSFileHandle *fhStdOut = [standardOut fileHandleForReading];
    [fhStdOut waitForDataInBackgroundAndNotify];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receivedData:) name:NSFileHandleDataAvailableNotification object:fhStdOut];
    
    NSFileHandle *fhStdErr = [standardErr fileHandleForReading];
    [fhStdErr waitForDataInBackgroundAndNotify];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receivedData:) name:NSFileHandleDataAvailableNotification object:fhStdErr];
    
    [task launch];
    [self setWineIsRunning:YES];
    
    dispatch_queue_t diQueue = dispatch_queue_create("com.appcake.wineserverMonitor", DISPATCH_QUEUE_SERIAL);
    dispatch_queue_t priority = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0);
    dispatch_set_target_queue(diQueue, priority);
    
    dispatch_async(diQueue, ^{
        [BLSystemCommand waitForWineserverToExitWithBinaryName:@"BLWineLauncher" andCallback:^(BOOL result) {
            if (result == YES) {
                [self setWineIsRunning:NO];
            }
        }];
    });
}

- (IBAction)forceTerminateWinetrick:(id)sender {
    warning = [OEHUDAlert alertWithMessageText:@"Are you sure you want to forcefully terminate Winetricks?" defaultButton:@"Yes" alternateButton:@"No"];
    [warning setDefaultButtonAction:@selector(stopWineAndLauncher:) andTarget:self];
    [warning runModal];
}

- (IBAction)stopWineAndLauncher:(id)sender {
    // First find and terminate all running Wine and Wineserver processes
    [warning closeWithResult:0];
    
    NSMutableDictionary *bundleDict = [NSMutableDictionary dictionaryWithContentsOfFile:[NSString stringWithFormat:@"%@/Contents/Info.plist", bundlePath]];
    NSString *wineProcess = [bundleDict valueForKey:@"BLWineBin"];
    NSString *wineserverProcess = [bundleDict valueForKey:@"BLWineserverBin"];
    
    NSString *killWineCommand = @"killall -9 \"wine\" > /dev/null 2>&1";
    NSString *killWineserverCommand = @"killall -9 \"wineserver\" > /dev/null 2>&1";
    NSString *killLauncherCommand = @"killall -9 \"BLWineLauncher\" > /dev/null 2>&1";
    
    // Leave no trace!
    [BLSystemCommand systemCommand:killWineCommand shouldWaitForProcess:YES];
    [BLSystemCommand systemCommand:killWineserverCommand shouldWaitForProcess:YES];
    [BLSystemCommand systemCommand:killLauncherCommand shouldWaitForProcess:YES];
    
    // Rename the binaries back
    // Rename the wine binaries back to what they where before exiting
    [[NSFileManager defaultManager] moveItemAtPath:[NSString stringWithFormat:@"%@/Contents/Frameworks/blwine.bundle/bin/wine", bundlePath] toPath:[NSString stringWithFormat:@"%@/bin/%@", bundlePath, wineProcess] error:nil];
    [[NSFileManager defaultManager] moveItemAtPath:[NSString stringWithFormat:@"%@/Contents/Frameworks/blwine.bundle/bin/wineserver", bundlePath] toPath:[NSString stringWithFormat:@"%@/bin/%@", bundlePath, wineserverProcess] error:nil];
    
    [[NSFileManager defaultManager] moveItemAtPath:[NSString stringWithFormat:@"%@/Contents/Frameworks/blwine.bundle/bin/wine_OLD", bundlePath] toPath:[NSString stringWithFormat:@"%@/bin/wine", bundlePath] error:nil];
    [[NSFileManager defaultManager] moveItemAtPath:[NSString stringWithFormat:@"%@/Contents/Frameworks/blwine.bundle/bin/wineserver_OLD", bundlePath] toPath:[NSString stringWithFormat:@"%@/bin/wineserver", bundlePath] error:nil];
}
#pragma mark ---
@end
