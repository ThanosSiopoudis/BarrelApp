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
#import "BL_GenericAPIResponse.h"

@interface AppCakeAPI()


@end

@implementation AppCakeAPI

- (void)searchDBForGameWithName:(NSString *)gameName orIdentifier:(NSString *)identifier toBlock:(void (^)(RKObjectRequestOperation *, RKMappingResult *))completionBlock failBlock:(void (^)(RKObjectRequestOperation *, NSError *))errorBlock
{
    RKObjectMapping *gameMapping = [RKObjectMapping mappingForClass:[AC_Game class]];
    [gameMapping addAttributeMappingsFromDictionary:@{
        @"Game.id"           : @"id",
        @"Game.identifiers"  : @"identifiers",
        @"Game.name"         : @"name",
        @"Game.wineBuildID"  : @"wineBuildID",
        @"Game.description"  : @"description",
        @"Game.userID"       : @"userID",
        @"Game.coverArtURL"  : @"coverArtURL",
        @"Game.recipeURL"    : @"recipeURL",
        @"Game.engineURL"    : @"engineURL"
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
    NSString *escapedIdentifier = (NSString *)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(
                                                                                                    NULL,
                                                                                                    (__bridge CFStringRef) identifier,
                                                                                                    NULL,
                                                                                                    CFSTR("!*'();:@&=+$,/?%#[]"),
                                                                                                    kCFStringEncodingUTF8));
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@?gameName=%@&identifier=%@", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"BLApiServerURL"], @"/Games/searchForGame.json", escapedString, escapedIdentifier]];
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
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/WineBuilds/getAllWineBuilds.json", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"BLApiServerURL"]]];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    RKObjectRequestOperation *objectRequestOperation = [[RKObjectRequestOperation alloc] initWithRequest:request responseDescriptors:@[ responseDescriptor ]];
    [objectRequestOperation setCompletionBlockWithSuccess:completionBlock
    failure:errorBlock];
    
    [objectRequestOperation start];
}

- (void)registerUserWithUsername:(NSString *)username password:(NSString *)password email:(NSString *)email toBlock:(void (^)(RKObjectRequestOperation *operation, RKMappingResult *mappingResult))completionBlock failBlock:(void (^)(RKObjectRequestOperation *operation, NSError *error))errorBlock
{
    /*  We need to look if the user exists in the database before adding him
     *  so, request the user data and only proceed when the result set is empty 
     */
    RKObjectMapping *userMap = [RKObjectMapping mappingForClass:[AC_User class]];
    [userMap addAttributeMappingsFromDictionary:@{
        @"User.id":          @"userID",
        @"User.username":    @"username",
        @"User.password":    @"password",
        @"User.email":       @"email"
    }];
    
    RKResponseDescriptor *responseDescriptor = [RKResponseDescriptor responseDescriptorWithMapping:userMap method:RKRequestMethodGET pathPattern:nil keyPath:@"results" statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)];
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/Users/searchForUser.json?username=%@", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"BLApiServerURL"], username]];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    RKObjectRequestOperation *objectRequestOperation = [[RKObjectRequestOperation alloc] initWithRequest:request responseDescriptors:@[ responseDescriptor ]];
    [objectRequestOperation setCompletionBlockWithSuccess:^(RKObjectRequestOperation *inOp, RKMappingResult *inMapResult){
        if ([inMapResult count] > 0) {
            // Create a custom error and throw it
            NSMutableDictionary *errorDetails = [NSMutableDictionary dictionary];
            [errorDetails setValue:@"User already exists. Please choose a different username and try again." forKey:NSLocalizedDescriptionKey];
            NSError *throwableError = [NSError errorWithDomain:@"Barrel.API" code:200 userInfo:errorDetails];
            errorBlock(inOp, throwableError);
        }
        else {
            // We found no user, so create the user
            RKObjectMapping *responseMapping = [RKObjectMapping mappingForClass:[BL_GenericAPIResponse class]];
            [responseMapping addAttributeMappingsFromDictionary:@{
                @"responseCode": @"responseCode",
                @"responseDescription": @"responseDescription"
            }];
            
            RKObjectMapping *requestMapping = [RKObjectMapping requestMapping];
            [requestMapping addAttributeMappingsFromArray:@[@"username", @"password", @"email"]];
            
            RKRequestDescriptor *requestDescriptor = [RKRequestDescriptor requestDescriptorWithMapping:requestMapping objectClass:[AC_User class] rootKeyPath:nil method:RKRequestMethodPOST];
            RKResponseDescriptor *innerResponseDescriptor = [RKResponseDescriptor responseDescriptorWithMapping:responseMapping method:RKRequestMethodPOST pathPattern:nil keyPath:@"results" statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)];
            
            NSURL *registerURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@/Users/", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"BLApiServerURL"]]];
            RKObjectManager *manager = [RKObjectManager managerWithBaseURL:registerURL];
            [manager addRequestDescriptor:requestDescriptor];
            [manager addResponseDescriptor:innerResponseDescriptor];
            
            AC_User *user = [AC_User new];
            user.username = username;
            user.password = password;
            user.email = email;
            
            [manager postObject:user path:@"registerNewUser.json" parameters:nil success:completionBlock failure:errorBlock];
        }
    } failure:errorBlock];
    
    [objectRequestOperation start];
}

- (void)loginUserWithUsername: (NSString *)username toBlock:(void (^)(RKObjectRequestOperation *operation, RKMappingResult *mappingResult))completionBlock failBlock:(void (^)(RKObjectRequestOperation *operation, NSError *error))errorBlock {
    
    RKObjectMapping *userMap = [RKObjectMapping mappingForClass:[AC_User class]];
    [userMap addAttributeMappingsFromDictionary:@{
        @"User.id":          @"userID",
        @"User.username":    @"username",
        @"User.password":    @"password",
        @"User.email":       @"email"
    }];
    
    RKResponseDescriptor *responseDescriptor = [RKResponseDescriptor responseDescriptorWithMapping:userMap method:RKRequestMethodGET pathPattern:nil keyPath:@"results" statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)];
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/Users/searchForUser.json?username=%@", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"BLApiServerURL"], username]];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    RKObjectRequestOperation *objectRequestOperation = [[RKObjectRequestOperation alloc] initWithRequest:request responseDescriptors:@[ responseDescriptor ]];
    [objectRequestOperation setCompletionBlockWithSuccess:completionBlock failure:errorBlock];
    
    [objectRequestOperation start];
}

- (void)uploadGame:     (NSString *)gameName
        fromVolName:    (NSString *)volName
        wineBuildID:    (NSString *)wineBuildID
        fromAuthor:     (NSString *)authorID
        recipePath:     (NSString *)recipePath
        toBlock:        (void (^)(RKObjectRequestOperation *operation, RKMappingResult *mappingResult))completionBlock
        failBlock:      (void (^)(RKObjectRequestOperation *operation, NSError *error))errorBlock
{
    AC_Game *game = [AC_Game new];
    game.name = gameName;
    game.identifiers = volName;
    game.wineBuildID = [wineBuildID integerValue];
    game.userID = [authorID integerValue];
    
    RKObjectMapping *requestMapping = [RKObjectMapping requestMapping];
    [requestMapping addAttributeMappingsFromArray:@[@"name", @"identifiers", @"wineBuildID", @"userID", @"game"]];
    
    RKObjectMapping *responseMapping = [RKObjectMapping mappingForClass:[BL_GenericAPIResponse class]];
    [responseMapping addAttributeMappingsFromDictionary:@{
        @"gameID": @"responseID",
        @"responseCode": @"responseCode",
        @"responseDescription": @"responseDescription"
    }];
    
    RKRequestDescriptor *requestDescriptor = [RKRequestDescriptor requestDescriptorWithMapping:requestMapping objectClass:[AC_Game class] rootKeyPath:nil method:RKRequestMethodPOST];
    RKResponseDescriptor *innerResponseDescriptor = [RKResponseDescriptor responseDescriptorWithMapping:responseMapping method:RKRequestMethodPOST pathPattern:nil keyPath:@"results" statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)];
    
    // Serialize the Article attributes then attach a file
    RKObjectManager *manager = [RKObjectManager managerWithBaseURL:[NSURL URLWithString:[[NSBundle mainBundle] objectForInfoDictionaryKey:@"BLApiServerURL"]]];
    
    [manager addResponseDescriptor:innerResponseDescriptor];
    [manager addRequestDescriptor:requestDescriptor];
    
    NSMutableURLRequest *request = [manager multipartFormRequestWithObject:game method:RKRequestMethodPOST path:@"/Games/addNewGame.json" parameters:nil constructingBodyWithBlock:^(id<AFMultipartFormData> formData) {
        [formData appendPartWithFileData:[NSData dataWithContentsOfFile:recipePath] name:@"game" fileName:[recipePath lastPathComponent] mimeType:@"application/xml"];
    }];
    
    RKObjectRequestOperation *operation = [manager objectRequestOperationWithRequest:request success:completionBlock failure:errorBlock];
    [manager enqueueObjectRequestOperation:operation]; // NOTE: Must be enqueued rather than started
}

- (void) uploadArtwork:(NSString *)artworkPath forGameID:(NSInteger)gameID toBlock: (void (^)(RKObjectRequestOperation *operation, RKMappingResult *mappingResult)) completionBlock failBlock: (void (^)(RKObjectRequestOperation *operation, NSError *error))errorBlock
{
    RKLogConfigureByName("RestKit/Network", RKLogLevelTrace);
    AC_Game *game = [AC_Game new];
    game.id = gameID;
    
    RKObjectMapping *requestMapping = [RKObjectMapping requestMapping];
    [requestMapping addAttributeMappingsFromArray:@[@"id"]];
    
    RKObjectMapping *responseMapping = [RKObjectMapping mappingForClass:[BL_GenericAPIResponse class]];
    [responseMapping addAttributeMappingsFromDictionary:@{
        @"responseCode": @"responseCode",
        @"responseDescription": @"responseDescription"
    }];
    
    RKRequestDescriptor *requestDescriptor = [RKRequestDescriptor requestDescriptorWithMapping:requestMapping objectClass:[AC_Game class] rootKeyPath:nil method:RKRequestMethodPOST];
    RKResponseDescriptor *innerResponseDescriptor = [RKResponseDescriptor responseDescriptorWithMapping:responseMapping method:RKRequestMethodPOST pathPattern:nil keyPath:@"results" statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)];
    
    // Serialize the Article attributes then attach a file
    RKObjectManager *manager = [RKObjectManager managerWithBaseURL:[NSURL URLWithString:[[NSBundle mainBundle] objectForInfoDictionaryKey:@"BLApiServerURL"]]];
    
    [manager addResponseDescriptor:innerResponseDescriptor];
    [manager addRequestDescriptor:requestDescriptor];
    
    NSMutableURLRequest *request = [manager multipartFormRequestWithObject:game method:RKRequestMethodPOST path:@"/Games/updateGameArtwork.json" parameters:nil constructingBodyWithBlock:^(id<AFMultipartFormData> formData) {
        [formData appendPartWithFileData:[NSData dataWithContentsOfFile:artworkPath] name:@"coverArtURL" fileName:[artworkPath lastPathComponent] mimeType:@"image/png"];
    }];
    
    RKObjectRequestOperation *operation = [manager objectRequestOperationWithRequest:request success:completionBlock failure:errorBlock];
    [manager enqueueObjectRequestOperation:operation]; // NOTE: Must be enqueued rather than started
}

- (void) pushIdentifierToServer:(NSString *)identifier forGameWithID:(NSString *)gameID toBlock:(void (^)(RKObjectRequestOperation *operation, RKMappingResult *mappingResult))completionBlock failBlock:(void (^)(RKObjectRequestOperation *operation, NSError *error))errorBlock {
    RKObjectMapping *responseMapping = [RKObjectMapping mappingForClass:[BL_GenericAPIResponse class]];
    [responseMapping addAttributeMappingsFromDictionary:@{
        @"responseCode": @"responseCode",
        @"responseDescription": @"responseDescription"
    }];
    
    RKResponseDescriptor *responseDescriptor = [RKResponseDescriptor responseDescriptorWithMapping:responseMapping method:RKRequestMethodGET pathPattern:nil keyPath:@"results" statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)];
    
    // Escape the string for URL use
    // See: http://stackoverflow.com/questions/8086584/objective-c-url-encoding
    NSString *escapedIdentifier = (NSString *)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(
                                                                                                    NULL,
                                                                                                    (__bridge CFStringRef) identifier,
                                                                                                    NULL,
                                                                                                    CFSTR("!*'();:@&=+$,/?%#[]"),
                                                                                                    kCFStringEncodingUTF8));
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@?identifier=%@&gameID=%@", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"BLApiServerURL"], @"/Games/saveGameIdentifier.json", escapedIdentifier, gameID]];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    RKObjectRequestOperation *objectRequestOperation = [[RKObjectRequestOperation alloc] initWithRequest:request responseDescriptors:@[ responseDescriptor ]];
    [objectRequestOperation setCompletionBlockWithSuccess:completionBlock failure:errorBlock];
    
    [objectRequestOperation start];
}
@end
