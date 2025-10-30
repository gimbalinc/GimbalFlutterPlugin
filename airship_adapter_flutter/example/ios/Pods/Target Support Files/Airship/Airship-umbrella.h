#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "AirshipBasementLib.h"
#import "UAAppIntegrationDelegate.h"
#import "UAAutoIntegration.h"
#import "UACompression.h"
#import "AirshipKit.h"

FOUNDATION_EXPORT double AirshipKitVersionNumber;
FOUNDATION_EXPORT const unsigned char AirshipKitVersionString[];

