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

@implementation BLAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    [self setScriptPath:[[[NSBundle mainBundle] executablePath] stringByDeletingLastPathComponent]];
    
    // First of all, read the arguments passed to the app
    NSMutableArray *args = [[NSMutableArray alloc] initWithArray:[[NSProcessInfo processInfo] arguments]];
    // Get the first argument to decide what we need to do
    for (int i=0; i<[args count]; i++) {
        if ([(NSString *)[args objectAtIndex:i] isEqualToString:@"--exec"]) {
            // This is our custom argument, so get the param from the next index
            [self setExecParams:(NSString *)[args objectAtIndex:i+1]];
        }
    }
    
    if ([[self execParams] isEqualToString:@"initPrefix"]) {
        // Initialise the wine prefix (wineboot) [synchronous]
        [self initPrefix];
    }
    else {
        // Normal wine launch (wine) [asynchronous]
        dispatchQueue = dispatch_queue_create("com.appcake.barrelappqueue", DISPATCH_QUEUE_SERIAL);
        dispatch_queue_t priority = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0);
        dispatch_set_target_queue(dispatchQueue, priority);
        
        dispatch_async(dispatchQueue, ^{
            [self runScript:@"BLWineLauncher" withArguments:@""];
        });
        
        [[NSApplication sharedApplication] terminate:nil];
    }
}

- (void)initPrefix {
    [self runScript:@"BLWineLauncher" withArguments:[self execParams]];
    [[NSApplication sharedApplication] terminate:nil];
}

- (void)runScript:(NSString*)scriptName withArguments:(NSString *)arguments
{
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
}

@end
