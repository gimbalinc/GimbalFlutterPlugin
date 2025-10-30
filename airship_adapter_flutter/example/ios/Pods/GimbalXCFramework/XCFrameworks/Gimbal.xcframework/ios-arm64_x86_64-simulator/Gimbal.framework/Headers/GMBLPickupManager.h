//
//  GMBLPickupManager.h
//  Gimbal-SDK
//
//  Created by Andrew Tran on 6/9/20.
//  Copyright © 2020 Gimbal. All rights reserved.
//

#import <Foundation/Foundation.h>

@class GMBLPickupManager;
@class GMBLPickup;
@class GMBLAttributes;

typedef NS_ENUM(NSInteger, GMBLPickupCompletionReason) {
    GMBLPickupCompletionReasonFulfilled NS_SWIFT_NAME(fulfilled) = 0,
    GMBLPickupCompletionReasonAborted NS_SWIFT_NAME(aborted),
    GMBLPickupCompletionReasonOther NS_SWIFT_NAME(other),
} NS_SWIFT_NAME(PickupCompletionReason);

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(PickupManagerDelegate)
@protocol GMBLPickupManagerDelegate <NSObject>

@optional
- (void)pickupManager:(GMBLPickupManager *)pickupManager didUpdateStateForPickup:(GMBLPickup *)pickup;
- (void)pickupManager:(GMBLPickupManager *)pickupManager didDetectError:(NSError *)error forPickup:(GMBLPickup * __nullable)pickup;
@end

NS_ASSUME_NONNULL_END

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(PickupManager)
@interface GMBLPickupManager : NSObject

@property (nonatomic, weak) id<GMBLPickupManagerDelegate> delegate;
- (NSArray<GMBLPickup *> *)monitoredPickups;

- (void)startMonitoringPickup:(GMBLPickup *)pickup;

- (void)stopMonitoringPickup:(GMBLPickup *)pickup
                      reason:(GMBLPickupCompletionReason)completionReason;

- (void)setAwaitingItem:(BOOL)awaitingItem
              forPickup:(GMBLPickup *)pickup;

@end

NS_ASSUME_NONNULL_END
