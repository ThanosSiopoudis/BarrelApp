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

#import <AppKit/AppKit.h>
#import <ApplicationServices/ApplicationServices.h>
#import "BarrelWineLauncher.h"

@implementation BarrelWineLauncher

-(id) initWithArguments:(NSMutableArray *)arguments {
    
    // [NSThread sleepForTimeInterval:10.0f]; // Wait for debugger
    
    if (self = [super init]) {
        [self setArguments:arguments];
        NSBundle *appBundle = [NSBundle bundleWithPath:[[[NSBundle mainBundle] executablePath] stringByReplacingOccurrencesOfString:@"/Contents/MacOs/BLWineLauncher" withString:@""]];
        if (appBundle == nil) {
            appBundle = [NSBundle bundleWithPath:[[[NSBundle mainBundle] executablePath] stringByReplacingOccurrencesOfString:@"/Contents/MacOS/BLWineLauncher" withString:@""]];
        }
        [self setBundlePath:[appBundle bundlePath]];
        [self setExecutablePath:[appBundle executablePath]];
        [self setFrameworksPath:[NSString stringWithFormat:@"%@/Contents/Frameworks", [appBundle bundlePath]]];
        [self setWineBundlePath:[NSString stringWithFormat:@"%@/blwine.bundle", [self frameworksPath]]];
        [self setWinePrefixPath:[appBundle resourcePath]];
        [self setDyldFallbackPath:[NSString stringWithFormat:@"%@:%@/blwine.bundle/lib:/usr/lib:/usr/libexec:/usr/lib/system:/opt/X11/lib:/opt/local/lib:/usr/X11/lib:/usr/X11R6/lib",[self frameworksPath],[self frameworksPath]]];
        
        dispatchQueue = dispatch_queue_create("com.appcake.blwinelauncher", DISPATCH_QUEUE_SERIAL);
        dispatch_queue_t priority = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0);
        dispatch_set_target_queue(dispatchQueue, priority);
    }
    
    return self;
}

-(void) runWine {
    [self makeCustomBundleIDs];
    [self fixWineTempFolder];
    if ([(NSString *)[[self arguments] objectAtIndex:1]isEqualToString:@"initPrefix"]) {
        [self initWinePrefix];
    }
    else if ([(NSString *)[[self arguments] objectAtIndex:1]isEqualToString:@"--runSetup"]) {
        [self runWineWithWindowsBinary:(NSString *)[[self arguments] objectAtIndex:2]];
        [self keepLauncherAliveUntilWineserverQuit];
    }
    else if ([(NSString *)[[self arguments] objectAtIndex:1]isEqualToString:@"--runWineCfg"]) {
        [self runWineConfig];
    }
    else if ([(NSString *)[[self arguments] objectAtIndex:1] isEqualToString:@"--runWinetricks"]) {
        NSString *argsStr = @"";
        for (int i=2; i<[[self arguments] count]; i++) {
            argsStr = [argsStr stringByAppendingString:[NSString stringWithFormat:@" %@",(NSString *)[[self arguments] objectAtIndex: i]]];
        }
        [self runWinetricksWithArgs:argsStr];
    }
    else if ([(NSString *)[[self arguments] objectAtIndex:1] isEqualToString:@"--runTest"]) {
        [self runWithWindowsBinary:(NSString *)[[self arguments] objectAtIndex:2] andTestSwitches:(NSString *)[[self arguments] objectAtIndex:3]];
    }
    else if ([(NSString *)[[self arguments] objectAtIndex:1] isEqualToString:@"--winetricksList"]) {
        [self getWinetricksList];
    }
    else {
        [self runWineWithWindowsBinary:(NSString *)[[self arguments] objectAtIndex:1]];
    }
}

-(void) getWinetricksList {
    [self prepareBinariesForWinetricks];
    
    NSString *script = [NSString stringWithFormat:@"cd \"%@/bin\";export PATH=\"$PWD:%@/bin:%@/bin:$PATH:/opt/local/bin:/opt/local/sbin\";export WINEPREFIX=\"%@\";export WINEDEBUG=\"err+all,fixme+all\";DYLD_FALLBACK_LIBRARY_PATH=\"%@\" winetricks --no-isolate list-installed", [self wineBundlePath], [self wineBundlePath], [self frameworksPath], [self winePrefixPath], [self dyldFallbackPath]];
    [self setScriptPath:@""];
    [self systemCommand:script shouldWaitForProcess:YES redirectOutput:YES];
    
    [self restoreBinaryNames];
}

-(void) runWithWindowsBinary: (NSString *)binaryPath andTestSwitches:(NSString *)switches {
    NSString *pathContainingBinary = [binaryPath stringByDeletingLastPathComponent];
    NSString *binaryName = [binaryPath lastPathComponent];
    NSString *script = [NSString stringWithFormat:@"export PATH=\"%@/bin:%@/bin:$PATH:/opt/local/bin:/opt/local/sbin\";export WINEPREFIX=\"%@\";export WINEDEBUG=\"%@\";cd \"%@\";DYLD_FALLBACK_LIBRARY_PATH=\"%@\" wine \"%@\" > \"%@/Wine.log\" 2>&1", [self wineBundlePath], [self frameworksPath], [self winePrefixPath], switches, pathContainingBinary, [self dyldFallbackPath], binaryName, [self winePrefixPath]];
    [self setScriptPath:@""];
    [self systemCommand:script shouldWaitForProcess:NO redirectOutput:NO];
}

- (void) prepareBinariesForWinetricks {
    // We're about to do winetricks. Rename the wine and wineserver binaries back to what they were
    // before we do that.
    // 1st get the names
    NSString *infoPlistPath = [NSString stringWithFormat:@"%@/Contents/Info.plist", [self bundlePath]];
    NSMutableDictionary *infoPlistDict = [[NSMutableDictionary alloc] initWithContentsOfFile: infoPlistPath];
    NSString *oldWineBin = [infoPlistDict valueForKey:@"BLWineBin"];
    NSString *oldWineserverBin = [infoPlistDict valueForKey:@"BLWineserverBin"];
    
    // 2nd rename the fake ones
    [[NSFileManager defaultManager] moveItemAtPath:[NSString stringWithFormat:@"%@/bin/wine", [self wineBundlePath]] toPath:[NSString stringWithFormat:@"%@/bin/wine_OLD", [self wineBundlePath]] error:nil];
    [[NSFileManager defaultManager] moveItemAtPath:[NSString stringWithFormat:@"%@/bin/wineserver", [self wineBundlePath]] toPath:[NSString stringWithFormat:@"%@/bin/wineserver_OLD", [self wineBundlePath]] error:nil];
    
    // 3rd rename the proper ones to their proper names
    [[NSFileManager defaultManager] moveItemAtPath:[NSString stringWithFormat:@"%@/bin/%@", [self wineBundlePath], oldWineBin] toPath:[NSString stringWithFormat:@"%@/bin/wine", [self wineBundlePath]] error:nil];
    [[NSFileManager defaultManager] moveItemAtPath:[NSString stringWithFormat:@"%@/bin/%@", [self wineBundlePath], oldWineserverBin] toPath:[NSString stringWithFormat:@"%@/bin/wineserver", [self wineBundlePath]] error:nil];
}

- (void) restoreBinaryNames {
    NSString *infoPlistPath = [NSString stringWithFormat:@"%@/Contents/Info.plist", [self bundlePath]];
    NSMutableDictionary *infoPlistDict = [[NSMutableDictionary alloc] initWithContentsOfFile: infoPlistPath];
    NSString *oldWineBin = [infoPlistDict valueForKey:@"BLWineBin"];
    NSString *oldWineserverBin = [infoPlistDict valueForKey:@"BLWineserverBin"];
    
    // Rename the wine binaries back to what they where before exiting
    [[NSFileManager defaultManager] moveItemAtPath:[NSString stringWithFormat:@"%@/bin/wine", [self wineBundlePath]] toPath:[NSString stringWithFormat:@"%@/bin/%@", [self wineBundlePath], oldWineBin] error:nil];
    [[NSFileManager defaultManager] moveItemAtPath:[NSString stringWithFormat:@"%@/bin/wineserver", [self wineBundlePath]] toPath:[NSString stringWithFormat:@"%@/bin/%@", [self wineBundlePath], oldWineserverBin] error:nil];
    
    [[NSFileManager defaultManager] moveItemAtPath:[NSString stringWithFormat:@"%@/bin/wine_OLD", [self wineBundlePath]] toPath:[NSString stringWithFormat:@"%@/bin/wine", [self wineBundlePath]] error:nil];
    [[NSFileManager defaultManager] moveItemAtPath:[NSString stringWithFormat:@"%@/bin/wineserver_OLD", [self wineBundlePath]] toPath:[NSString stringWithFormat:@"%@/bin/wineserver", [self wineBundlePath]] error:nil];
}

-(void) runWinetricksWithArgs: (NSString *)args {
    [self prepareBinariesForWinetricks];
    
    NSString *script = [NSString stringWithFormat:@"cd \"%@/bin\";export PATH=\"$PWD:%@/bin:%@/bin:$PATH:/opt/local/bin:/opt/local/sbin\";export WINEPREFIX=\"%@\";export WINEDEBUG=\"err+all,fixme+all\";DYLD_FALLBACK_LIBRARY_PATH=\"%@\" winetricks --no-isolate%@", [self wineBundlePath], [self wineBundlePath], [self frameworksPath], [self winePrefixPath], [self dyldFallbackPath], args];
    [self setScriptPath:@""];
    [self systemCommand:script shouldWaitForProcess:YES redirectOutput:YES];
    
    [self restoreBinaryNames];
}

-(void) runWineWithWindowsBinary:(NSString *)binaryPath {
    NSString *pathContainingBinary = [binaryPath stringByDeletingLastPathComponent];
    NSString *binaryName = [binaryPath lastPathComponent];
    NSString *script = [NSString stringWithFormat:@"export PATH=\"%@/bin:%@/bin:$PATH:/opt/local/bin:/opt/local/sbin\";export WINEPREFIX=\"%@\";cd \"%@\";DYLD_FALLBACK_LIBRARY_PATH=\"%@\" wine \"%@\" > \"/dev/null\" 2>&1", [self wineBundlePath], [self frameworksPath], [self winePrefixPath], pathContainingBinary, [self dyldFallbackPath], binaryName];
    [self setScriptPath:@""];
    [self systemCommand:script shouldWaitForProcess:YES redirectOutput:NO];
}

-(void) runWineConfig {
    NSString *script = [NSString stringWithFormat:@"export PATH=\"%@/bin:%@/bin:$PATH:/opt/local/bin:/opt/local/sbin\";export WINEPREFIX=\"%@\";DYLD_FALLBACK_LIBRARY_PATH=\"%@\" winecfg > \"%@/Wine.log\" 2>&1", [self wineBundlePath], [self frameworksPath], [self winePrefixPath], [self dyldFallbackPath], [self winePrefixPath]];
    [self setScriptPath:@""];
    [self systemCommand:script shouldWaitForProcess:YES redirectOutput:NO];
    [self keepLauncherAliveUntilWineserverQuit];
}

-(void) initWinePrefix {
    NSString *script = [NSString stringWithFormat:@"export WINEDLLOVERRIDES=\"mscoree,mshtml=\";export PATH=\"%@/bin:%@/bin:$PATH:/opt/local/bin:/opt/local/sbin\";export WINEPREFIX=\"%@\";DYLD_FALLBACK_LIBRARY_PATH=\"%@\" wine wineboot > \"/dev/null\" 2>&1", [self wineBundlePath], [self frameworksPath], [self winePrefixPath], [self dyldFallbackPath]];
    [self setScriptPath:@""];
    
    // Start a new thread with the wine monitor
    dispatch_async(dispatchQueue, ^{
        [self monitorWineProcessForPrefixBuild];
    });
    
    [self systemCommand:script shouldWaitForProcess:YES redirectOutput:NO];
    [self waitForWineserverToExitForMaximumTime:60];
    // Wait for all wine processes to exit
    [NSThread sleepForTimeInterval:5.0f];
    // Now terminate this and all other threads
    [[NSApplication sharedApplication] terminate:nil];
}

- (void)makeCustomBundleIDs {
    BOOL makeCustomBundles = YES;
    
    NSInteger randomIntOne = (NSInteger)(arc4random_uniform(999999));
    
    [self setWineserverBundleName:[NSString stringWithFormat:@"Barrel%ldWineserver", (long)randomIntOne]];
    [self setWineBundleName:[NSString stringWithFormat:@"Barrel%ldWine", (long)randomIntOne]];
    
    // Enumerate Wine's bin folder to look for wine executables
    NSArray *engineBinFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[NSString stringWithFormat:@"%@/bin", [self wineBundlePath]] error:nil];
    for (NSString *filename in engineBinFiles) {
        if ([filename hasPrefix:@"Barrel"]) {
            makeCustomBundles = NO;
            if ([filename hasSuffix:@"Wineserver"]) {
                [self setWineserverBundleName:filename];
            }
            else if ([filename hasSuffix:@"Wine"]) {
                [self setWineBundleName:filename];
            }
        }
    }
    
    if (makeCustomBundles) {
        [[NSFileManager defaultManager] moveItemAtPath:[NSString stringWithFormat:@"%@/bin/wine", [self wineBundlePath]] toPath:[NSString stringWithFormat:@"%@/bin/%@", [self wineBundlePath], [self wineBundleName]] error:nil];
        [[NSFileManager defaultManager] moveItemAtPath:[NSString stringWithFormat:@"%@/bin/wineserver", [self wineBundlePath]] toPath:[NSString stringWithFormat:@"%@/bin/%@", [self wineBundlePath], [self wineserverBundleName]] error:nil];
        [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/bin/wine", [self wineBundlePath]] error:nil];
        [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/bin/wineserver", [self wineBundlePath]] error:nil];
        NSString *wineBash = [NSString stringWithFormat:@"#!/bin/bash\n\"$(dirname \"$0\")/%@\" \"$@\" &",[self wineBundleName]];
        NSString *wineServerBash = [NSString stringWithFormat:@"#!/bin/bash\n\"$(dirname \"$0\")/%@\" \"$@\" &",[self wineserverBundleName]];
        [wineBash writeToFile:[NSString stringWithFormat:@"%@/bin/wine",[self wineBundlePath]] atomically:YES encoding:NSUTF8StringEncoding error:nil];
        [wineServerBash writeToFile:[NSString stringWithFormat:@"%@/bin/wineserver",[self wineBundlePath]] atomically:YES encoding:NSUTF8StringEncoding error:nil];
        [self systemCommand:[NSString stringWithFormat:@"chmod -R 777 \"%@/bin\"",[self wineBundlePath]] shouldWaitForProcess:YES redirectOutput:NO];
        
        // Save the wine and wineserver names in the Info.plist for external access
        NSString *bundleInfoPlistPath = [NSString stringWithFormat:@"%@/Contents/Info.plist", [self bundlePath]];
        NSMutableDictionary *infoPlist = [[NSMutableDictionary alloc] initWithContentsOfFile:bundleInfoPlistPath];
        [infoPlist setValue:[self wineBundleName] forKey:@"BLWineBin"];
        [infoPlist setValue:[self wineserverBundleName] forKey:@"BLWineserverBin"];
        [infoPlist writeToFile:bundleInfoPlistPath atomically:YES];
    }
}

- (void)fixWineTempFolder {
    //make sure the /tmp/.wine-uid folder and lock file are correct since Wine is buggy about it
    NSDictionary *info = [[NSFileManager defaultManager] attributesOfItemAtPath:[self winePrefixPath] error:nil];
    NSString *uid = [NSString stringWithFormat: @"%d", getuid()];
    NSString *inode = [NSString stringWithFormat:@"%lx", [[info objectForKey:NSFileSystemFileNumber] longValue]];
    NSString *deviceId = [NSString stringWithFormat:@"%lx", [[info objectForKey:NSFileSystemNumber] longValue]];
    NSString *pathToWineLockFolder = [NSString stringWithFormat:@"/tmp/.wine-%@/server-%@-%@",uid,deviceId,inode];
    if ([[NSFileManager defaultManager] fileExistsAtPath:pathToWineLockFolder])
    {
        [[NSFileManager defaultManager] removeItemAtPath:pathToWineLockFolder error:nil];
    }
    [[NSFileManager defaultManager] createDirectoryAtPath:pathToWineLockFolder withIntermediateDirectories:YES attributes:nil error:nil];
    [self systemCommand:[NSString stringWithFormat:@"chmod -R 700 \"/tmp/.wine-%@\"",uid] shouldWaitForProcess:YES redirectOutput:NO];
}

- (void)keepLauncherAliveUntilWineserverQuit {
    [NSThread sleepForTimeInterval:10.0f];
    for (;;) {
        BOOL stillRunning = NO;
        NSArray *resultArray = [[self systemCommand:[NSString stringWithFormat:@"ps -eo pcpu,pid,args | grep \"%@\"", [self wineserverBundleName]] shouldWaitForProcess:YES redirectOutput:NO] componentsSeparatedByString:@" "];
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
                NSRange strRange = [test rangeOfString:[self wineserverBundleName]];
                NSRange stuckRange = [test rangeOfString:@")"];
                if ((strRange.location != NSNotFound && stuckRange.location == NSNotFound) && ![(NSString *)[cleanArray objectAtIndex:(i-1)] isEqualToString:@"grep"]) {
                    stillRunning = YES;
                }
            }
        }
        if (!stillRunning) {
            NSLog(@"Wineserver not running");
            return;
        }
        [NSThread sleepForTimeInterval:1.0f];
    }
}

- (void)waitForWineserverToExitForMaximumTime:(NSInteger)seconds {
    [NSThread sleepForTimeInterval:10.0f];
    for (NSInteger i=0; i<seconds; i++) {
        BOOL stillRunning = NO;
        NSArray *resultArray = [[self systemCommand:[NSString stringWithFormat:@"ps -eo pcpu,pid,args | grep \"%@\"", [self wineserverBundleName]] shouldWaitForProcess:YES redirectOutput:NO] componentsSeparatedByString:@" "];
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
                NSRange strRange = [test rangeOfString:[self wineserverBundleName]];
                NSRange stuckRange = [test rangeOfString:@")"];
                if ((strRange.location != NSNotFound && stuckRange.location == NSNotFound) && ![(NSString *)[cleanArray objectAtIndex:(i-1)] isEqualToString:@"grep"]) {
                    stillRunning = YES;
                }
            }
        }
        if (!stillRunning) {
            NSLog(@"Wineserver not running");
            return;
        }
        [NSThread sleepForTimeInterval:1.0f];
    }
    
    // Looks like wine is still running, which is not normal.
    // Kill all wine and wineserver processes
    [self killAllWineProcesses];
}

- (void)killAllWineProcesses {
    NSLog(@"Forcefully killing wine..");
    [self systemCommand:[NSString stringWithFormat:@"killall -9 \"%@\" > /dev/null 2>&1", [self wineBundleName]] shouldWaitForProcess:YES redirectOutput:NO];
    [self systemCommand:[NSString stringWithFormat:@"killall -9 \"%@\" > /dev/null 2>&1", [self wineserverBundleName]] shouldWaitForProcess:YES redirectOutput:NO];
}

- (void)monitorWineProcessForPrefixBuild {
    // ----------- WINE BUG WORKAROUND ----------- //
    /* Wait 5 seconds for normal wineprefix build operation.
     * If we still have wine processes running after 5 seconds
     * this means that wine is stuck at 99% CPU
     * so find the stuck process and terminate it to give the
     * wineboot command a chance to finish */
    [NSThread sleepForTimeInterval:10.0f];
    int loopCount = 30;
    int i;
    for (i=0; i < loopCount; ++i)
    {
        NSArray *resultArray = [[self systemCommand:@"ps -eo pcpu,pid,args | sort -rk 1 | grep \"wine\"" shouldWaitForProcess:YES redirectOutput:NO] componentsSeparatedByString:@" "];
        NSMutableArray *cleanArray = [[NSMutableArray alloc] init];
        // Go through the resultArray and clear out any empty items
        for (NSString *item in resultArray) {
            if ([item length] > 0) {
                [cleanArray addObject:item];
            }
        }
        
        if ([[cleanArray objectAtIndex:0] floatValue] > 90.0 && [[cleanArray objectAtIndex:2] rangeOfString:@"grep"].location == NSNotFound)
        {
            NSLog(@"Found stuck wine process with PID: %@, killing...", (NSString *)[cleanArray objectAtIndex:1]);
            // Send the kill signal as a system command
            [self systemCommand:[NSString stringWithFormat:@"kill -9 %@", (NSString *)[cleanArray objectAtIndex:1]] shouldWaitForProcess:YES redirectOutput:NO];
            break;
        }
        [NSThread sleepForTimeInterval:1.0f];
    }
}

- (NSString *)systemCommand:(NSString *)command shouldWaitForProcess:(BOOL)waitForProcess redirectOutput:(BOOL)redirect {
    return [self systemCommand:command shouldWaitForProcess:waitForProcess redirectOutput:redirect logOutputToFilePath:@""];
}

- (NSString *)systemCommand:(NSString *)command shouldWaitForProcess:(BOOL)waitForProcess redirectOutput:(BOOL)redirect logOutputToFilePath:(NSString *)logFilePath
{
	FILE *fp;
	char buff[512];
	NSMutableString *returnString = [[NSMutableString alloc] init];
	fp = popen([command cStringUsingEncoding:NSUTF8StringEncoding], "r");
    if (waitForProcess) {
        while (fgets( buff, sizeof buff, fp))
        {
            [returnString appendString:[NSString stringWithCString:buff encoding:NSUTF8StringEncoding]];
            if (redirect) {
                // NSLog(@"%@", [NSString stringWithCString:buff encoding:NSUTF8StringEncoding]);
                printf("%s", buff);
            }
            else if ([logFilePath length] > 0) {
                NSFileHandle *aFileHandle;
                NSString *aFile;
                
                aFile = [NSString stringWithString:logFilePath];
                aFileHandle = [NSFileHandle fileHandleForWritingAtPath:aFile];
                [aFileHandle truncateFileAtOffset:[aFileHandle seekToEndOfFile]];
                [aFileHandle writeData: [[NSString stringWithCString:buff encoding:NSUTF8StringEncoding] dataUsingEncoding:NSUTF8StringEncoding]];
            }
        }
        pclose(fp);
        returnString = [NSMutableString stringWithString:[returnString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
    }
	return [NSString stringWithString:returnString];
}

@end
