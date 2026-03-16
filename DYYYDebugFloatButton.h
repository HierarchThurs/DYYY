#import <UIKit/UIKit.h>

FOUNDATION_EXPORT NSInteger const DYYYDebugFloatButtonTag;

@interface DYYYDebugFloatButton : UIButton

- (void)saveButtonPosition;
- (void)loadSavedPosition;

@end
