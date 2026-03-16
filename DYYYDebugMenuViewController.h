#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface DYYYDebugMenuAction : NSObject

@property(nonatomic, copy) NSString *title;
@property(nonatomic, copy, nullable) NSString *detail;
@property(nonatomic, copy) dispatch_block_t handler;

+ (instancetype)actionWithTitle:(NSString *)title detail:(nullable NSString *)detail handler:(dispatch_block_t)handler;

@end

@interface DYYYDebugMenuViewController : UIViewController

@property(nonatomic, copy) NSString *menuTitleText;
@property(nonatomic, copy, nullable) NSString *menuMessageText;
@property(nonatomic, copy) NSArray<DYYYDebugMenuAction *> *actions;
@property(nonatomic, copy, nullable) dispatch_block_t onClose;

+ (UIViewController *)showWithTitle:(NSString *)title
                            message:(nullable NSString *)message
                            actions:(NSArray<DYYYDebugMenuAction *> *)actions
               onPresentingViewController:(UIViewController *)presentingViewController
                           closeAction:(nullable dispatch_block_t)closeAction;

@end

NS_ASSUME_NONNULL_END
