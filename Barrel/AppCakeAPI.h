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

#import <Foundation/Foundation.h>
#import <RestKit/RestKit.h>

@interface AppCakeAPI : NSObject

- (void)listOfAllWineBuildsToBlock:(void (^)(RKObjectRequestOperation *operation, RKMappingResult *mappingResult))completionBlock
failBlock:(void (^)(RKObjectRequestOperation *operation, NSError *error))errorBlock;
- (void)searchDBForGameWithName:(NSString *)gameName orIdentifier:(NSString *)identifier toBlock:(void (^)(RKObjectRequestOperation *, RKMappingResult *))completionBlock failBlock:(void (^)(RKObjectRequestOperation *, NSError *))errorBlock;
- (void)registerUserWithUsername:(NSString *)username password:(NSString *)password email:(NSString *)email toBlock:(void (^)(RKObjectRequestOperation *operation, RKMappingResult *mappingResult))completionBlock failBlock:(void (^)(RKObjectRequestOperation *operation, NSError *error))errorBlock;
- (void)loginUserWithUsername: (NSString *)username toBlock:(void (^)(RKObjectRequestOperation *operation, RKMappingResult *mappingResult))completionBlock failBlock:(void (^)(RKObjectRequestOperation *operation, NSError *error))errorBlock;
- (void)uploadGame: (NSString *)gameName fromVolName: (NSString *)volName wineBuildID: (NSString *)wineBuildID fromAuthor: (NSString *)authorID recipePath: (NSString *)recipePath toBlock: (void (^)(RKObjectRequestOperation *operation, RKMappingResult *mappingResult))completionBlock failBlock: (void (^)(RKObjectRequestOperation *operation, NSError *error))errorBlock;
- (void) uploadArtwork:(NSString *)artworkPath forGameID:(NSInteger)gameID toBlock: (void (^)(RKObjectRequestOperation *operation, RKMappingResult *mappingResult)) completionBlock failBlock: (void (^)(RKObjectRequestOperation *operation, NSError *error))errorBlock;


@end
