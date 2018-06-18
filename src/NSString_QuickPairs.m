//
//  NSString_QuickPairs.m
//  linda-mac
//
//  Created by Brendan Johnson on 17/6/18.
//

#import <Foundation/Foundation.h>
#import "NSString_QuickPairs.h"

@implementation NSString (NSString_QuickPairs)
-(NSString *) quickPairs{
    NSMutableArray* pairs = [[NSMutableArray alloc] init];
    for (NSInteger charIdx=0; charIdx<self.length; charIdx+=2) {
        [pairs addObject:[self substringWithRange:NSMakeRange(charIdx, MIN(2,self.length-charIdx))]];
    }
    NSString* joinedPairs = [pairs componentsJoinedByString:@" "];
    NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern: @"(z)"
                                                                           options: NSRegularExpressionCaseInsensitive
                                                                             error: nil];
    
    return [regex stringByReplacingMatchesInString: joinedPairs
                                                          options: 0
                                                            range: NSMakeRange(0, [joinedPairs length])
                                                     withTemplate: @""];
}
@end
