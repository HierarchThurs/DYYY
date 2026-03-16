#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^DYYYDebugExportCompletion)(NSArray<NSURL *> *_Nullable exportFileURLs, NSArray<NSString *> *_Nullable tempFilePaths, NSError *_Nullable error);

@interface DYYYDebugExportContext : NSObject

@property(nonatomic, strong, nullable) UIWindow *activeWindow;
@property(nonatomic, strong, nullable) UIViewController *windowRootViewController;
@property(nonatomic, strong, nullable) UIViewController *topVisibleViewController;
@property(nonatomic, strong, nullable) UIViewController *sourceBusinessViewController;
@property(nonatomic, strong, nullable) UIViewController *debugMenuController;
@property(nonatomic, strong, nullable) UIView *debugButtonView;

@end

@interface DYYYDebugHelper : NSObject

+ (void)exportCurrentPageHierarchyFromContext:(DYYYDebugExportContext *)context completion:(DYYYDebugExportCompletion)completion;
+ (void)exportWindowHierarchyFromContext:(DYYYDebugExportContext *)context completion:(DYYYDebugExportCompletion)completion;

@end

NS_ASSUME_NONNULL_END
