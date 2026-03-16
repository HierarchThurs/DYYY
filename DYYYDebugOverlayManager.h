#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DYYYDebugOverlayManager : NSObject

+ (instancetype)sharedManager;
- (void)setDebugModeEnabled:(BOOL)enabled;
- (void)refreshDebugButtonAttachment;

@end

NS_ASSUME_NONNULL_END
