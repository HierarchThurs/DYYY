#import "DYYYDebugHelper.h"

#import "DYYYUtils.h"

typedef NS_ENUM(NSUInteger, DYYYDebugExportScope) {
    DYYYDebugExportScopeCurrentPage,
    DYYYDebugExportScopeWindowHierarchy,
};

static NSString *const kDYYYDebugExportErrorDomain = @"com.dyyy.debug.export";

@implementation DYYYDebugExportContext
@end

@interface DYYYDebugHelper ()

+ (void)exportHierarchyForScope:(DYYYDebugExportScope)scope context:(DYYYDebugExportContext *)context completion:(DYYYDebugExportCompletion)completion;
+ (NSDictionary *)snapshotForScope:(DYYYDebugExportScope)scope
                           context:(DYYYDebugExportContext *)context
                    controllerRoot:(UIViewController *)controllerRoot
                          viewRoot:(UIView *)viewRoot;
+ (void)writeSnapshot:(NSDictionary *)snapshot scope:(DYYYDebugExportScope)scope completion:(DYYYDebugExportCompletion)completion;
+ (NSDictionary *)controllerNodeFromController:(UIViewController *)viewController context:(DYYYDebugExportContext *)context;
+ (NSDictionary *)viewNodeFromView:(UIView *)view context:(DYYYDebugExportContext *)context;
+ (BOOL)shouldSkipController:(UIViewController *)controller context:(DYYYDebugExportContext *)context;
+ (BOOL)shouldSkipView:(UIView *)view context:(DYYYDebugExportContext *)context;
+ (BOOL)isDebugOwnedController:(UIViewController *)viewController;
+ (NSString *)scopeIdentifierForScope:(DYYYDebugExportScope)scope;
+ (NSString *)scopeDisplayNameForScope:(DYYYDebugExportScope)scope;
+ (NSString *)exportTimestampString;
+ (NSDictionary *)objectSummaryForObject:(id)object;
+ (NSString *)singleLineObjectSummary:(id)objectSummary;
+ (NSString *)boolText:(NSNumber *)value;
+ (void)removeTemporaryFiles:(NSArray<NSString *> *)paths;
+ (void)completeWithFileURLs:(NSArray<NSURL *> *_Nullable)fileURLs
               tempFilePaths:(NSArray<NSString *> *_Nullable)tempFilePaths
                       error:(NSError *_Nullable)error
                  completion:(DYYYDebugExportCompletion)completion;

@end

@implementation DYYYDebugHelper

+ (void)exportCurrentPageHierarchyFromContext:(DYYYDebugExportContext *)context completion:(DYYYDebugExportCompletion)completion {
    [self exportHierarchyForScope:DYYYDebugExportScopeCurrentPage context:context completion:completion];
}

+ (void)exportWindowHierarchyFromContext:(DYYYDebugExportContext *)context completion:(DYYYDebugExportCompletion)completion {
    [self exportHierarchyForScope:DYYYDebugExportScopeWindowHierarchy context:context completion:completion];
}

#pragma mark - Export

+ (void)exportHierarchyForScope:(DYYYDebugExportScope)scope context:(DYYYDebugExportContext *)context completion:(DYYYDebugExportCompletion)completion {
    if (!context) {
        NSError *error = [NSError errorWithDomain:kDYYYDebugExportErrorDomain
                                             code:1000
                                         userInfo:@{NSLocalizedDescriptionKey : @"缺少调试导出上下文"}];
        [self completeWithFileURLs:nil tempFilePaths:nil error:error completion:completion];
        return;
    }

    void (^captureBlock)(void) = ^{
      UIWindow *activeWindow = context.activeWindow;
      UIViewController *rootVC = context.windowRootViewController;
      UIViewController *sourceVC = context.sourceBusinessViewController;

      if (!activeWindow || !rootVC) {
          NSError *error = [NSError errorWithDomain:kDYYYDebugExportErrorDomain
                                               code:1001
                                           userInfo:@{NSLocalizedDescriptionKey : @"当前没有可用的窗口或根控制器"}];
          [self completeWithFileURLs:nil tempFilePaths:nil error:error completion:completion];
          return;
      }

      UIViewController *controllerRoot = (scope == DYYYDebugExportScopeCurrentPage) ? sourceVC : rootVC;
      UIView *viewRoot = (scope == DYYYDebugExportScopeCurrentPage) ? sourceVC.view : activeWindow;
      if (!controllerRoot || !viewRoot) {
          NSError *error = [NSError errorWithDomain:kDYYYDebugExportErrorDomain
                                               code:1002
                                           userInfo:@{NSLocalizedDescriptionKey : @"当前没有可用的前台页面"}];
          [self completeWithFileURLs:nil tempFilePaths:nil error:error completion:completion];
          return;
      }

      NSDictionary *snapshot = [self snapshotForScope:scope context:context controllerRoot:controllerRoot viewRoot:viewRoot];
      dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self writeSnapshot:snapshot scope:scope completion:completion];
      });
    };

    if ([NSThread isMainThread]) {
        captureBlock();
    } else {
        dispatch_async(dispatch_get_main_queue(), captureBlock);
    }
}

+ (NSDictionary *)snapshotForScope:(DYYYDebugExportScope)scope
                           context:(DYYYDebugExportContext *)context
                    controllerRoot:(UIViewController *)controllerRoot
                          viewRoot:(UIView *)viewRoot {
    NSString *timestamp = [self exportTimestampString];
    NSBundle *mainBundle = [NSBundle mainBundle];
    NSString *bundleIdentifier = mainBundle.bundleIdentifier ?: @"";
    NSString *appVersion = [mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"";
    NSString *buildVersion = [mainBundle objectForInfoDictionaryKey:@"CFBundleVersion"] ?: @"";

    NSMutableDictionary *metadata = [NSMutableDictionary dictionary];
    metadata[@"scope"] = [self scopeIdentifierForScope:scope];
    metadata[@"scopeDisplayName"] = [self scopeDisplayNameForScope:scope];
    metadata[@"timestamp"] = timestamp;
    metadata[@"bundleIdentifier"] = bundleIdentifier;
    metadata[@"appVersion"] = appVersion;
    metadata[@"buildVersion"] = buildVersion;
    metadata[@"activeWindow"] = [self objectSummaryForObject:context.activeWindow];
    metadata[@"rootViewController"] = [self objectSummaryForObject:context.windowRootViewController];
    metadata[@"topViewController"] = [self objectSummaryForObject:context.topVisibleViewController];
    metadata[@"sourceBusinessViewController"] = [self objectSummaryForObject:context.sourceBusinessViewController];
    metadata[@"controllerRoot"] = [self objectSummaryForObject:controllerRoot];
    metadata[@"viewRoot"] = [self objectSummaryForObject:viewRoot];

    return @{
        @"metadata" : [metadata copy],
        @"controllerTree" : [self controllerNodeFromController:controllerRoot context:context] ?: [NSNull null],
        @"viewTree" : [self viewNodeFromView:viewRoot context:context] ?: [NSNull null]
    };
}

+ (void)writeSnapshot:(NSDictionary *)snapshot scope:(DYYYDebugExportScope)scope completion:(DYYYDebugExportCompletion)completion {
    NSString *timestamp = snapshot[@"metadata"][@"timestamp"] ?: [self exportTimestampString];
    NSString *scopeIdentifier = [self scopeIdentifierForScope:scope];
    NSString *baseFileName = [NSString stringWithFormat:@"DYYY_Debug_%@_%@", scopeIdentifier, timestamp];
    NSString *textPath = [DYYYUtils cachePathForFilename:[baseFileName stringByAppendingPathExtension:@"txt"]];
    NSString *jsonPath = [DYYYUtils cachePathForFilename:[baseFileName stringByAppendingPathExtension:@"json"]];

    NSError *writeError = nil;
    NSString *textContent = [self textRepresentationForSnapshot:snapshot];
    if (![textContent writeToFile:textPath atomically:YES encoding:NSUTF8StringEncoding error:&writeError]) {
        [self removeTemporaryFiles:@[ textPath, jsonPath ]];
        [self completeWithFileURLs:nil tempFilePaths:nil error:writeError completion:completion];
        return;
    }

    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:snapshot
                                                       options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys
                                                         error:&writeError];
    if (!jsonData || ![jsonData writeToFile:jsonPath options:NSDataWritingAtomic error:&writeError]) {
        [self removeTemporaryFiles:@[ textPath, jsonPath ]];
        [self completeWithFileURLs:nil tempFilePaths:nil error:writeError completion:completion];
        return;
    }

    NSArray<NSString *> *tempFilePaths = @[ textPath, jsonPath ];
    NSArray<NSURL *> *fileURLs = @[ [NSURL fileURLWithPath:textPath], [NSURL fileURLWithPath:jsonPath] ];
    [self completeWithFileURLs:fileURLs tempFilePaths:tempFilePaths error:nil completion:completion];
}

+ (void)completeWithFileURLs:(NSArray<NSURL *> *_Nullable)fileURLs
               tempFilePaths:(NSArray<NSString *> *_Nullable)tempFilePaths
                       error:(NSError *_Nullable)error
                  completion:(DYYYDebugExportCompletion)completion {
    if (!completion) {
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
      completion(fileURLs, tempFilePaths, error);
    });
}

#pragma mark - Tree Builders

+ (NSDictionary *)controllerNodeFromController:(UIViewController *)viewController context:(DYYYDebugExportContext *)context {
    if (!viewController || [self shouldSkipController:viewController context:context]) {
        return nil;
    }

    NSMutableArray<NSDictionary *> *children = [NSMutableArray array];
    for (UIViewController *childViewController in viewController.childViewControllers) {
        NSDictionary *childNode = [self controllerNodeFromController:childViewController context:context];
        if (childNode) {
            [children addObject:childNode];
        }
    }

    UIViewController *presentedViewController = viewController.presentedViewController;
    NSDictionary *presentedNode = [self controllerNodeFromController:presentedViewController context:context];

    NSMutableDictionary *node = [NSMutableDictionary dictionary];
    node[@"className"] = NSStringFromClass(viewController.class) ?: @"";
    node[@"address"] = [NSString stringWithFormat:@"%p", viewController];
    node[@"title"] = viewController.title ?: @"";
    node[@"navigationTitle"] = viewController.navigationItem.title ?: @"";
    node[@"viewLoaded"] = @([viewController isViewLoaded]);
    node[@"childCount"] = @(children.count);
    node[@"presentedClassName"] = presentedNode ? (NSStringFromClass(presentedViewController.class) ?: @"") : @"";
    node[@"children"] = [children copy];
    node[@"presented"] = presentedNode ?: [NSNull null];
    return [node copy];
}

+ (NSDictionary *)viewNodeFromView:(UIView *)view context:(DYYYDebugExportContext *)context {
    if (!view || [self shouldSkipView:view context:context]) {
        return nil;
    }

    NSMutableArray<NSDictionary *> *subviewNodes = [NSMutableArray array];
    for (UIView *subview in view.subviews) {
        NSDictionary *subviewNode = [self viewNodeFromView:subview context:context];
        if (subviewNode) {
            [subviewNodes addObject:subviewNode];
        }
    }

    NSString *accessibilityLabel = nil;
    if ([view respondsToSelector:@selector(accessibilityLabel)]) {
        accessibilityLabel = view.accessibilityLabel;
    }

    return @{
        @"className" : NSStringFromClass(view.class) ?: @"",
        @"address" : [NSString stringWithFormat:@"%p", view],
        @"frame" : NSStringFromCGRect(view.frame),
        @"bounds" : NSStringFromCGRect(view.bounds),
        @"hidden" : @(view.hidden),
        @"alpha" : @((double)view.alpha),
        @"tag" : @(view.tag),
        @"accessibilityLabel" : accessibilityLabel ?: @"",
        @"subviewCount" : @(subviewNodes.count),
        @"subviews" : [subviewNodes copy]
    };
}

+ (BOOL)shouldSkipController:(UIViewController *)controller context:(DYYYDebugExportContext *)context {
    if (!controller) {
        return YES;
    }

    if (controller == context.sourceBusinessViewController || controller == context.windowRootViewController) {
        return NO;
    }

    if (context.debugMenuController && controller == context.debugMenuController) {
        return YES;
    }

    return [self isDebugOwnedController:controller];
}

+ (BOOL)shouldSkipView:(UIView *)view context:(DYYYDebugExportContext *)context {
    if (!view) {
        return YES;
    }

    UIView *debugButtonView = context.debugButtonView;
    if (debugButtonView && [view isDescendantOfView:debugButtonView]) {
        return YES;
    }

    UIView *debugMenuView = context.debugMenuController.view;
    if (debugMenuView && [view isDescendantOfView:debugMenuView]) {
        return YES;
    }

    return NO;
}

+ (BOOL)isDebugOwnedController:(UIViewController *)viewController {
    if (!viewController) {
        return NO;
    }

    NSString *className = NSStringFromClass(viewController.class) ?: @"";
    return [className hasPrefix:@"DYYY"];
}

#pragma mark - Text Serialization

+ (NSString *)textRepresentationForSnapshot:(NSDictionary *)snapshot {
    NSDictionary *metadata = snapshot[@"metadata"];
    NSMutableString *text = [NSMutableString string];
    [text appendString:@"DYYY 调试导出\n"];
    [text appendFormat:@"导出范围: %@\n", metadata[@"scopeDisplayName"] ?: @""];
    [text appendFormat:@"时间: %@\n", metadata[@"timestamp"] ?: @""];
    [text appendFormat:@"Bundle ID: %@\n", metadata[@"bundleIdentifier"] ?: @""];
    [text appendFormat:@"App Version: %@ (%@)\n", metadata[@"appVersion"] ?: @"", metadata[@"buildVersion"] ?: @""];
    [text appendFormat:@"Active Window: %@\n", [self singleLineObjectSummary:metadata[@"activeWindow"]]];
    [text appendFormat:@"Root VC: %@\n", [self singleLineObjectSummary:metadata[@"rootViewController"]]];
    [text appendFormat:@"Top VC: %@\n", [self singleLineObjectSummary:metadata[@"topViewController"]]];
    [text appendFormat:@"Source VC: %@\n", [self singleLineObjectSummary:metadata[@"sourceBusinessViewController"]]];
    [text appendFormat:@"Controller Root: %@\n", [self singleLineObjectSummary:metadata[@"controllerRoot"]]];
    [text appendFormat:@"View Root: %@\n", [self singleLineObjectSummary:metadata[@"viewRoot"]]];

    [text appendString:@"\n== 控制器树 ==\n"];
    NSDictionary *controllerTree = snapshot[@"controllerTree"];
    if ([controllerTree isKindOfClass:[NSDictionary class]]) {
        [self appendControllerNode:controllerTree toString:text indent:0 relationship:nil];
    } else {
        [text appendString:@"(无)\n"];
    }

    [text appendString:@"\n== View 树 ==\n"];
    NSDictionary *viewTree = snapshot[@"viewTree"];
    if ([viewTree isKindOfClass:[NSDictionary class]]) {
        [self appendViewNode:viewTree toString:text indent:0];
    } else {
        [text appendString:@"(无)\n"];
    }

    return [text copy];
}

+ (void)appendControllerNode:(NSDictionary *)node toString:(NSMutableString *)text indent:(NSUInteger)indent relationship:(NSString *_Nullable)relationship {
    NSString *indentString = [@"" stringByPaddingToLength:indent * 2 withString:@" " startingAtIndex:0];
    NSString *relationshipPrefix = relationship.length > 0 ? [NSString stringWithFormat:@"[%@] ", relationship] : @"";
    [text appendFormat:@"%@- %@%@ <%@> title=\"%@\" navTitle=\"%@\" viewLoaded=%@ childCount=%@\n",
                       indentString, relationshipPrefix, node[@"className"] ?: @"", node[@"address"] ?: @"",
                       node[@"title"] ?: @"", node[@"navigationTitle"] ?: @"", [self boolText:node[@"viewLoaded"]], node[@"childCount"] ?: @0];

    NSArray *children = node[@"children"];
    if ([children isKindOfClass:[NSArray class]]) {
        for (NSDictionary *child in children) {
            if ([child isKindOfClass:[NSDictionary class]]) {
                [self appendControllerNode:child toString:text indent:indent + 1 relationship:nil];
            }
        }
    }

    NSDictionary *presentedNode = node[@"presented"];
    if ([presentedNode isKindOfClass:[NSDictionary class]]) {
        [self appendControllerNode:presentedNode toString:text indent:indent + 1 relationship:@"presented"];
    }
}

+ (void)appendViewNode:(NSDictionary *)node toString:(NSMutableString *)text indent:(NSUInteger)indent {
    NSString *indentString = [@"" stringByPaddingToLength:indent * 2 withString:@" " startingAtIndex:0];
    [text appendFormat:@"%@- %@ <%@> frame=%@ bounds=%@ hidden=%@ alpha=%.2f tag=%@ label=\"%@\" subviews=%@\n",
                       indentString, node[@"className"] ?: @"", node[@"address"] ?: @"",
                       node[@"frame"] ?: @"", node[@"bounds"] ?: @"", [self boolText:node[@"hidden"]],
                       [node[@"alpha"] doubleValue], node[@"tag"] ?: @0, node[@"accessibilityLabel"] ?: @"", node[@"subviewCount"] ?: @0];

    NSArray *subviews = node[@"subviews"];
    if ([subviews isKindOfClass:[NSArray class]]) {
        for (NSDictionary *subview in subviews) {
            if ([subview isKindOfClass:[NSDictionary class]]) {
                [self appendViewNode:subview toString:text indent:indent + 1];
            }
        }
    }
}

#pragma mark - Helpers

+ (NSString *)scopeIdentifierForScope:(DYYYDebugExportScope)scope {
    switch (scope) {
        case DYYYDebugExportScopeCurrentPage:
            return @"CurrentPage";
        case DYYYDebugExportScopeWindowHierarchy:
            return @"WindowHierarchy";
    }
}

+ (NSString *)scopeDisplayNameForScope:(DYYYDebugExportScope)scope {
    switch (scope) {
        case DYYYDebugExportScopeCurrentPage:
            return @"当前页面";
        case DYYYDebugExportScopeWindowHierarchy:
            return @"整窗层级";
    }
}

+ (NSString *)exportTimestampString {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyyMMdd_HHmmss";
    return [formatter stringFromDate:[NSDate date]];
}

+ (NSDictionary *)objectSummaryForObject:(id)object {
    if (!object) {
        return @{@"className" : @"", @"address" : @""};
    }
    return @{
        @"className" : NSStringFromClass([object class]) ?: @"",
        @"address" : [NSString stringWithFormat:@"%p", object]
    };
}

+ (NSString *)singleLineObjectSummary:(id)objectSummary {
    if (![objectSummary isKindOfClass:[NSDictionary class]]) {
        return @"(无)";
    }

    NSString *className = objectSummary[@"className"] ?: @"";
    NSString *address = objectSummary[@"address"] ?: @"";
    if (className.length == 0 && address.length == 0) {
        return @"(无)";
    }
    return [NSString stringWithFormat:@"%@ <%@>", className, address];
}

+ (NSString *)boolText:(NSNumber *)value {
    return value.boolValue ? @"YES" : @"NO";
}

+ (void)removeTemporaryFiles:(NSArray<NSString *> *)paths {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    for (NSString *path in paths) {
        if (path.length == 0) {
            continue;
        }
        if ([fileManager fileExistsAtPath:path]) {
            [fileManager removeItemAtPath:path error:nil];
        }
    }
}

@end
