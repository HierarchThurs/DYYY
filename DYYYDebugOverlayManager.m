#import "DYYYDebugOverlayManager.h"

#import <objc/runtime.h>

#import "DYYYABTestHook.h"
#import "DYYYBackupPickerDelegate.h"
#import "DYYYDebugFloatButton.h"
#import "DYYYDebugHelper.h"
#import "DYYYDebugMenuViewController.h"
#import "DYYYUtils.h"

static NSString *const kDYYYEnableDebugModeKey = @"DYYYEnableDebugMode";
static NSString *const kDYYYDebugOverlayLaunchGuardPendingKey = @"DYYYDebugOverlayLaunchGuardPending";
static NSString *const kDYYYDebugOverlayRecoveryNoticePendingKey = @"DYYYDebugOverlayRecoveryNoticePending";
static NSString *const kDYYYDebugOverlayStartupLogFilename = @"debug_overlay_startup.log";
static CGFloat const kDYYYDebugButtonSize = 48.0;
static NSTimeInterval const kDYYYDebugButtonAttachDelay = 0.35;
static NSTimeInterval const kDYYYDebugButtonStartupValidationDelay = 0.15;
static NSUInteger const kDYYYDebugOverlayStartupLogMaxLines = 200;

@interface DYYYDebugOverlayManager ()

@property(nonatomic, assign) BOOL debugModeEnabled;
@property(nonatomic, assign) BOOL pendingStartupAttachment;
@property(nonatomic, assign) NSUInteger attachmentGeneration;
@property(nonatomic, strong) DYYYDebugFloatButton *debugButton;
@property(nonatomic, strong, nullable) UIViewController *debugMenuController;
@property(nonatomic, strong, nullable) DYYYDebugExportContext *activeExportContext;
@property(nonatomic, strong, nullable) id windowObserver;
@property(nonatomic, strong, nullable) id didBecomeActiveObserver;
@property(nonatomic, strong, nullable) id willEnterForegroundObserver;

@end

@implementation DYYYDebugOverlayManager

+ (instancetype)sharedManager {
    static DYYYDebugOverlayManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      manager = [[self alloc] init];
    });
    return manager;
}

- (instancetype)init {
    self = [super init];
    if (!self) {
        return nil;
    }

    [self registerObservers];
    _debugModeEnabled = NO;
    _pendingStartupAttachment = NO;
    _attachmentGeneration = 0;
    return self;
}

- (void)bootstrapFromStoredSettings {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
          [self bootstrapFromStoredSettings];
        });
        return;
    }

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL shouldEnableDebugMode = [defaults boolForKey:kDYYYEnableDebugModeKey];
    BOOL hasPendingLaunchGuard = [defaults boolForKey:kDYYYDebugOverlayLaunchGuardPendingKey];
    [self recordStartupLog:[NSString stringWithFormat:@"bootstrap: debug=%@ launchGuard=%@",
                                                      shouldEnableDebugMode ? @"YES" : @"NO",
                                                      hasPendingLaunchGuard ? @"YES" : @"NO"]];

    if (!shouldEnableDebugMode) {
        self.debugModeEnabled = NO;
        self.pendingStartupAttachment = NO;
        [self clearStartupLaunchGuardIfNeededWithReason:@"bootstrap_debug_disabled"];
        [self teardownDebugOverlay];
        [self handlePendingRecoveryNoticeIfNeeded];
        return;
    }

    if (hasPendingLaunchGuard) {
        [self autoRecoverFromPendingStartupGuard];
        [self handlePendingRecoveryNoticeIfNeeded];
        return;
    }

    self.debugModeEnabled = YES;
    self.pendingStartupAttachment = YES;
    [self scheduleDebugButtonAttachmentWithReason:@"bootstrap"];
    [self handlePendingRecoveryNoticeIfNeeded];
}

- (void)setDebugModeEnabled:(BOOL)enabled {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
          [self setDebugModeEnabled:enabled];
        });
        return;
    }

    _debugModeEnabled = enabled;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:enabled forKey:kDYYYEnableDebugModeKey];
    [defaults synchronize];
    if (!enabled) {
        [self recordStartupLog:@"setDebugModeEnabled:NO"];
        self.pendingStartupAttachment = NO;
        self.attachmentGeneration += 1;
        [self clearStartupLaunchGuardIfNeededWithReason:@"manual_disable"];
        [DYYYABTestHook clearDebugABTestHitRecords];
        [self teardownDebugOverlay];
        return;
    }

    [self recordStartupLog:@"setDebugModeEnabled:YES"];
    self.pendingStartupAttachment = NO;
    [self refreshDebugButtonAttachment];
}

- (void)refreshDebugButtonAttachment {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
          [self refreshDebugButtonAttachment];
        });
        return;
    }

    if (!self.debugModeEnabled) {
        return;
    }

    [self scheduleDebugButtonAttachmentWithReason:@"refresh"];
}

- (void)scheduleDebugButtonAttachmentWithReason:(NSString *)reason {
    if (!self.debugModeEnabled) {
        return;
    }

    self.attachmentGeneration += 1;
    NSUInteger generation = self.attachmentGeneration;
    [self recordStartupLog:[NSString stringWithFormat:@"schedule attach: reason=%@ pendingStartup=%@",
                                                      reason ?: @"unknown",
                                                      self.pendingStartupAttachment ? @"YES" : @"NO"]];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kDYYYDebugButtonAttachDelay * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
                     if (!self.debugModeEnabled || generation != self.attachmentGeneration) {
                         return;
                     }
                     [self attemptDebugButtonAttachmentWithReason:reason];
                   });
}

- (void)attemptDebugButtonAttachmentWithReason:(NSString *)reason {
    UIWindow *activeWindow = [DYYYUtils getActiveWindow];
    NSString *failureReason = nil;
    if (![self canSafelyAttachToWindow:activeWindow failureReason:&failureReason]) {
        [self recordStartupLog:[NSString stringWithFormat:@"attach skipped: reason=%@ failure=%@ window=%@",
                                                          reason ?: @"unknown",
                                                          failureReason ?: @"unknown",
                                                          [self windowSummary:activeWindow]]];
        return;
    }

    BOOL shouldTrackLaunchGuard = self.pendingStartupAttachment;
    if (shouldTrackLaunchGuard) {
        [self armStartupLaunchGuardIfNeededWithReason:reason];
    }

    @try {
        [self createDebugButtonIfNeeded];
        if (self.debugButton.superview != activeWindow) {
            [self.debugButton removeFromSuperview];
            [activeWindow addSubview:self.debugButton];
        }

        [self.debugButton.superview bringSubviewToFront:self.debugButton];
        [self.debugButton loadSavedPosition];
        [self recordStartupLog:[NSString stringWithFormat:@"attach success: reason=%@ window=%@ root=%@",
                                                          reason ?: @"unknown",
                                                          [self windowSummary:activeWindow],
                                                          [self viewControllerSummary:activeWindow.rootViewController]]];
    } @catch (NSException *exception) {
        [self handleAttachmentException:exception reason:reason];
        return;
    }

    if (!shouldTrackLaunchGuard) {
        return;
    }

    self.pendingStartupAttachment = NO;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kDYYYDebugButtonStartupValidationDelay * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
                     if (!self.debugModeEnabled) {
                         return;
                     }
                     if (self.debugButton.superview && self.debugButton.window) {
                         [self clearStartupLaunchGuardIfNeededWithReason:@"attach_validated"];
                     } else {
                         [self recordStartupLog:@"attach validation failed: button detached before validation"];
                     }
                   });
}

- (BOOL)canSafelyAttachToWindow:(UIWindow *)window failureReason:(NSString **)failureReason {
    UIApplication *application = [UIApplication sharedApplication];
    if (application.applicationState != UIApplicationStateActive) {
        if (failureReason) {
            *failureReason = @"app_not_active";
        }
        return NO;
    }

    if (!window) {
        if (failureReason) {
            *failureReason = @"missing_window";
        }
        return NO;
    }

    if (window.isHidden) {
        if (failureReason) {
            *failureReason = @"window_hidden";
        }
        return NO;
    }

    if (!window.rootViewController) {
        if (failureReason) {
            *failureReason = @"missing_root_view_controller";
        }
        return NO;
    }

    CGRect bounds = window.bounds;
    if (CGRectGetWidth(bounds) <= 1.0 || CGRectGetHeight(bounds) <= 1.0) {
        if (failureReason) {
            *failureReason = @"invalid_window_bounds";
        }
        return NO;
    }

    if (@available(iOS 13.0, *)) {
        UIWindowScene *windowScene = window.windowScene;
        if (!windowScene) {
            if (failureReason) {
                *failureReason = @"missing_window_scene";
            }
            return NO;
        }
        if (windowScene.activationState != UISceneActivationStateForegroundActive) {
            if (failureReason) {
                *failureReason = @"window_scene_not_active";
            }
            return NO;
        }
    }

    return YES;
}

- (void)armStartupLaunchGuardIfNeededWithReason:(NSString *)reason {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults boolForKey:kDYYYDebugOverlayLaunchGuardPendingKey]) {
        return;
    }

    [defaults setBool:YES forKey:kDYYYDebugOverlayLaunchGuardPendingKey];
    [defaults synchronize];
    [self recordStartupLog:[NSString stringWithFormat:@"launch guard armed: reason=%@", reason ?: @"unknown"]];
}

- (void)clearStartupLaunchGuardIfNeededWithReason:(NSString *)reason {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (![defaults boolForKey:kDYYYDebugOverlayLaunchGuardPendingKey]) {
        return;
    }

    [defaults setBool:NO forKey:kDYYYDebugOverlayLaunchGuardPendingKey];
    [defaults synchronize];
    [self recordStartupLog:[NSString stringWithFormat:@"launch guard cleared: reason=%@", reason ?: @"unknown"]];
}

- (void)persistDisabledDebugModeWithRecoveryNotice:(BOOL)shouldSetRecoveryNotice
                            clearStartupLaunchGuard:(BOOL)shouldClearLaunchGuard
                                             reason:(NSString *)reason {
    _debugModeEnabled = NO;
    self.pendingStartupAttachment = NO;
    self.attachmentGeneration += 1;

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:NO forKey:kDYYYEnableDebugModeKey];
    if (shouldClearLaunchGuard) {
        [defaults setBool:NO forKey:kDYYYDebugOverlayLaunchGuardPendingKey];
    }
    if (shouldSetRecoveryNotice) {
        [defaults setBool:YES forKey:kDYYYDebugOverlayRecoveryNoticePendingKey];
    }
    [defaults synchronize];

    [self recordStartupLog:[NSString stringWithFormat:@"persist debug disabled: reason=%@ recoveryNotice=%@ clearLaunchGuard=%@",
                                                      reason ?: @"unknown",
                                                      shouldSetRecoveryNotice ? @"YES" : @"NO",
                                                      shouldClearLaunchGuard ? @"YES" : @"NO"]];
    [DYYYABTestHook clearDebugABTestHitRecords];
    [self teardownDebugOverlay];
}

- (void)autoRecoverFromPendingStartupGuard {
    [self recordStartupLog:@"auto recovery triggered from pending launch guard"];
    [self persistDisabledDebugModeWithRecoveryNotice:YES
                              clearStartupLaunchGuard:YES
                                               reason:@"startup_guard_recovery"];
}

- (void)handlePendingRecoveryNoticeIfNeeded {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
          [self handlePendingRecoveryNoticeIfNeeded];
        });
        return;
    }

    UIApplication *application = [UIApplication sharedApplication];
    if (application.applicationState != UIApplicationStateActive) {
        return;
    }

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (![defaults boolForKey:kDYYYDebugOverlayRecoveryNoticePendingKey]) {
        return;
    }

    [defaults setBool:NO forKey:kDYYYDebugOverlayRecoveryNoticePendingKey];
    [defaults synchronize];
    [self recordStartupLog:@"show recovery notice"];
    [DYYYUtils showToast:@"检测到调试模式启动异常，已自动关闭"];
}

- (void)handleAttachmentException:(NSException *)exception reason:(NSString *)reason {
    NSString *exceptionMessage = [NSString stringWithFormat:@"attach exception: reason=%@ name=%@ message=%@",
                                                            reason ?: @"unknown",
                                                            exception.name ?: @"",
                                                            exception.reason ?: @""];
    [self recordStartupLog:exceptionMessage];

    BOOL shouldSetRecoveryNotice = self.pendingStartupAttachment || [[NSUserDefaults standardUserDefaults] boolForKey:kDYYYDebugOverlayLaunchGuardPendingKey];
    [self persistDisabledDebugModeWithRecoveryNotice:shouldSetRecoveryNotice
                              clearStartupLaunchGuard:YES
                                               reason:[NSString stringWithFormat:@"attach_exception_%@", reason ?: @"unknown"]];
    [DYYYUtils showToast:@"调试模式初始化失败，已自动关闭"];
}

- (void)teardownDebugOverlay {
    [self dismissCurrentMenuIfNeeded];
    [self.debugButton removeFromSuperview];
    self.debugButton = nil;
}

- (void)recordStartupLog:(NSString *)message {
    if (message.length == 0) {
        return;
    }

    @synchronized(self) {
        NSString *logPath = [DYYYUtils cachePathForFilename:kDYYYDebugOverlayStartupLogFilename];
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss.SSS";
        NSString *timestamp = [formatter stringFromDate:[NSDate date]];
        NSString *line = [NSString stringWithFormat:@"[%@] %@", timestamp, message];

        NSError *readError = nil;
        NSString *existingContent = [NSString stringWithContentsOfFile:logPath encoding:NSUTF8StringEncoding error:&readError];
        NSMutableArray<NSString *> *lines = [NSMutableArray array];
        if (existingContent.length > 0) {
            for (NSString *existingLine in [existingContent componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]) {
                if (existingLine.length > 0) {
                    [lines addObject:existingLine];
                }
            }
        }

        [lines addObject:line];
        if (lines.count > kDYYYDebugOverlayStartupLogMaxLines) {
            NSRange trimRange = NSMakeRange(lines.count - kDYYYDebugOverlayStartupLogMaxLines, kDYYYDebugOverlayStartupLogMaxLines);
            lines = [[lines subarrayWithRange:trimRange] mutableCopy];
        }

        NSString *finalContent = [[lines componentsJoinedByString:@"\n"] stringByAppendingString:@"\n"];
        [finalContent writeToFile:logPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }
}

- (NSString *)windowSummary:(UIWindow *)window {
    if (!window) {
        return @"(null)";
    }
    return [NSString stringWithFormat:@"%@<%p> hidden=%@ bounds=%@",
                                      NSStringFromClass(window.class) ?: @"UIWindow",
                                      window,
                                      window.isHidden ? @"YES" : @"NO",
                                      NSStringFromCGRect(window.bounds)];
}

- (NSString *)viewControllerSummary:(UIViewController *)viewController {
    if (!viewController) {
        return @"(null)";
    }
    return [NSString stringWithFormat:@"%@<%p> loaded=%@",
                                      NSStringFromClass(viewController.class) ?: @"UIViewController",
                                      viewController,
                                      viewController.isViewLoaded ? @"YES" : @"NO"];
}

#pragma mark - Observers

- (void)registerObservers {
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    __weak __typeof(self) weakSelf = self;

    self.windowObserver = [center addObserverForName:UIWindowDidBecomeKeyNotification
                                              object:nil
                                               queue:[NSOperationQueue mainQueue]
                                          usingBlock:^(NSNotification *_Nonnull notification) {
                                            __strong __typeof(weakSelf) strongSelf = weakSelf;
                                            if (!strongSelf || !strongSelf.debugModeEnabled) {
                                                return;
                                            }
                                            [strongSelf scheduleDebugButtonAttachmentWithReason:@"window_did_become_key"];
                                          }];

    self.didBecomeActiveObserver = [center addObserverForName:UIApplicationDidBecomeActiveNotification
                                                       object:nil
                                                        queue:[NSOperationQueue mainQueue]
                                                   usingBlock:^(NSNotification *_Nonnull notification) {
                                                     __strong __typeof(weakSelf) strongSelf = weakSelf;
                                                     if (!strongSelf) {
                                                         return;
                                                     }
                                                     [strongSelf handlePendingRecoveryNoticeIfNeeded];
                                                     if (strongSelf.debugModeEnabled) {
                                                         [strongSelf scheduleDebugButtonAttachmentWithReason:@"app_did_become_active"];
                                                     }
                                                   }];

    self.willEnterForegroundObserver = [center addObserverForName:UIApplicationWillEnterForegroundNotification
                                                           object:nil
                                                            queue:[NSOperationQueue mainQueue]
                                                       usingBlock:^(NSNotification *_Nonnull notification) {
                                                         __strong __typeof(weakSelf) strongSelf = weakSelf;
                                                         if (!strongSelf) {
                                                             return;
                                                         }
                                                         [strongSelf handlePendingRecoveryNoticeIfNeeded];
                                                         if (strongSelf.debugModeEnabled) {
                                                             [strongSelf scheduleDebugButtonAttachmentWithReason:@"app_will_enter_foreground"];
                                                         }
                                                       }];
}

#pragma mark - Button / Menu

- (void)createDebugButtonIfNeeded {
    if (self.debugButton) {
        return;
    }

    DYYYDebugFloatButton *button = [[DYYYDebugFloatButton alloc] initWithFrame:CGRectMake(0, 0, kDYYYDebugButtonSize, kDYYYDebugButtonSize)];
    [button addTarget:self action:@selector(handleDebugButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    self.debugButton = button;
}

- (void)handleDebugButtonTapped:(UIButton *)sender {
    [self refreshDebugButtonAttachment];
    [self dismissCurrentMenuIfNeeded];

    DYYYDebugExportContext *context = [self captureCurrentExportContext];
    if (!context.activeWindow || !context.windowRootViewController) {
        [DYYYUtils showToast:@"当前没有可用的页面上下文"];
        return;
    }

    if (!context.sourceBusinessViewController) {
        [DYYYUtils showToast:@"当前没有可用的业务页面"];
        return;
    }

    self.activeExportContext = context;

    __weak __typeof(self) weakSelf = self;
    NSArray<DYYYDebugMenuAction *> *actions = @[
        [DYYYDebugMenuAction actionWithTitle:@"导出当前页 UI"
                                      detail:@"导出当前业务页的控制器树和 View 树"
                                     handler:^{
                                       __strong __typeof(weakSelf) strongSelf = weakSelf;
                                       [strongSelf exportType:DYYYDebugExportTypeCurrentPageHierarchy
                                                   fromContext:context
                                                  loadingText:@"正在生成当前页 UI..."
                                               failureMessage:@"导出当前页 UI 失败"];
                                     }],
        [DYYYDebugMenuAction actionWithTitle:@"导出整窗 UI"
                                      detail:@"导出当前窗口的完整控制器树和 View 树"
                                     handler:^{
                                       __strong __typeof(weakSelf) strongSelf = weakSelf;
                                       [strongSelf exportType:DYYYDebugExportTypeWindowHierarchy
                                                   fromContext:context
                                                  loadingText:@"正在生成整窗 UI..."
                                               failureMessage:@"导出整窗 UI 失败"];
                                     }],
        [DYYYDebugMenuAction actionWithTitle:@"导出关键类方法"
                                      detail:@"导出当前页关键控制器和模型类的方法列表与 type encoding"
                                     handler:^{
                                       __strong __typeof(weakSelf) strongSelf = weakSelf;
                                       [strongSelf exportType:DYYYDebugExportTypeKeyClassMethods
                                                   fromContext:context
                                                  loadingText:@"正在生成关键类方法..."
                                               failureMessage:@"导出关键类方法失败"];
                                     }],
        [DYYYDebugMenuAction actionWithTitle:@"导出关键对象链"
                                      detail:@"导出当前页控制器链、可见同级控制器和关键模型对象链"
                                     handler:^{
                                       __strong __typeof(weakSelf) strongSelf = weakSelf;
                                       [strongSelf exportType:DYYYDebugExportTypeObjectChain
                                                   fromContext:context
                                                  loadingText:@"正在生成关键对象链..."
                                               failureMessage:@"导出关键对象链失败"];
                                     }],
        [DYYYDebugMenuAction actionWithTitle:@"导出模型字段值"
                                      detail:@"导出当前模型一层字段，并展开常用链路对象"
                                     handler:^{
                                       __strong __typeof(weakSelf) strongSelf = weakSelf;
                                       [strongSelf exportType:DYYYDebugExportTypeModelFieldValues
                                                   fromContext:context
                                                  loadingText:@"正在生成模型字段值..."
                                               failureMessage:@"导出模型字段值失败"];
                                     }],
        [DYYYDebugMenuAction actionWithTitle:@"导出当前 ABTest 快照"
                                      detail:@"导出当前 AWEABTestManager 中的完整 abTestData"
                                     handler:^{
                                       __strong __typeof(weakSelf) strongSelf = weakSelf;
                                       [strongSelf exportType:DYYYDebugExportTypeABTestSnapshot
                                                   fromContext:context
                                                  loadingText:@"正在生成 ABTest 快照..."
                                               failureMessage:@"导出当前 ABTest 快照失败"];
                                     }],
        [DYYYDebugMenuAction actionWithTitle:@"导出当前页 ABTest 命中"
                                      detail:@"导出当前页运行时访问过的 ABTest key 及最近命中记录"
                                     handler:^{
                                       __strong __typeof(weakSelf) strongSelf = weakSelf;
                                       [strongSelf exportType:DYYYDebugExportTypeABTestHitKeys
                                                   fromContext:context
                                                  loadingText:@"正在生成当前页 ABTest 命中..."
                                               failureMessage:@"导出当前页 ABTest 命中失败"];
                                     }],
        [DYYYDebugMenuAction actionWithTitle:@"一键导出全部"
                                      detail:@"导出当前页 UI、整窗 UI、增强调试文件和 Manifest 清单"
                                     handler:^{
                                       __strong __typeof(weakSelf) strongSelf = weakSelf;
                                       [strongSelf exportAllDebugDataFromContext:context];
                                     }],
    ];

    UIViewController *presentingViewController = [self bestPresentingControllerForContext:context];
    UIViewController *menuController = [DYYYDebugMenuViewController showWithTitle:@"调试导出"
                                                                          message:@"每个动作都会单独生成文件；一键导出会输出全部文件和清单"
                                                                          actions:actions
                                                         onPresentingViewController:presentingViewController
                                                                      closeAction:^{
                                                                        __strong __typeof(weakSelf) strongSelf = weakSelf;
                                                                        [strongSelf clearMenuContextIfNeeded:context];
                                                                      }];
    context.debugMenuController = menuController;
    self.debugMenuController = menuController;

    if (!menuController) {
        [self clearMenuContextIfNeeded:context];
        [DYYYUtils showToast:@"无法打开调试菜单"];
    }
}

- (void)dismissCurrentMenuIfNeeded {
    UIViewController *menuController = self.debugMenuController;
    if (menuController.presentingViewController && !menuController.isBeingDismissed) {
        [menuController dismissViewControllerAnimated:NO completion:nil];
    }
    self.debugMenuController = nil;
    self.activeExportContext = nil;
}

- (void)clearMenuContextIfNeeded:(DYYYDebugExportContext *)context {
    if (self.activeExportContext == context) {
        self.activeExportContext = nil;
    }
    if (self.debugMenuController == context.debugMenuController) {
        self.debugMenuController = nil;
    }
}

#pragma mark - Export Flow

- (void)exportType:(DYYYDebugExportType)type
       fromContext:(DYYYDebugExportContext *)context
      loadingText:(NSString *)loadingText
   failureMessage:(NSString *)failureMessage {
    [DYYYUtils showToast:loadingText ?: @"正在生成调试文件..."];
    __weak __typeof(self) weakSelf = self;
    [DYYYDebugHelper exportDebugDataForType:type fromContext:context completion:^(NSArray<NSURL *> *_Nullable exportFileURLs, NSArray<NSString *> *_Nullable tempFilePaths, NSError *_Nullable error) {
      __strong __typeof(weakSelf) strongSelf = weakSelf;
      [strongSelf handleExportResultWithFileURLs:exportFileURLs tempFilePaths:tempFilePaths error:error context:context failureMessage:failureMessage];
    }];
}

- (void)exportAllDebugDataFromContext:(DYYYDebugExportContext *)context {
    [DYYYUtils showToast:@"正在生成全部调试文件..."];
    __weak __typeof(self) weakSelf = self;
    [DYYYDebugHelper exportAllDebugDataFromContext:context completion:^(NSArray<NSURL *> *_Nullable exportFileURLs, NSArray<NSString *> *_Nullable tempFilePaths, NSError *_Nullable error) {
      __strong __typeof(weakSelf) strongSelf = weakSelf;
      [strongSelf handleExportResultWithFileURLs:exportFileURLs tempFilePaths:tempFilePaths error:error context:context failureMessage:@"一键导出全部失败"];
    }];
}

- (void)handleExportResultWithFileURLs:(NSArray<NSURL *> *)fileURLs
                         tempFilePaths:(NSArray<NSString *> *)tempFilePaths
                                 error:(NSError *)error
                               context:(DYYYDebugExportContext *)context
                        failureMessage:(NSString *)failureMessage {
    if (error) {
        [self clearMenuContextIfNeeded:context];
        [self removeTemporaryFiles:tempFilePaths];
        [DYYYUtils showToast:error.localizedDescription ?: failureMessage];
        return;
    }

    [self presentDocumentPickerWithURLs:fileURLs tempFilePaths:tempFilePaths context:context successMessage:@"调试文件已保存"];
    [self clearMenuContextIfNeeded:context];
}

- (void)presentDocumentPickerWithURLs:(NSArray<NSURL *> *)fileURLs
                        tempFilePaths:(NSArray<NSString *> *)tempFilePaths
                              context:(DYYYDebugExportContext *)context
                       successMessage:(NSString *)successMessage {
    if (fileURLs.count == 0) {
        [self removeTemporaryFiles:tempFilePaths];
        [DYYYUtils showToast:@"调试文件创建失败"];
        return;
    }

    UIDocumentPickerViewController *documentPicker = [[UIDocumentPickerViewController alloc] initWithURLs:fileURLs inMode:UIDocumentPickerModeExportToService];
    DYYYBackupPickerDelegate *pickerDelegate = [[DYYYBackupPickerDelegate alloc] init];
    pickerDelegate.tempFilePaths = tempFilePaths;
    pickerDelegate.completionBlock = ^(NSURL *url) {
      [DYYYUtils showToast:successMessage ?: @"调试文件已保存"];
    };

    static char kDYYYDebugPickerDelegateKey;
    documentPicker.delegate = pickerDelegate;
    objc_setAssociatedObject(documentPicker, &kDYYYDebugPickerDelegateKey, pickerDelegate, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    void (^presentPicker)(void) = ^{
      UIViewController *presentingVC = [self bestPresentingControllerForContext:context];
      if (!presentingVC) {
          [self removeTemporaryFiles:tempFilePaths];
          [DYYYUtils showToast:@"无法显示导出面板"];
          return;
      }
      [presentingVC presentViewController:documentPicker animated:YES completion:nil];
    };

    UIViewController *menuController = context.debugMenuController;
    if (menuController.presentingViewController && !menuController.isBeingDismissed) {
        [menuController dismissViewControllerAnimated:YES completion:^{
          presentPicker();
        }];
        return;
    }

    presentPicker();
}

- (UIViewController *)bestPresentingControllerForContext:(DYYYDebugExportContext *)context {
    UIViewController *menuController = context.debugMenuController;
    if (menuController.view.window && !menuController.isBeingDismissed && !menuController.isBeingPresented) {
        return menuController;
    }

    UIViewController *topController = [self resolvedVisibleViewControllerFromController:context.windowRootViewController];
    if (topController.view.window) {
        return topController;
    }

    UIViewController *topViewController = [DYYYUtils topView];
    if (topViewController) {
        return topViewController;
    }

    return context.sourceBusinessViewController ?: context.windowRootViewController;
}

#pragma mark - Context Capture

- (DYYYDebugExportContext *)captureCurrentExportContext {
    UIWindow *activeWindow = [DYYYUtils getActiveWindow];
    UIViewController *rootVC = activeWindow.rootViewController;
    UIViewController *topVisibleVC = [self resolvedVisibleViewControllerFromController:rootVC];
    UIViewController *sourceBusinessVC = [self sourceBusinessViewControllerFromCandidate:topVisibleVC rootViewController:rootVC];

    DYYYDebugExportContext *context = [[DYYYDebugExportContext alloc] init];
    context.activeWindow = activeWindow;
    context.windowRootViewController = rootVC;
    context.topVisibleViewController = topVisibleVC;
    context.sourceBusinessViewController = sourceBusinessVC ?: topVisibleVC ?: rootVC;
    context.debugButtonView = self.debugButton;
    return context;
}

- (UIViewController *)resolvedVisibleViewControllerFromController:(UIViewController *)controller {
    if (!controller) {
        return nil;
    }

    UIViewController *presentedViewController = controller.presentedViewController;
    if (presentedViewController && !presentedViewController.isBeingDismissed) {
        return [self resolvedVisibleViewControllerFromController:presentedViewController];
    }

    if ([controller isKindOfClass:[UINavigationController class]]) {
        UINavigationController *navigationController = (UINavigationController *)controller;
        UIViewController *visibleViewController = navigationController.visibleViewController ?: navigationController.topViewController ?: navigationController.viewControllers.lastObject;
        return [self resolvedVisibleViewControllerFromController:visibleViewController];
    }

    if ([controller isKindOfClass:[UITabBarController class]]) {
        UITabBarController *tabBarController = (UITabBarController *)controller;
        UIViewController *selectedViewController = tabBarController.selectedViewController ?: tabBarController.moreNavigationController.topViewController;
        return [self resolvedVisibleViewControllerFromController:selectedViewController];
    }

    for (UIViewController *childViewController in [controller.childViewControllers reverseObjectEnumerator]) {
        if (!childViewController.isViewLoaded) {
            continue;
        }
        UIView *childView = childViewController.view;
        if (!childView.window || childView.hidden || childView.alpha <= 0.01) {
            continue;
        }

        UIViewController *resolvedChild = [self resolvedVisibleViewControllerFromController:childViewController];
        if (resolvedChild) {
            return resolvedChild;
        }
    }

    return controller;
}

- (UIViewController *)sourceBusinessViewControllerFromCandidate:(UIViewController *)candidate rootViewController:(UIViewController *)rootViewController {
    UIViewController *resolvedCandidate = [self resolvedVisibleViewControllerFromController:candidate];
    if (![self isDebugOwnedController:resolvedCandidate]) {
        return resolvedCandidate;
    }

    UIViewController *navigationFallback = [self lastNonDebugControllerInNavigationStack:resolvedCandidate.navigationController];
    if (navigationFallback) {
        return [self resolvedVisibleViewControllerFromController:navigationFallback];
    }

    UIViewController *presentingViewController = resolvedCandidate.presentingViewController;
    while (presentingViewController) {
        UIViewController *resolvedPresentingController = [self resolvedVisibleViewControllerFromController:presentingViewController];
        if (![self isDebugOwnedController:resolvedPresentingController]) {
            return resolvedPresentingController;
        }
        presentingViewController = presentingViewController.presentingViewController;
    }

    UIViewController *resolvedRootController = [self resolvedVisibleViewControllerFromController:rootViewController];
    if (![self isDebugOwnedController:resolvedRootController]) {
        return resolvedRootController;
    }

    UIViewController *rootNavigationFallback = [self lastNonDebugControllerInNavigationStack:rootViewController.navigationController];
    if (rootNavigationFallback) {
        return [self resolvedVisibleViewControllerFromController:rootNavigationFallback];
    }

    return rootViewController;
}

- (UIViewController *)lastNonDebugControllerInNavigationStack:(UINavigationController *)navigationController {
    if (!navigationController) {
        return nil;
    }

    for (UIViewController *viewController in [navigationController.viewControllers reverseObjectEnumerator]) {
        if (![self isDebugOwnedController:viewController]) {
            return viewController;
        }
    }

    return nil;
}

- (BOOL)isDebugOwnedController:(UIViewController *)viewController {
    if (!viewController) {
        return NO;
    }

    NSString *className = NSStringFromClass(viewController.class) ?: @"";
    return [className hasPrefix:@"DYYY"];
}

#pragma mark - Helpers

- (void)removeTemporaryFiles:(NSArray<NSString *> *)paths {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    for (NSString *path in paths) {
        if (path.length == 0 || ![fileManager fileExistsAtPath:path]) {
            continue;
        }
        [fileManager removeItemAtPath:path error:nil];
    }
}

@end
