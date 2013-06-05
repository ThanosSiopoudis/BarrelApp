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
    //[NSThread sleepForTimeInterval:10.0f]; // Wait for debugger
    
    BOOL isSetup = NO;
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
    }
    
    if ([[self execParams] isEqualToString:@"initPrefix"]) {
        // Initialise the wine prefix (wineboot) [synchronous]
        [self initPrefix];
        [[NSApplication sharedApplication] terminate:nil];
    }
    else if ([[self runParams] length] > 0) {
        if (isSetup) {
            [self runSetup];
        }
        else {
            [self runWithParams];
        }
        [[NSApplication sharedApplication] terminate:nil];
    }
    else {
        // Normal wine launch (wine) [asynchronous]
        dispatchQueue = dispatch_queue_create("com.appcake.barrelappqueue", DISPATCH_QUEUE_SERIAL);
        dispatch_queue_t priority = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0);
        dispatch_set_target_queue(dispatchQueue, priority);
        
        dispatch_async(dispatchQueue, ^{
            [self runScript:@"BLWineLauncher" withArguments:@"" shouldWaitForProcess:NO];
        });
        
        [[NSApplication sharedApplication] terminate:nil];
    }
}

- (void)runSetup {
    NSMutableArray *startingExecutables = [self searchFolderForExecutables:[NSString stringWithFormat:@"%@/drive_c", [[NSBundle mainBundle] resourcePath]]];
    NSMutableArray *newExecutables = [[NSMutableArray alloc] init];
    
    
    [self runScript:@"BLWineLauncher" withArguments:[self runParams] shouldWaitForProcess:YES];
    
    NSMutableArray *endExecutables = [self searchFolderForExecutables:[NSString stringWithFormat:@"%@/drive_c", [[NSBundle mainBundle] resourcePath]]];
    
    for (NSString *cPath in endExecutables) {
        if (![startingExecutables containsObject:cPath]) {
            // Remove the path to the wrapper and start at drive_c
            [newExecutables addObject:[cPath stringByReplacingOccurrencesOfString:[[NSBundle mainBundle] resourcePath] withString:@""]];
        }
    }
    
    if ([newExecutables count] > 0) {
        OEHUDAlert *execsAlert = [OEHUDAlert alertWithMessageText:@"Please choose the game's main executable" defaultButton:@"OK" alternateButton:@"Cancel" otherButton:@"" popupItems:newExecutables popupButtonLabel:@"Executable"];
        [execsAlert runModal];
    }
    else {
        OEHUDAlert *noNewExecs = [OEHUDAlert alertWithMessageText:@"No new executables found in the bundle. The installer either failed or was cancelled." defaultButton:@"OK" alternateButton:@"" otherButton:@""];
        [noNewExecs runModal];
    }
    
    [[NSApplication sharedApplication] terminate:nil];
}

- (void)runWithParams {
    [self runScript:@"BLWineLauncher" withArguments:[self runParams] shouldWaitForProcess:YES];
    [[NSApplication sharedApplication] terminate:nil];
}

- (void)initPrefix {
    [self runScript:@"BLWineLauncher" withArguments:[self execParams] shouldWaitForProcess:YES];
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

- (void)runScript:(NSString*)scriptName withArguments:(NSString *)arguments shouldWaitForProcess:(BOOL)waitForProcess {
    NSTask *task;
    task = [[NSTask alloc] init];
    
    NSArray *argumentsArray;
    NSString* newpath = [NSString stringWithFormat:@"%@/%@",[self scriptPath], scriptName];
    [task setLaunchPath: newpath];
    argumentsArray = [NSArray arrayWithObjects:arguments, nil];
    [task setArguments: argumentsArray];
    
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
    }
}

@end
