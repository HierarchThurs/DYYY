#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^DYYYDebugExportCompletion)(NSArray<NSURL *> *_Nullable exportFileURLs, NSArray<NSString *> *_Nullable tempFilePaths, NSError *_Nullable error);

typedef NS_ENUM(NSInteger, DYYYDebugExportType) {
    DYYYDebugExportTypeCurrentPageHierarchy = 0,
    DYYYDebugExportTypeWindowHierarchy,
    DYYYDebugExportTypeKeyClassMethods,
    DYYYDebugExportTypeObjectChain,
    DYYYDebugExportTypeModelFieldValues,
    DYYYDebugExportTypeABTestSnapshot,
    DYYYDebugExportTypeABTestHitKeys,
    DYYYDebugExportTypeAllCurrentPageDebugData,
};

@interface DYYYDebugExportContext : NSObject

@property(nonatomic, strong, nullable) UIWindow *activeWindow;
@property(nonatomic, strong, nullable) UIViewController *windowRootViewController;
@property(nonatomic, strong, nullable) UIViewController *topVisibleViewController;
@property(nonatomic, strong, nullable) UIViewController *sourceBusinessViewController;
@property(nonatomic, strong, nullable) UIViewController *debugMenuController;
@property(nonatomic, strong, nullable) UIView *debugButtonView;
@property(nonatomic, copy, nullable) NSString *batchID;
@property(nonatomic, copy, nullable) NSArray<UIViewController *> *cachedControllerChain;
@property(nonatomic, copy, nullable) NSArray<UIViewController *> *cachedVisibleSiblingControllers;
@property(nonatomic, copy, nullable) NSArray<NSDictionary *> *cachedKeyObjectEntries;
@property(nonatomic, copy, nullable) NSArray<NSDictionary *> *cachedKeyClassEntries;

@end

@interface DYYYDebugHelper : NSObject

+ (void)exportCurrentPageHierarchyFromContext:(DYYYDebugExportContext *)context completion:(DYYYDebugExportCompletion)completion;
+ (void)exportWindowHierarchyFromContext:(DYYYDebugExportContext *)context completion:(DYYYDebugExportCompletion)completion;
+ (void)exportDebugDataForType:(DYYYDebugExportType)type fromContext:(DYYYDebugExportContext *)context completion:(DYYYDebugExportCompletion)completion;
+ (void)exportAllDebugDataFromContext:(DYYYDebugExportContext *)context completion:(DYYYDebugExportCompletion)completion;

@end

NS_ASSUME_NONNULL_END
