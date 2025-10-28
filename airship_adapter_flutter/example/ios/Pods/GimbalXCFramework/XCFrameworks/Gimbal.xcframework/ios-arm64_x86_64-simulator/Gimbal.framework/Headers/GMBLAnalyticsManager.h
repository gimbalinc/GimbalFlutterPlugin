//
//  GMBLAnalyticsManager.h
//  Gimbal-SDK
//
//  Created by Yaro on 5/17/22.
//  Copyright © 2022 Gimbal. All rights reserved.
//

#import <Foundation/Foundation.h>


NS_SWIFT_NAME(AnalyticsManager)
@interface GMBLAnalyticsManager : NSObject

+ (GMBLAnalyticsManager *)sharedInstance;

- (void)setUserAnalyticsID:(NSString *)_id;
- (void)deleteUserAnalyticsID;

@end
