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

#import "BLAppDelegate.h"
#import "OEHUDAlert+DefaultAlertsAdditions.h"

@implementation BLAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    // [NSThread sleepForTimeInterval:10.0f]; // Wait for debugger
    [self setInfoPlistPath:[NSString stringWithFormat:@"%@/Contents/Info.plist", [[NSBundle mainBundle] bundlePath]]];
    [self setInfoPlistDict:[[NSMutableDictionary alloc] initWithContentsOfFile:[self infoPlistPath]]];
    
    dispatchQueue = dispatch_queue_create("com.appcake.barrelappqueue", DISPATCH_QUEUE_SERIAL);
    dispatch_queue_t priority = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0);
    dispatch_set_target_queue(dispatchQueue, priority);
    
    BOOL isSetup = NO;
    BOOL isTestRun = NO;
    [self setScriptPath:[[[NSBundle mainBundle] executablePath] stringByDeletingLastPathComponent]];
    
    // First of all, read the arguments passed to the app
    NSMutableArray *args = [[NSMutableArray alloc] initWithArray:[[NSProcessInfo processInfo] arguments]];
    // Get the first argument to decide what we need to do
    for (int i=0; i<[args count]; i++) {
        if ([(NSString *)[args objectAtIndex:i] isEqualToString:@"--exec"]) {
            // This is our custom argument, so get the param from the next index
            [self setExecParams:(NSString *)[args objectAtIndex:i+1]];
        }
        else if ([(NSString *)[args objectAtIndex:i] isEqualToString:@"--run"]) {
            [self setRunParams:(NSString *)[args objectAtIndex:i+1]];
        }
        else if ([(NSString *)[args objectAtIndex:i] isEqualToString:@"--runSetup"]) {
            [self setRunParams:(NSString *)[args objectAtIndex:i+1]];
            isSetup = YES;
        }
        else if ([(NSString *)[args objectAtIndex:i] isEqualToString:@"--runWineCfg"]) {
            [self setExecParams:(NSString *)[args objectAtIndex:i]];
        }
        else if ([(NSString *)[args objectAtIndex:i] isEqualToString:@"--runTest"]) {
            [self setRunParams:(NSString *)[args objectAtIndex:i+1]];
            isTestRun = YES;
        }
    }
    
    if ([[self execParams] isEqualToString:@"initPrefix"]) {
        // Initialise the wine prefix (wineboot) [synchronous]
        [self initPrefix];
        [[NSApplication sharedApplication] terminate:nil];
    }
    else if ([[self execParams] isEqualToString:@"--runWineCfg"]) {
        [self runWineConfig];
    }
    else if ([[self runParams] length] > 0) {
        if (isSetup) {
            [self runSetup];
        }
        else if (isTestRun) {
            [self runTestRun];
        }
        else {
            [self runWithParams];
        }
    }
    else {
        // Normal wine launch (wine) [asynchronous]
        NSString *winBinaryPath = [NSString stringWithFormat:@"%@/Contents/Resources/%@", [[NSBundle mainBundle] bundlePath], [[self infoPlistDict] valueForKey:@"Windows Executable"]];
        BOOL withStart = [[[self infoPlistDict] valueForKey:@"BLUseStartExe"] boolValue];
        OEHUDAlert *launchAlert = [OEHUDAlert showProgressAlertWithMessage:@"Launching Game..." andTitle:@"Launching Game" indeterminate:YES];
        [self setAlertCache:launchAlert];
        [[self alertCache] open];
        dispatch_async(dispatchQueue, ^{
            NSMutableArray *launchArgs = [[NSMutableArray alloc] initWithObjects:winBinaryPath, nil];
            if (withStart) {
                [launchArgs addObject:@"--withStart"];
            }
            [self runScript:@"BLWineLauncher" withArguments:launchArgs shouldWaitForProcess:YES callback:^(int result){
                [[self alertCache] close];
                [[NSApplication sharedApplication] terminate:nil];
            }];
        });
    }
}

- (void)runTestRun {
    NSString *winBinaryPath = [NSString stringWithFormat:@"%@/Contents/Resources/%@", [[NSBundle mainBundle] bundlePath], [[self infoPlistDict] valueForKey:@"Windows Executable"]];
    dispatch_async(dispatchQueue, ^{
        [self runScript:@"BLWineLauncher" withArguments:[NSArray arrayWithObjects:@"--runTest", winBinaryPath, [self runParams], nil] shouldWaitForProcess:YES callback:^(int result){
            [[NSApplication sharedApplication] terminate:nil];
        }];
    });
}

- (void)runWineConfig {
    OEHUDAlert *configAlert = [OEHUDAlert showProgressAlertWithMessage:@"Running Wine Config..." andTitle:@"Wine Config" indeterminate:YES];
    [configAlert setOtherButtonTitle:@"Kill Wine"];
    [configAlert setOtherButtonAction:@selector(killAllWineProcesses) andTarget:self];
    [self setAlertCache:configAlert];
    [[self alertCache] open];
    
    dispatch_async(dispatchQueue, ^{
        [self runScript:@"BLWineLauncher" withArguments:[NSArray arrayWithObjects:@"--runWineCfg", nil] shouldWaitForProcess:YES callback:^(int result){
            [[self alertCache] close];
            [[NSApplication sharedApplication] terminate:nil];
        }];
    });
}

- (void)runSetup {
    // Open the progress window in its own thread
    OEHUDAlert *installerAlert = [OEHUDAlert showProgressAlertWithMessage:@"Installing game..." andTitle:@"Installing..." indeterminate:YES];
    [installerAlert setOtherButtonTitle:@"Kill Wine"];
    [installerAlert setOtherButtonAction:@selector(killAllWineProcesses) andTarget:self];
    [self setAlertCache:installerAlert];
    [[self alertCache] open];
    
    [self setStartingExecutables:[self searchFolderForExecutables:[NSString stringWithFormat:@"%@/drive_c", [[NSBundle mainBundle] resourcePath]]]];
    [self setTheNewExecutables:[[NSMutableArray alloc] init]];
    
    dispatch_async(dispatchQueue, ^{
        [self runScript:@"BLWineLauncher" withArguments:[NSArray arrayWithObjects:@"--runSetup", [self runParams], nil] shouldWaitForProcess:YES callback:^(int result){
            [[self alertCache] close];
            [self setupFinished];
            [[NSApplication sharedApplication] terminate:nil];
        }];
    });
}

- (void)setupFinished {
    NSMutableArray *endExecutables = [self searchFolderForExecutables:[NSString stringWithFormat:@"%@/drive_c", [[NSBundle mainBundle] resourcePath]]];
    
    for (NSString *cPath in endExecutables) {
        if (![[self startingExecutables] containsObject:cPath]) {
            // Remove the path to the wrapper and start at drive_c
            [[self theNewExecutables] addObject:[cPath stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"%@/", [[NSBundle mainBundle] resourcePath]] withString:@""]];
        }
    }
    
    if ([[self theNewExecutables] count] > 0) {
        OEHUDAlert *execsAlert = [OEHUDAlert alertWithMessageText:@"Please choose the game's main executable" defaultButton:@"OK" alternateButton:@"Cancel" otherButton:@"" popupItems:[self theNewExecutables] popupButtonLabel:@".exe"];
        [execsAlert setDefaultButtonAction:@selector(saveBundleExecutablePath) andTarget:self];
        [self setAlertCache:execsAlert];
        [[self alertCache] runModal];
    }
    else {
        OEHUDAlert *noNewExecs = [OEHUDAlert alertWithMessageText:@"No new executables found in the bundle. The installer either failed or was cancelled." defaultButton:@"OK" alternateButton:@"" otherButton:@""];
        [noNewExecs runModal];
    }
}

- (void)waitForWineLauncherToFinish {
    for (;;) {
        BOOL stillRunning = NO;
        NSArray *resultArray = [[self systemCommand:@"ps -eo pcpu,pid,args | grep \"BLWineLauncher\"" callback:nil] componentsSeparatedByString:@" "];
        NSMutableArray *cleanArray = [[NSMutableArray alloc] init];
        // Go through the resultArray and clear out any empty items
        for (NSString *item in resultArray) {
            if ([item length] > 0) {
                [cleanArray addObject:item];
            }
        }
        
        if ([cleanArray count] > 0) {
            for (int i=0; i<[cleanArray count]; i++) {
                NSString *test = [cleanArray objectAtIndex:i];
                NSRange strRange = [test rangeOfString:@"BLWineLauncher"];
                NSRange stuckRange = [test rangeOfString:@")"];
                if ((strRange.location != NSNotFound && stuckRange.location == NSNotFound) && ![(NSString *)[cleanArray objectAtIndex:(i-1)] isEqualToString:@"grep"]) {
                    stillRunning = YES;
                }
            }
        }
        if (!stillRunning) {
            NSLog(@"WineLauncher not running");
            return;
        }
        [NSThread sleepForTimeInterval:1.0f];
    }
}

- (void)runWithParams {
    [self runScript:@"BLWineLauncher" withArguments:[NSArray arrayWithObjects:[self runParams], nil] shouldWaitForProcess:YES callback:nil];
    [[NSApplication sharedApplication] terminate:nil];
}

- (void)initPrefix {
    [self runScript:@"BLWineLauncher" withArguments:[NSArray arrayWithObjects:[self execParams], nil] shouldWaitForProcess:YES callback:nil];
    [[NSApplication sharedApplication] terminate:nil];
}

- (NSMutableArray *)searchFolderForExecutables:(NSString *)folder {
    NSMutableArray *results = [[NSMutableArray alloc] init];
    
    NSDirectoryEnumerator *direnum = [[NSFileManager defaultManager] enumeratorAtURL:[NSURL URLWithString:[folder stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]]includingPropertiesForKeys:[NSArray arrayWithObjects:NSURLNameKey, NSURLIsDirectoryKey, nil] options:NSDirectoryEnumerationSkipsHiddenFiles errorHandler:nil];
    
    NSNumber *isDirectory = nil;
    NSError *error;
    
    for (NSURL *url in direnum) {
        if (![url getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:&error]) {
            // ERROR
        }
        else if (![isDirectory boolValue]) {
            // It's a file. Add it to the array if it's an .exe
            if ([[url pathExtension] isEqualToString:@"exe"]) {
                [results addObject:[url path]];
            }
        }
    }
    
    return results;
}

- (void)saveBundleExecutablePath {
     NSString *execPath = [[self alertCache] popupButtonSelectedItem];
    if ([execPath length] > 0) {
        [[self infoPlistDict] setValue:execPath forKey:@"Windows Executable"];
        [[self infoPlistDict] writeToFile:[self infoPlistPath] atomically:YES];
    }
    [NSApp stopModal];
}

- (NSString *)systemCommand:(NSString *)command callback:(void (^)(int))completionBlock
{
	FILE *fp;
	char buff[512];
	NSMutableString *returnString = [[NSMutableString alloc] init];
	fp = popen([command cStringUsingEncoding:NSUTF8StringEncoding], "r");
    while (fgets( buff, sizeof buff, fp))
    {
        [returnString appendString:[NSString stringWithCString:buff encoding:NSUTF8StringEncoding]];
    }
    pclose(fp);
    returnString = [NSMutableString stringWithString:[returnString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
    if (completionBlock) {
        completionBlock(1);
    }
	return [NSString stringWithString:returnString];
}

- (void)runScript:(NSString*)scriptName withArguments:(NSArray *)arguments shouldWaitForProcess:(BOOL)waitForProcess callback:(void (^)(int))completionBlock  {
    NSTask *task;
    task = [[NSTask alloc] init];
    
    NSString* newpath = [NSString stringWithFormat:@"%@/%@",[self scriptPath], scriptName];
    [task setLaunchPath: newpath];
    [task setArguments: arguments];
    
    NSPipe *pipe;
    pipe = [NSPipe pipe];
    [task setStandardOutput: pipe];
    
    NSFileHandle *file;
    file = [pipe fileHandleForReading];
    
    [task launch];
    
    if (waitForProcess) {
        NSData *data;
        data = [file readDataToEndOfFile];
        
        NSString *string;
        string = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
        if (completionBlock) {
            completionBlock(1);
        }
    }
}

- (void)killAllWineProcesses {
    NSLog(@"Forcefully killing wine..");
    // Get the wine and wineserver bundle names from the plist file
    NSString *wineBundleName = [[self infoPlistDict] valueForKey:@"BLWineBin"];
    NSString *wineserverBundleName = [[self infoPlistDict] valueForKey:@"BLWineserverBin"];
    [self systemCommand:[NSString stringWithFormat:@"killall -9 \"%@\" > /dev/null 2>&1", wineBundleName] callback:nil];
    [self systemCommand:[NSString stringWithFormat:@"killall -9 \"%@\" > /dev/null 2>&1", wineserverBundleName] callback:nil];
}

@end
