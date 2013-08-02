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

#import "BLPrefUserController.h"
#import "OETextField.h"

@interface BLPrefUserController () {
    IBOutlet OETextField *usernameField, *emailField;
    IBOutlet NSSecureTextField *pwdField;
}

- (IBAction)didSelectLoginButton:(id)sender;
- (IBAction)didSelectRegisterButton:(id)sender;

@end

@implementation BLPrefUserController

- (void)awakeFromNib {
    // hide focus ring
    [usernameField setFocusRingType:NSFocusRingTypeNone];
    [pwdField setFocusRingType:NSFocusRingTypeNone];
    [emailField setFocusRingType:NSFocusRingTypeNone];
}

#pragma mark -
#pragma mark OEPreferencePane Protocol

- (NSImage *)icon
{
    return [NSImage imageNamed:@"user_tab_icon"];
}

- (NSString *)title
{
    return @"User Account";
}

- (NSString *)localizedTitle
{
    return NSLocalizedString([self title], "");
}

- (NSSize)viewSize
{
    return NSMakeSize(423, 178);
}

#pragma mark -
#pragma mark Interface Actions
- (IBAction)didSelectLoginButton:(id)sender {
    
}

- (IBAction)didSelectRegisterButton:(id)sender {
    
}

@end
