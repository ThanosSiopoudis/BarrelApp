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

#import "AppCakeAPI.h"
#import "AC_Game.h"
#import "AC_WineBuild.h"
#import "AC_User.h"

@interface AppCakeAPI()


@end

@implementation AppCakeAPI

- (void)searchDBForGameWithName:(NSString *)gameName toBlock:(void (^)(RKObjectRequestOperation *, RKMappingResult *))completionBlock failBlock:(void (^)(RKObjectRequestOperation *, NSError *))errorBlock
{
    RKObjectMapping *gameMapping = [RKObjectMapping mappingForClass:[AC_Game class]];
    [gameMapping addAttributeMappingsFromDictionary:@{
        @"id"           : @"id",
        @"identifiers"  : @"identifiers",
        @"name"         : @"name",
        @"wineBuildID"  : @"wineBuildID",
        @"description"  : @"description",
        @"userID"       : @"userID",
        @"coverArtURL"  : @"coverArtURL"
     }];
    
    RKResponseDescriptor *responseDescriptor = [RKResponseDescriptor responseDescriptorWithMapping:gameMapping method:RKRequestMethodGET pathPattern:nil keyPath:@"results" statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)];
    
    // Escape the string for URL use
    // See: http://stackoverflow.com/questions/8086584/objective-c-url-encoding
    NSString *escapedString = (NSString *)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(
                                                                                                    NULL,
                                                                                                    (__bridge CFStringRef) gameName,
                                                                                                    NULL,
                                                                                                    CFSTR("!*'();:@&=+$,/?%#[]"),
                                                                                                    kCFStringEncodingUTF8));
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@?gameName=%@", @"http://api.appcake.co.uk/Games/searchForGame.json", escapedString]];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    RKObjectRequestOperation *objectRequestOperation = [[RKObjectRequestOperation alloc] initWithRequest:request responseDescriptors:@[ responseDescriptor ]];
    [objectRequestOperation setCompletionBlockWithSuccess:completionBlock failure:errorBlock];
    
    [objectRequestOperation start];
}

- (void)listOfAllWineBuildsToBlock:(void (^)(RKObjectRequestOperation *, RKMappingResult *))completionBlock failBlock:(void (^)(RKObjectRequestOperation *, NSError *))errorBlock
{
    RKObjectMapping *wineBuildsMapping = [RKObjectMapping mappingForClass:[AC_WineBuild class]];
    [wineBuildsMapping addAttributeMappingsFromDictionary:@{
        @"WineBuild.id":          @"id",
        @"WineBuild.name":        @"name",
        @"WineBuild.archivePath": @"archivePath"
     }];
    
    RKResponseDescriptor *responseDescriptor = [RKResponseDescriptor responseDescriptorWithMapping:wineBuildsMapping method:RKRequestMethodGET pathPattern:nil keyPath:@"wineBuilds" statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)];
    
    NSURL *url = [NSURL URLWithString:@"http://api.appcake.co.uk/WineBuilds/getAllWineBuilds.json"];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    RKObjectRequestOperation *objectRequestOperation = [[RKObjectRequestOperation alloc] initWithRequest:request responseDescriptors:@[ responseDescriptor ]];
    [objectRequestOperation setCompletionBlockWithSuccess:completionBlock
    failure:errorBlock];
    
    [objectRequestOperation start];
}

- (void)registerUserWithUsername:(NSString *)username password:(NSString *)password email:(NSString *)email toBlock:(void (^)(RKObjectRequestOperation *operation, RKMappingResult *mappingResult))completionBlock failBlock:(void (^)(RKObjectRequestOperation *operation, NSError *error))errorBlock
{
    RKObjectMapping *userMap = [RKObjectMapping mappingForClass:[AC_User class]];
}

@end
