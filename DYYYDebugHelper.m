#import "DYYYDebugHelper.h"

#import <objc/runtime.h>

#import "DYYYABTestHook.h"
#import "DYYYUtils.h"

static NSString *const kDYYYDebugExportErrorDomain = @"com.dyyy.debug.export";
static NSString *const kDYYYDebugManifestLabel = @"Manifest";

@implementation DYYYDebugExportContext
@end

@interface DYYYDebugHelper ()

+ (void)exportArtifactsForType:(DYYYDebugExportType)type context:(DYYYDebugExportContext *)context completion:(DYYYDebugExportCompletion)completion;
+ (NSArray<NSNumber *> *)singleExportTypes;
+ (NSArray<NSDictionary *> *)artifactsForType:(DYYYDebugExportType)type context:(DYYYDebugExportContext *)context;
+ (NSArray<NSDictionary *> *)artifactsForAllTypesWithContext:(DYYYDebugExportContext *)context;
+ (NSArray<NSDictionary *> *)artifactsWithBaseLabel:(NSString *)baseLabel exportType:(DYYYDebugExportType)type textContent:(NSString *)textContent jsonObject:(NSDictionary *)jsonObject batchID:(NSString *)batchID;
+ (NSDictionary *)artifactWithFilename:(NSString *)filename exportType:(DYYYDebugExportType)type contentType:(NSString *)contentType content:(id)content;
+ (void)writeArtifacts:(NSArray<NSDictionary *> *)artifacts completion:(DYYYDebugExportCompletion)completion;
+ (void)completeWithFileURLs:(NSArray<NSURL *> *_Nullable)fileURLs tempFilePaths:(NSArray<NSString *> *_Nullable)tempFilePaths error:(NSError *_Nullable)error completion:(DYYYDebugExportCompletion)completion;
+ (NSError *)errorWithCode:(NSInteger)code description:(NSString *)description;

+ (void)ensureBatchIDOnContext:(DYYYDebugExportContext *)context;
+ (NSString *)newBatchID;
+ (NSString *)exportTimestampString;
+ (NSString *)labelForExportType:(DYYYDebugExportType)type;
+ (NSString *)displayNameForExportType:(DYYYDebugExportType)type;
+ (NSString *)filenameForBatchID:(NSString *)batchID label:(NSString *)label extension:(NSString *)extension;

+ (NSDictionary *)baseMetadataForContext:(DYYYDebugExportContext *)context exportType:(DYYYDebugExportType)type;
+ (NSDictionary *)objectSummaryForObject:(id)object;
+ (NSString *)singleLineObjectSummary:(id)objectSummary;
+ (NSString *)boolText:(NSNumber *)value;
+ (NSString *)safeStringDescriptionForObject:(id)object;
+ (NSString *)truncatedString:(NSString *)string maxLength:(NSUInteger)maxLength;

+ (NSDictionary *)hierarchySnapshotForType:(DYYYDebugExportType)type context:(DYYYDebugExportContext *)context;
+ (NSDictionary *)controllerNodeFromController:(UIViewController *)viewController context:(DYYYDebugExportContext *)context;
+ (NSDictionary *)viewNodeFromView:(UIView *)view context:(DYYYDebugExportContext *)context;
+ (BOOL)shouldSkipController:(UIViewController *)controller context:(DYYYDebugExportContext *)context;
+ (BOOL)shouldSkipView:(UIView *)view context:(DYYYDebugExportContext *)context;
+ (BOOL)isDebugOwnedController:(UIViewController *)viewController;
+ (NSString *)textRepresentationForHierarchySnapshot:(NSDictionary *)snapshot;
+ (void)appendControllerNode:(NSDictionary *)node toString:(NSMutableString *)text indent:(NSUInteger)indent relationship:(NSString *_Nullable)relationship;
+ (void)appendViewNode:(NSDictionary *)node toString:(NSMutableString *)text indent:(NSUInteger)indent;

+ (NSArray<UIViewController *> *)controllerChainForContext:(DYYYDebugExportContext *)context;
+ (NSArray<UIViewController *> *)visibleSiblingControllersForContext:(DYYYDebugExportContext *)context;
+ (NSArray<NSDictionary *> *)keyObjectEntriesForContext:(DYYYDebugExportContext *)context;
+ (NSArray<NSDictionary *> *)keyClassEntriesForContext:(DYYYDebugExportContext *)context;
+ (NSDictionary *)methodSnapshotForContext:(DYYYDebugExportContext *)context;
+ (NSArray<NSDictionary *> *)methodsForClass:(Class)targetClass classMethods:(BOOL)classMethods;
+ (NSString *)textRepresentationForMethodSnapshot:(NSDictionary *)snapshot;

+ (NSDictionary *)objectChainSnapshotForContext:(DYYYDebugExportContext *)context;
+ (NSString *)textRepresentationForObjectChainSnapshot:(NSDictionary *)snapshot;
+ (NSDictionary *)richSummaryForObject:(id)object;
+ (id)firstAvailableValueForSelectorNames:(NSArray<NSString *> *)selectorNames onObject:(id)object matchedSelector:(NSString *_Nullable *_Nullable)matchedSelector;
+ (id)safeValueForKey:(NSString *)key onObject:(id)object;

+ (NSDictionary *)modelFieldSnapshotForContext:(DYYYDebugExportContext *)context;
+ (NSDictionary *)objectDumpForEntry:(NSDictionary *)entry;
+ (NSArray<NSDictionary *> *)classSegmentsForObject:(id)object;
+ (NSArray<NSDictionary *> *)propertyEntriesForClass:(Class)targetClass object:(id)object;
+ (NSArray<NSDictionary *> *)ivarEntriesForClass:(Class)targetClass object:(id)object;
+ (id)serializableValueSummary:(id)value;
+ (NSString *)textRepresentationForModelFieldSnapshot:(NSDictionary *)snapshot;
+ (void)appendObjectDump:(NSDictionary *)objectDump toString:(NSMutableString *)text;

+ (NSDictionary *)abTestSnapshotForContext:(DYYYDebugExportContext *)context;
+ (NSString *)textRepresentationForABTestSnapshot:(NSDictionary *)snapshot;
+ (NSDictionary *)abTestHitSnapshotForContext:(DYYYDebugExportContext *)context;
+ (NSString *)textRepresentationForABTestHitSnapshot:(NSDictionary *)snapshot;

+ (NSDictionary *)manifestSnapshotForArtifacts:(NSArray<NSDictionary *> *)artifacts context:(DYYYDebugExportContext *)context;
+ (NSString *)textRepresentationForManifestSnapshot:(NSDictionary *)snapshot;

@end

@implementation DYYYDebugHelper

+ (void)exportCurrentPageHierarchyFromContext:(DYYYDebugExportContext *)context completion:(DYYYDebugExportCompletion)completion {
    [self exportDebugDataForType:DYYYDebugExportTypeCurrentPageHierarchy fromContext:context completion:completion];
}

+ (void)exportWindowHierarchyFromContext:(DYYYDebugExportContext *)context completion:(DYYYDebugExportCompletion)completion {
    [self exportDebugDataForType:DYYYDebugExportTypeWindowHierarchy fromContext:context completion:completion];
}

+ (void)exportDebugDataForType:(DYYYDebugExportType)type fromContext:(DYYYDebugExportContext *)context completion:(DYYYDebugExportCompletion)completion {
    if (type == DYYYDebugExportTypeAllCurrentPageDebugData) {
        [self exportAllDebugDataFromContext:context completion:completion];
        return;
    }
    [self exportArtifactsForType:type context:context completion:completion];
}

+ (void)exportAllDebugDataFromContext:(DYYYDebugExportContext *)context completion:(DYYYDebugExportCompletion)completion {
    if (!context) {
        [self completeWithFileURLs:nil tempFilePaths:nil error:[self errorWithCode:1000 description:@"缺少调试导出上下文"] completion:completion];
        return;
    }

    void (^captureBlock)(void) = ^{
      [self ensureBatchIDOnContext:context];
      NSArray<NSDictionary *> *artifacts = [self artifactsForAllTypesWithContext:context];
      if (artifacts.count == 0) {
          [self completeWithFileURLs:nil tempFilePaths:nil error:[self errorWithCode:1003 description:@"当前没有可导出的调试信息"] completion:completion];
          return;
      }

      dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self writeArtifacts:artifacts completion:completion];
      });
    };

    if ([NSThread isMainThread]) {
        captureBlock();
    } else {
        dispatch_async(dispatch_get_main_queue(), captureBlock);
    }
}

#pragma mark - Export Flow

+ (void)exportArtifactsForType:(DYYYDebugExportType)type context:(DYYYDebugExportContext *)context completion:(DYYYDebugExportCompletion)completion {
    if (!context) {
        [self completeWithFileURLs:nil tempFilePaths:nil error:[self errorWithCode:1000 description:@"缺少调试导出上下文"] completion:completion];
        return;
    }

    void (^captureBlock)(void) = ^{
      [self ensureBatchIDOnContext:context];
      NSArray<NSDictionary *> *artifacts = [self artifactsForType:type context:context];
      if (artifacts.count == 0) {
          NSString *description = [NSString stringWithFormat:@"%@暂无可导出的信息", [self displayNameForExportType:type]];
          [self completeWithFileURLs:nil tempFilePaths:nil error:[self errorWithCode:1003 description:description] completion:completion];
          return;
      }

      dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self writeArtifacts:artifacts completion:completion];
      });
    };

    if ([NSThread isMainThread]) {
        captureBlock();
    } else {
        dispatch_async(dispatch_get_main_queue(), captureBlock);
    }
}

+ (NSArray<NSNumber *> *)singleExportTypes {
    return @[
        @(DYYYDebugExportTypeCurrentPageHierarchy),
        @(DYYYDebugExportTypeWindowHierarchy),
        @(DYYYDebugExportTypeKeyClassMethods),
        @(DYYYDebugExportTypeObjectChain),
        @(DYYYDebugExportTypeModelFieldValues),
        @(DYYYDebugExportTypeABTestSnapshot),
        @(DYYYDebugExportTypeABTestHitKeys)
    ];
}

+ (NSArray<NSDictionary *> *)artifactsForAllTypesWithContext:(DYYYDebugExportContext *)context {
    NSMutableArray<NSDictionary *> *artifacts = [NSMutableArray array];
    for (NSNumber *typeValue in [self singleExportTypes]) {
        [artifacts addObjectsFromArray:[self artifactsForType:typeValue.integerValue context:context]];
    }

    NSDictionary *manifestSnapshot = [self manifestSnapshotForArtifacts:artifacts context:context];
    [artifacts addObjectsFromArray:[self artifactsWithBaseLabel:kDYYYDebugManifestLabel
                                                     exportType:DYYYDebugExportTypeAllCurrentPageDebugData
                                                    textContent:[self textRepresentationForManifestSnapshot:manifestSnapshot]
                                                     jsonObject:manifestSnapshot
                                                        batchID:context.batchID]];
    return [artifacts copy];
}

+ (NSArray<NSDictionary *> *)artifactsForType:(DYYYDebugExportType)type context:(DYYYDebugExportContext *)context {
    NSDictionary *snapshot = nil;
    NSString *textContent = nil;
    switch (type) {
        case DYYYDebugExportTypeCurrentPageHierarchy:
        case DYYYDebugExportTypeWindowHierarchy:
            snapshot = [self hierarchySnapshotForType:type context:context];
            textContent = [self textRepresentationForHierarchySnapshot:snapshot];
            break;
        case DYYYDebugExportTypeKeyClassMethods:
            snapshot = [self methodSnapshotForContext:context];
            textContent = [self textRepresentationForMethodSnapshot:snapshot];
            break;
        case DYYYDebugExportTypeObjectChain:
            snapshot = [self objectChainSnapshotForContext:context];
            textContent = [self textRepresentationForObjectChainSnapshot:snapshot];
            break;
        case DYYYDebugExportTypeModelFieldValues:
            snapshot = [self modelFieldSnapshotForContext:context];
            textContent = [self textRepresentationForModelFieldSnapshot:snapshot];
            break;
        case DYYYDebugExportTypeABTestSnapshot:
            snapshot = [self abTestSnapshotForContext:context];
            textContent = [self textRepresentationForABTestSnapshot:snapshot];
            break;
        case DYYYDebugExportTypeABTestHitKeys:
            snapshot = [self abTestHitSnapshotForContext:context];
            textContent = [self textRepresentationForABTestHitSnapshot:snapshot];
            break;
        case DYYYDebugExportTypeAllCurrentPageDebugData:
            return @[];
    }

    if (!snapshot) {
        return @[];
    }

    return [self artifactsWithBaseLabel:[self labelForExportType:type]
                              exportType:type
                             textContent:textContent
                              jsonObject:snapshot
                                 batchID:context.batchID];
}

+ (NSArray<NSDictionary *> *)artifactsWithBaseLabel:(NSString *)baseLabel exportType:(DYYYDebugExportType)type textContent:(NSString *)textContent jsonObject:(NSDictionary *)jsonObject batchID:(NSString *)batchID {
    NSString *resolvedBatchID = batchID ?: [self newBatchID];
    NSString *textFilename = [self filenameForBatchID:resolvedBatchID label:baseLabel extension:@"txt"];
    NSString *jsonFilename = [self filenameForBatchID:resolvedBatchID label:baseLabel extension:@"json"];

    return @[
        [self artifactWithFilename:textFilename exportType:type contentType:@"text" content:textContent ?: @""],
        [self artifactWithFilename:jsonFilename exportType:type contentType:@"json" content:jsonObject ?: @{}]
    ];
}

+ (NSDictionary *)artifactWithFilename:(NSString *)filename exportType:(DYYYDebugExportType)type contentType:(NSString *)contentType content:(id)content {
    return @{
        @"filename" : filename ?: @"",
        @"exportType" : @(type),
        @"contentType" : contentType ?: @"json",
        @"content" : content ?: @{}
    };
}

+ (void)writeArtifacts:(NSArray<NSDictionary *> *)artifacts completion:(DYYYDebugExportCompletion)completion {
    NSMutableArray<NSString *> *tempFilePaths = [NSMutableArray array];
    NSMutableArray<NSURL *> *fileURLs = [NSMutableArray array];
    NSFileManager *fileManager = [NSFileManager defaultManager];

    for (NSDictionary *artifact in artifacts) {
        NSString *filename = artifact[@"filename"];
        NSString *contentType = artifact[@"contentType"];
        id content = artifact[@"content"];
        if (filename.length == 0 || contentType.length == 0) {
            continue;
        }

        NSString *filePath = [DYYYUtils cachePathForFilename:filename];
        NSError *writeError = nil;
        BOOL writeSuccess = NO;

        if ([contentType isEqualToString:@"text"]) {
            NSString *textContent = [content isKindOfClass:[NSString class]] ? (NSString *)content : [content description];
            writeSuccess = [textContent writeToFile:filePath atomically:YES encoding:NSUTF8StringEncoding error:&writeError];
        } else {
            id safeObject = DYYYJSONSafeObject(content);
            NSData *jsonData = [NSJSONSerialization dataWithJSONObject:safeObject
                                                               options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys
                                                                 error:&writeError];
            if (jsonData) {
                writeSuccess = [jsonData writeToFile:filePath options:NSDataWritingAtomic error:&writeError];
            }
        }

        if (!writeSuccess || writeError) {
            for (NSString *path in tempFilePaths) {
                if ([fileManager fileExistsAtPath:path]) {
                    [fileManager removeItemAtPath:path error:nil];
                }
            }
            [self completeWithFileURLs:nil tempFilePaths:nil error:(writeError ?: [self errorWithCode:1004 description:@"调试文件写入失败"]) completion:completion];
            return;
        }

        [tempFilePaths addObject:filePath];
        [fileURLs addObject:[NSURL fileURLWithPath:filePath]];
    }

    [self completeWithFileURLs:[fileURLs copy] tempFilePaths:[tempFilePaths copy] error:nil completion:completion];
}

+ (void)completeWithFileURLs:(NSArray<NSURL *> *)fileURLs tempFilePaths:(NSArray<NSString *> *)tempFilePaths error:(NSError *)error completion:(DYYYDebugExportCompletion)completion {
    if (!completion) {
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
      completion(fileURLs, tempFilePaths, error);
    });
}

+ (NSError *)errorWithCode:(NSInteger)code description:(NSString *)description {
    return [NSError errorWithDomain:kDYYYDebugExportErrorDomain
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey : description ?: @"调试导出失败"}];
}

#pragma mark - Context / Metadata

+ (void)ensureBatchIDOnContext:(DYYYDebugExportContext *)context {
    if (context.batchID.length == 0) {
        context.batchID = [self newBatchID];
    }
}

+ (NSString *)newBatchID {
    return [self exportTimestampString];
}

+ (NSString *)exportTimestampString {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyyMMdd_HHmmss";
    return [formatter stringFromDate:[NSDate date]];
}

+ (NSString *)labelForExportType:(DYYYDebugExportType)type {
    switch (type) {
        case DYYYDebugExportTypeCurrentPageHierarchy:
            return @"CurrentPageUI";
        case DYYYDebugExportTypeWindowHierarchy:
            return @"WindowHierarchy";
        case DYYYDebugExportTypeKeyClassMethods:
            return @"KeyClassMethods";
        case DYYYDebugExportTypeObjectChain:
            return @"ObjectChain";
        case DYYYDebugExportTypeModelFieldValues:
            return @"ModelFieldValues";
        case DYYYDebugExportTypeABTestSnapshot:
            return @"ABTestSnapshot";
        case DYYYDebugExportTypeABTestHitKeys:
            return @"ABTestHitKeys";
        case DYYYDebugExportTypeAllCurrentPageDebugData:
            return @"AllCurrentPageDebugData";
    }
}

+ (NSString *)displayNameForExportType:(DYYYDebugExportType)type {
    switch (type) {
        case DYYYDebugExportTypeCurrentPageHierarchy:
            return @"当前页 UI";
        case DYYYDebugExportTypeWindowHierarchy:
            return @"整窗 UI";
        case DYYYDebugExportTypeKeyClassMethods:
            return @"关键类方法";
        case DYYYDebugExportTypeObjectChain:
            return @"关键对象链";
        case DYYYDebugExportTypeModelFieldValues:
            return @"模型字段值";
        case DYYYDebugExportTypeABTestSnapshot:
            return @"当前 ABTest 快照";
        case DYYYDebugExportTypeABTestHitKeys:
            return @"当前页 ABTest 命中";
        case DYYYDebugExportTypeAllCurrentPageDebugData:
            return @"一键导出全部";
    }
}

+ (NSString *)filenameForBatchID:(NSString *)batchID label:(NSString *)label extension:(NSString *)extension {
    NSString *baseFilename = [NSString stringWithFormat:@"DYYY_Debug_%@_%@", batchID ?: [self newBatchID], label ?: @"Debug"];
    return [baseFilename stringByAppendingPathExtension:extension ?: @"txt"];
}

+ (NSDictionary *)baseMetadataForContext:(DYYYDebugExportContext *)context exportType:(DYYYDebugExportType)type {
    NSBundle *mainBundle = [NSBundle mainBundle];
    NSMutableDictionary *metadata = [NSMutableDictionary dictionary];
    metadata[@"batchID"] = context.batchID ?: @"";
    metadata[@"timestamp"] = [self exportTimestampString];
    metadata[@"exportType"] = [self labelForExportType:type];
    metadata[@"exportDisplayName"] = [self displayNameForExportType:type];
    metadata[@"bundleIdentifier"] = mainBundle.bundleIdentifier ?: @"";
    metadata[@"appVersion"] = [mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"";
    metadata[@"buildVersion"] = [mainBundle objectForInfoDictionaryKey:@"CFBundleVersion"] ?: @"";
    metadata[@"activeWindow"] = [self objectSummaryForObject:context.activeWindow];
    metadata[@"rootViewController"] = [self objectSummaryForObject:context.windowRootViewController];
    metadata[@"topViewController"] = [self objectSummaryForObject:context.topVisibleViewController];
    metadata[@"sourceBusinessViewController"] = [self objectSummaryForObject:context.sourceBusinessViewController];
    return [metadata copy];
}

+ (NSDictionary *)objectSummaryForObject:(id)object {
    if (!object) {
        return @{@"className" : @"", @"address" : @""};
    }

    NSMutableDictionary *summary = [NSMutableDictionary dictionary];
    summary[@"className"] = NSStringFromClass([object class]) ?: @"";
    summary[@"address"] = [NSString stringWithFormat:@"%p", object];
    return [summary copy];
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

+ (NSString *)safeStringDescriptionForObject:(id)object {
    if (!object) {
        return @"";
    }
    NSString *description = [object description] ?: @"";
    return [self truncatedString:description maxLength:200];
}

+ (NSString *)truncatedString:(NSString *)string maxLength:(NSUInteger)maxLength {
    if (string.length <= maxLength) {
        return string ?: @"";
    }
    return [[string substringToIndex:maxLength] stringByAppendingString:@"..."];
}

#pragma mark - Hierarchy Export

+ (NSDictionary *)hierarchySnapshotForType:(DYYYDebugExportType)type context:(DYYYDebugExportContext *)context {
    UIWindow *activeWindow = context.activeWindow;
    UIViewController *rootViewController = context.windowRootViewController;
    UIViewController *sourceViewController = context.sourceBusinessViewController;

    UIViewController *controllerRoot = (type == DYYYDebugExportTypeCurrentPageHierarchy) ? sourceViewController : rootViewController;
    UIView *viewRoot = (type == DYYYDebugExportTypeCurrentPageHierarchy) ? sourceViewController.view : activeWindow;
    if (!activeWindow || !rootViewController || !controllerRoot || !viewRoot) {
        return nil;
    }

    NSMutableDictionary *snapshot = [NSMutableDictionary dictionary];
    snapshot[@"metadata"] = [self baseMetadataForContext:context exportType:type];
    snapshot[@"controllerRoot"] = [self objectSummaryForObject:controllerRoot];
    snapshot[@"viewRoot"] = [self objectSummaryForObject:viewRoot];
    snapshot[@"controllerTree"] = [self controllerNodeFromController:controllerRoot context:context] ?: [NSNull null];
    snapshot[@"viewTree"] = [self viewNodeFromView:viewRoot context:context] ?: [NSNull null];
    return [snapshot copy];
}

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

    return @{
        @"className" : NSStringFromClass(viewController.class) ?: @"",
        @"address" : [NSString stringWithFormat:@"%p", viewController],
        @"title" : viewController.title ?: @"",
        @"navigationTitle" : viewController.navigationItem.title ?: @"",
        @"viewLoaded" : @([viewController isViewLoaded]),
        @"childCount" : @(children.count),
        @"presentedClassName" : presentedNode ? (NSStringFromClass(presentedViewController.class) ?: @"") : @"",
        @"children" : [children copy],
        @"presented" : presentedNode ?: [NSNull null]
    };
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

    return @{
        @"className" : NSStringFromClass(view.class) ?: @"",
        @"address" : [NSString stringWithFormat:@"%p", view],
        @"frame" : NSStringFromCGRect(view.frame),
        @"bounds" : NSStringFromCGRect(view.bounds),
        @"hidden" : @(view.hidden),
        @"alpha" : @((double)view.alpha),
        @"tag" : @(view.tag),
        @"accessibilityLabel" : view.accessibilityLabel ?: @"",
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

    if (context.debugButtonView && [view isDescendantOfView:context.debugButtonView]) {
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

+ (NSString *)textRepresentationForHierarchySnapshot:(NSDictionary *)snapshot {
    NSDictionary *metadata = snapshot[@"metadata"];
    NSMutableString *text = [NSMutableString string];
    [text appendString:@"DYYY 调试导出\n"];
    [text appendFormat:@"导出范围: %@\n", metadata[@"exportDisplayName"] ?: @""];
    [text appendFormat:@"批次: %@\n", metadata[@"batchID"] ?: @""];
    [text appendFormat:@"时间: %@\n", metadata[@"timestamp"] ?: @""];
    [text appendFormat:@"Bundle ID: %@\n", metadata[@"bundleIdentifier"] ?: @""];
    [text appendFormat:@"App Version: %@ (%@)\n", metadata[@"appVersion"] ?: @"", metadata[@"buildVersion"] ?: @""];
    [text appendFormat:@"Active Window: %@\n", [self singleLineObjectSummary:metadata[@"activeWindow"]]];
    [text appendFormat:@"Root VC: %@\n", [self singleLineObjectSummary:metadata[@"rootViewController"]]];
    [text appendFormat:@"Top VC: %@\n", [self singleLineObjectSummary:metadata[@"topViewController"]]];
    [text appendFormat:@"Source VC: %@\n", [self singleLineObjectSummary:metadata[@"sourceBusinessViewController"]]];

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

+ (void)appendControllerNode:(NSDictionary *)node toString:(NSMutableString *)text indent:(NSUInteger)indent relationship:(NSString *)relationship {
    NSString *indentString = [@"" stringByPaddingToLength:indent * 2 withString:@" " startingAtIndex:0];
    NSString *relationshipPrefix = relationship.length > 0 ? [NSString stringWithFormat:@"[%@] ", relationship] : @"";
    [text appendFormat:@"%@- %@%@ <%@> title=\"%@\" navTitle=\"%@\" viewLoaded=%@ childCount=%@\n",
                       indentString,
                       relationshipPrefix,
                       node[@"className"] ?: @"",
                       node[@"address"] ?: @"",
                       node[@"title"] ?: @"",
                       node[@"navigationTitle"] ?: @"",
                       [self boolText:node[@"viewLoaded"]],
                       node[@"childCount"] ?: @0];

    NSArray *children = node[@"children"];
    for (NSDictionary *child in children) {
        if ([child isKindOfClass:[NSDictionary class]]) {
            [self appendControllerNode:child toString:text indent:indent + 1 relationship:nil];
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
                       indentString,
                       node[@"className"] ?: @"",
                       node[@"address"] ?: @"",
                       node[@"frame"] ?: @"",
                       node[@"bounds"] ?: @"",
                       [self boolText:node[@"hidden"]],
                       [node[@"alpha"] doubleValue],
                       node[@"tag"] ?: @0,
                       node[@"accessibilityLabel"] ?: @"",
                       node[@"subviewCount"] ?: @0];

    NSArray *subviews = node[@"subviews"];
    for (NSDictionary *subview in subviews) {
        if ([subview isKindOfClass:[NSDictionary class]]) {
            [self appendViewNode:subview toString:text indent:indent + 1];
        }
    }
}

#pragma mark - Controller / Object Discovery

+ (NSArray<UIViewController *> *)controllerChainForContext:(DYYYDebugExportContext *)context {
    if (context.cachedControllerChain.count > 0) {
        return context.cachedControllerChain;
    }

    NSMutableArray<UIViewController *> *controllers = [NSMutableArray array];
    NSMutableSet<NSString *> *seenAddresses = [NSMutableSet set];
    UIViewController *currentController = context.sourceBusinessViewController;
    while (currentController) {
        NSString *address = [NSString stringWithFormat:@"%p", currentController];
        if (![seenAddresses containsObject:address]) {
            [controllers addObject:currentController];
            [seenAddresses addObject:address];
        }
        if (currentController == context.windowRootViewController) {
            break;
        }
        currentController = currentController.parentViewController;
    }

    if (context.windowRootViewController) {
        NSString *rootAddress = [NSString stringWithFormat:@"%p", context.windowRootViewController];
        if (![seenAddresses containsObject:rootAddress]) {
            [controllers addObject:context.windowRootViewController];
        }
    }

    context.cachedControllerChain = [controllers copy];
    return context.cachedControllerChain;
}

+ (NSArray<UIViewController *> *)visibleSiblingControllersForContext:(DYYYDebugExportContext *)context {
    if (context.cachedVisibleSiblingControllers.count > 0) {
        return context.cachedVisibleSiblingControllers;
    }

    NSMutableArray<UIViewController *> *controllers = [NSMutableArray array];
    UIViewController *sourceController = context.sourceBusinessViewController;
    UIViewController *parentController = sourceController.parentViewController;
    NSArray<UIViewController *> *candidates = parentController ? parentController.childViewControllers : sourceController.childViewControllers;

    for (UIViewController *controller in candidates) {
        if (controller == sourceController || !controller.isViewLoaded) {
            continue;
        }
        UIView *view = controller.view;
        if (!view.window || view.hidden || view.alpha <= 0.01) {
            continue;
        }
        [controllers addObject:controller];
    }

    context.cachedVisibleSiblingControllers = [controllers copy];
    return context.cachedVisibleSiblingControllers;
}

+ (NSArray<NSDictionary *> *)keyObjectEntriesForContext:(DYYYDebugExportContext *)context {
    if (context.cachedKeyObjectEntries.count > 0) {
        return context.cachedKeyObjectEntries;
    }

    NSMutableArray<NSDictionary *> *entries = [NSMutableArray array];
    NSMutableSet<NSString *> *seenAddresses = [NSMutableSet set];
    NSMutableArray<UIViewController *> *candidateControllers = [NSMutableArray array];
    if (context.sourceBusinessViewController) {
        [candidateControllers addObject:context.sourceBusinessViewController];
    }
    if (context.topVisibleViewController && context.topVisibleViewController != context.sourceBusinessViewController) {
        [candidateControllers addObject:context.topVisibleViewController];
    }
    [candidateControllers addObjectsFromArray:[self controllerChainForContext:context]];
    [candidateControllers addObjectsFromArray:[self visibleSiblingControllersForContext:context]];

    id primaryModel = nil;
    NSString *primaryPath = nil;
    NSString *matchedSelector = nil;
    NSArray<NSString *> *modelSelectorNames = @[ @"model", @"awemeModel", @"currentAweme" ];

    for (UIViewController *controller in candidateControllers) {
        matchedSelector = nil;
        id value = [self firstAvailableValueForSelectorNames:modelSelectorNames onObject:controller matchedSelector:&matchedSelector];
        if (value) {
            primaryModel = value;
            NSString *controllerClassName = NSStringFromClass(controller.class) ?: @"Controller";
            primaryPath = [NSString stringWithFormat:@"%@.%@", controllerClassName, matchedSelector ?: @"model"];
            break;
        }
    }

    void (^addEntry)(NSString *, NSString *, id) = ^(NSString *path, NSString *sourceAccessor, id object) {
      if (!object) {
          return;
      }
      NSString *address = [NSString stringWithFormat:@"%p", object];
      if ([seenAddresses containsObject:address]) {
          return;
      }
      [seenAddresses addObject:address];
      [entries addObject:@{
          @"path" : path ?: @"",
          @"sourceAccessor" : sourceAccessor ?: @"",
          @"object" : object,
          @"summary" : [self richSummaryForObject:object]
      }];
    };

    addEntry(primaryPath ?: @"primaryModel", matchedSelector ?: @"", primaryModel);

    if (primaryModel) {
        id video = [self safeValueForKey:@"video" onObject:primaryModel];
        id music = [self safeValueForKey:@"music" onObject:primaryModel];
        id author = [self safeValueForKey:@"author" onObject:primaryModel];
        id statistics = [self safeValueForKey:@"statistics" onObject:primaryModel];
        id animatedImageVideoInfo = [self safeValueForKey:@"animatedImageVideoInfo" onObject:primaryModel];
        id propGuideV2 = [self safeValueForKey:@"propGuideV2" onObject:primaryModel];
        NSArray *albumImages = [self safeValueForKey:@"albumImages" onObject:primaryModel];
        id firstAlbumImage = ([albumImages isKindOfClass:[NSArray class]] && [(NSArray *)albumImages count] > 0) ? [(NSArray *)albumImages firstObject] : nil;

        addEntry([NSString stringWithFormat:@"%@.video", primaryPath], @"video", video);
        addEntry([NSString stringWithFormat:@"%@.music", primaryPath], @"music", music);
        addEntry([NSString stringWithFormat:@"%@.author", primaryPath], @"author", author);
        addEntry([NSString stringWithFormat:@"%@.statistics", primaryPath], @"statistics", statistics);
        addEntry([NSString stringWithFormat:@"%@.animatedImageVideoInfo", primaryPath], @"animatedImageVideoInfo", animatedImageVideoInfo);
        addEntry([NSString stringWithFormat:@"%@.propGuideV2", primaryPath], @"propGuideV2", propGuideV2);
        addEntry([NSString stringWithFormat:@"%@.albumImages.firstObject", primaryPath], @"albumImages.firstObject", firstAlbumImage);

        addEntry([NSString stringWithFormat:@"%@.video.playURL", primaryPath], @"video.playURL", [self safeValueForKey:@"playURL" onObject:video]);
        addEntry([NSString stringWithFormat:@"%@.video.playLowBitURL", primaryPath], @"video.playLowBitURL", [self safeValueForKey:@"playLowBitURL" onObject:video]);
        addEntry([NSString stringWithFormat:@"%@.video.coverURL", primaryPath], @"video.coverURL", [self safeValueForKey:@"coverURL" onObject:video]);
        addEntry([NSString stringWithFormat:@"%@.video.h264URL", primaryPath], @"video.h264URL", [self safeValueForKey:@"h264URL" onObject:video]);
        addEntry([NSString stringWithFormat:@"%@.music.playURL", primaryPath], @"music.playURL", [self safeValueForKey:@"playURL" onObject:music]);
        addEntry([NSString stringWithFormat:@"%@.author.avatarMedium", primaryPath], @"author.avatarMedium", [self safeValueForKey:@"avatarMedium" onObject:author]);
        addEntry([NSString stringWithFormat:@"%@.albumImages.firstObject.clipVideo", primaryPath], @"albumImages.firstObject.clipVideo", [self safeValueForKey:@"clipVideo" onObject:firstAlbumImage]);
    }

    context.cachedKeyObjectEntries = [entries copy];
    return context.cachedKeyObjectEntries;
}

+ (NSArray<NSDictionary *> *)keyClassEntriesForContext:(DYYYDebugExportContext *)context {
    if (context.cachedKeyClassEntries.count > 0) {
        return context.cachedKeyClassEntries;
    }

    NSMutableDictionary<NSString *, NSMutableDictionary *> *classMap = [NSMutableDictionary dictionary];

    void (^addClass)(id, NSString *) = ^(id object, NSString *reason) {
      if (!object) {
          return;
      }
      Class targetClass = [object class];
      NSString *className = NSStringFromClass(targetClass) ?: @"";
      if (className.length == 0) {
          return;
      }

      NSMutableDictionary *entry = classMap[className];
      if (!entry) {
          entry = [@{
              @"classObject" : targetClass,
              @"className" : className,
              @"sampleObject" : [self objectSummaryForObject:object],
              @"reasons" : [NSMutableOrderedSet orderedSet]
          } mutableCopy];
          classMap[className] = entry;
      }
      [(NSMutableOrderedSet *)entry[@"reasons"] addObject:reason ?: @"unknown"];
    };

    for (UIViewController *controller in [self controllerChainForContext:context]) {
        addClass(controller, @"controller_chain");
    }
    for (UIViewController *controller in [self visibleSiblingControllersForContext:context]) {
        addClass(controller, @"visible_sibling");
    }
    for (NSDictionary *entry in [self keyObjectEntriesForContext:context]) {
        addClass(entry[@"object"], @"model_chain");
    }

    NSMutableArray<NSDictionary *> *sortedEntries = [NSMutableArray array];
    NSArray<NSString *> *sortedClassNames = [[classMap allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    for (NSString *className in sortedClassNames) {
        NSMutableDictionary *entry = classMap[className];
        NSMutableDictionary *normalizedEntry = [entry mutableCopy];
        normalizedEntry[@"reasons"] = [[(NSOrderedSet *)entry[@"reasons"] array] copy];
        [sortedEntries addObject:[normalizedEntry copy]];
    }

    context.cachedKeyClassEntries = [sortedEntries copy];
    return context.cachedKeyClassEntries;
}

#pragma mark - Method Export

+ (NSDictionary *)methodSnapshotForContext:(DYYYDebugExportContext *)context {
    NSMutableArray<NSDictionary *> *classes = [NSMutableArray array];
    for (NSDictionary *entry in [self keyClassEntriesForContext:context]) {
        Class targetClass = entry[@"classObject"];
        if (!targetClass) {
            continue;
        }

        [classes addObject:@{
            @"className" : entry[@"className"] ?: @"",
            @"superclassName" : NSStringFromClass(class_getSuperclass(targetClass)) ?: @"",
            @"reasons" : entry[@"reasons"] ?: @[],
            @"sampleObject" : entry[@"sampleObject"] ?: @{},
            @"instanceMethods" : [self methodsForClass:targetClass classMethods:NO],
            @"classMethods" : [self methodsForClass:targetClass classMethods:YES]
        }];
    }

    return @{
        @"metadata" : [self baseMetadataForContext:context exportType:DYYYDebugExportTypeKeyClassMethods],
        @"classes" : [classes copy]
    };
}

+ (NSArray<NSDictionary *> *)methodsForClass:(Class)targetClass classMethods:(BOOL)classMethods {
    if (!targetClass) {
        return @[];
    }

    Class methodContainer = classMethods ? object_getClass(targetClass) : targetClass;
    unsigned int methodCount = 0;
    Method *methodList = class_copyMethodList(methodContainer, &methodCount);
    NSMutableArray<NSDictionary *> *methods = [NSMutableArray array];
    for (unsigned int index = 0; index < methodCount; index++) {
        SEL selector = method_getName(methodList[index]);
        const char *typeEncoding = method_getTypeEncoding(methodList[index]);
        [methods addObject:@{
            @"selector" : NSStringFromSelector(selector) ?: @"",
            @"typeEncoding" : typeEncoding ? @(typeEncoding) : @""
        }];
    }
    if (methodList) {
        free(methodList);
    }

    [methods sortUsingComparator:^NSComparisonResult(NSDictionary *left, NSDictionary *right) {
      return [left[@"selector"] localizedCaseInsensitiveCompare:right[@"selector"]];
    }];
    return [methods copy];
}

+ (NSString *)textRepresentationForMethodSnapshot:(NSDictionary *)snapshot {
    NSMutableString *text = [NSMutableString string];
    NSDictionary *metadata = snapshot[@"metadata"];
    [text appendString:@"DYYY 调试导出\n"];
    [text appendFormat:@"导出范围: %@\n", metadata[@"exportDisplayName"] ?: @""];
    [text appendFormat:@"批次: %@\n", metadata[@"batchID"] ?: @""];
    [text appendFormat:@"Source VC: %@\n", [self singleLineObjectSummary:metadata[@"sourceBusinessViewController"]]];

    NSArray *classes = snapshot[@"classes"];
    [text appendFormat:@"类数量: %lu\n", (unsigned long)classes.count];
    [text appendString:@"\n== 关键类方法列表 ==\n"];
    for (NSDictionary *classInfo in classes) {
        [text appendFormat:@"\n[%@] reasons=%@\n", classInfo[@"className"] ?: @"", [classInfo[@"reasons"] componentsJoinedByString:@","]];
        [text appendFormat:@"superclass=%@\n", classInfo[@"superclassName"] ?: @""];
        [text appendFormat:@"sample=%@\n", [self singleLineObjectSummary:classInfo[@"sampleObject"]]];

        [text appendString:@"实例方法:\n"];
        for (NSDictionary *method in classInfo[@"instanceMethods"]) {
            [text appendFormat:@"  - %@  %s\n", method[@"selector"] ?: @"", [method[@"typeEncoding"] UTF8String]];
        }
        [text appendString:@"类方法:\n"];
        for (NSDictionary *method in classInfo[@"classMethods"]) {
            [text appendFormat:@"  - %@  %s\n", method[@"selector"] ?: @"", [method[@"typeEncoding"] UTF8String]];
        }
    }

    return [text copy];
}

#pragma mark - Object Chain Export

+ (NSDictionary *)objectChainSnapshotForContext:(DYYYDebugExportContext *)context {
    NSMutableArray<NSDictionary *> *controllerChain = [NSMutableArray array];
    for (UIViewController *controller in [self controllerChainForContext:context]) {
        [controllerChain addObject:[self richSummaryForObject:controller]];
    }

    NSMutableArray<NSDictionary *> *visibleSiblings = [NSMutableArray array];
    for (UIViewController *controller in [self visibleSiblingControllersForContext:context]) {
        [visibleSiblings addObject:[self richSummaryForObject:controller]];
    }

    NSMutableArray<NSDictionary *> *objectChain = [NSMutableArray array];
    for (NSDictionary *entry in [self keyObjectEntriesForContext:context]) {
        [objectChain addObject:@{
            @"path" : entry[@"path"] ?: @"",
            @"sourceAccessor" : entry[@"sourceAccessor"] ?: @"",
            @"className" : [entry[@"summary"] objectForKey:@"className"] ?: @"",
            @"address" : [entry[@"summary"] objectForKey:@"address"] ?: @"",
            @"summary" : entry[@"summary"] ?: @{}
        }];
    }

    return @{
        @"metadata" : [self baseMetadataForContext:context exportType:DYYYDebugExportTypeObjectChain],
        @"controllerChain" : [controllerChain copy],
        @"visibleSiblingControllers" : [visibleSiblings copy],
        @"objectChain" : [objectChain copy]
    };
}

+ (NSString *)textRepresentationForObjectChainSnapshot:(NSDictionary *)snapshot {
    NSDictionary *metadata = snapshot[@"metadata"];
    NSMutableString *text = [NSMutableString string];
    [text appendString:@"DYYY 调试导出\n"];
    [text appendFormat:@"导出范围: %@\n", metadata[@"exportDisplayName"] ?: @""];
    [text appendFormat:@"批次: %@\n", metadata[@"batchID"] ?: @""];

    [text appendString:@"\n== 控制器链 ==\n"];
    for (NSDictionary *controller in snapshot[@"controllerChain"]) {
        [text appendFormat:@"- %@ <%@> title=\"%@\"\n",
                           controller[@"className"] ?: @"",
                           controller[@"address"] ?: @"",
                           controller[@"title"] ?: @""];
    }

    [text appendString:@"\n== 可见同级控制器 ==\n"];
    NSArray *visibleSiblingControllers = snapshot[@"visibleSiblingControllers"];
    if (visibleSiblingControllers.count == 0) {
        [text appendString:@"(无)\n"];
    } else {
        for (NSDictionary *controller in visibleSiblingControllers) {
            [text appendFormat:@"- %@ <%@>\n", controller[@"className"] ?: @"", controller[@"address"] ?: @""];
        }
    }

    [text appendString:@"\n== 关键对象链 ==\n"];
    for (NSDictionary *entry in snapshot[@"objectChain"]) {
        NSDictionary *summary = entry[@"summary"];
        [text appendFormat:@"- %@ -> %@ <%@> via %@\n",
                           entry[@"path"] ?: @"",
                           entry[@"className"] ?: @"",
                           entry[@"address"] ?: @"",
                           entry[@"sourceAccessor"] ?: @""];
        if ([summary isKindOfClass:[NSDictionary class]]) {
            NSString *detail = summary[@"detail"];
            if (detail.length > 0) {
                [text appendFormat:@"  %@\n", detail];
            }
        }
    }

    return [text copy];
}

#pragma mark - Model Field Export

+ (NSDictionary *)modelFieldSnapshotForContext:(DYYYDebugExportContext *)context {
    NSMutableArray<NSDictionary *> *objectDumps = [NSMutableArray array];
    for (NSDictionary *entry in [self keyObjectEntriesForContext:context]) {
        [objectDumps addObject:[self objectDumpForEntry:entry]];
    }

    return @{
        @"metadata" : [self baseMetadataForContext:context exportType:DYYYDebugExportTypeModelFieldValues],
        @"objectCount" : @(objectDumps.count),
        @"objects" : [objectDumps copy]
    };
}

+ (NSDictionary *)objectDumpForEntry:(NSDictionary *)entry {
    id object = entry[@"object"];
    return @{
        @"path" : entry[@"path"] ?: @"",
        @"sourceAccessor" : entry[@"sourceAccessor"] ?: @"",
        @"summary" : [self richSummaryForObject:object] ?: @{},
        @"classSegments" : [self classSegmentsForObject:object]
    };
}

+ (NSArray<NSDictionary *> *)classSegmentsForObject:(id)object {
    if (!object) {
        return @[];
    }

    Class currentClass = [object class];
    if (!currentClass || currentClass == [NSObject class]) {
        return @[];
    }

    Class superclass = class_getSuperclass(currentClass);
    NSMutableDictionary *segment = [@{
        @"className" : NSStringFromClass(currentClass) ?: @"",
        @"properties" : [self propertyEntriesForClass:currentClass object:object],
        @"ivars" : [self ivarEntriesForClass:currentClass object:object]
    } mutableCopy];
    if (superclass && superclass != [NSObject class]) {
        segment[@"superclassName"] = NSStringFromClass(superclass) ?: @"";
    }
    return @[ [segment copy] ];
}

+ (NSArray<NSDictionary *> *)propertyEntriesForClass:(Class)targetClass object:(id)object {
    unsigned int propertyCount = 0;
    objc_property_t *propertyList = class_copyPropertyList(targetClass, &propertyCount);
    NSMutableArray<NSDictionary *> *properties = [NSMutableArray array];
    for (unsigned int index = 0; index < propertyCount; index++) {
        objc_property_t property = propertyList[index];
        NSString *name = property_getName(property) ? @(property_getName(property)) : @"";
        NSString *attributes = property_getAttributes(property) ? @(property_getAttributes(property)) : @"";
        id value = [self safeValueForKey:name onObject:object];
        [properties addObject:@{
            @"name" : name,
            @"attributes" : attributes,
            @"value" : [self serializableValueSummary:value] ?: [NSNull null]
        }];
    }
    if (propertyList) {
        free(propertyList);
    }

    [properties sortUsingComparator:^NSComparisonResult(NSDictionary *left, NSDictionary *right) {
      return [left[@"name"] localizedCaseInsensitiveCompare:right[@"name"]];
    }];
    return [properties copy];
}

+ (NSArray<NSDictionary *> *)ivarEntriesForClass:(Class)targetClass object:(id)object {
    unsigned int ivarCount = 0;
    Ivar *ivarList = class_copyIvarList(targetClass, &ivarCount);
    NSMutableArray<NSDictionary *> *ivars = [NSMutableArray array];
    for (unsigned int index = 0; index < ivarCount; index++) {
        Ivar ivar = ivarList[index];
        NSString *name = ivar_getName(ivar) ? @(ivar_getName(ivar)) : @"";
        NSString *typeEncoding = ivar_getTypeEncoding(ivar) ? @(ivar_getTypeEncoding(ivar)) : @"";

        id valueSummary = [NSNull null];
        if ([typeEncoding hasPrefix:@"@"]) {
            @try {
                id value = object_getIvar(object, ivar);
                valueSummary = [self serializableValueSummary:value] ?: [NSNull null];
            } @catch (__unused NSException *exception) {
                valueSummary = @"<unavailable>";
            }
        }

        [ivars addObject:@{
            @"name" : name,
            @"typeEncoding" : typeEncoding,
            @"value" : valueSummary ?: [NSNull null]
        }];
    }
    if (ivarList) {
        free(ivarList);
    }

    [ivars sortUsingComparator:^NSComparisonResult(NSDictionary *left, NSDictionary *right) {
      return [left[@"name"] localizedCaseInsensitiveCompare:right[@"name"]];
    }];
    return [ivars copy];
}

+ (id)serializableValueSummary:(id)value {
    if (!value) {
        return [NSNull null];
    }
    if ([value isKindOfClass:[NSString class]] || [value isKindOfClass:[NSNumber class]]) {
        return value;
    }
    if ([value isKindOfClass:[NSURL class]]) {
        return [(NSURL *)value absoluteString] ?: @"";
    }
    if ([value isKindOfClass:[NSDate class]]) {
        return @([(NSDate *)value timeIntervalSince1970]);
    }
    if ([value isKindOfClass:[NSData class]]) {
        return @{
            @"className" : NSStringFromClass([value class]) ?: @"NSData",
            @"length" : @([(NSData *)value length])
        };
    }
    if ([value isKindOfClass:[NSArray class]]) {
        NSMutableArray *preview = [NSMutableArray array];
        NSArray *array = (NSArray *)value;
        NSUInteger maxCount = MIN(array.count, 5);
        for (NSUInteger index = 0; index < maxCount; index++) {
            [preview addObject:[self serializableValueSummary:array[index]] ?: [NSNull null]];
        }
        return @{
            @"className" : NSStringFromClass([value class]) ?: @"NSArray",
            @"count" : @(array.count),
            @"preview" : preview
        };
    }
    if ([value isKindOfClass:[NSDictionary class]]) {
        NSMutableDictionary *preview = [NSMutableDictionary dictionary];
        NSArray *sortedKeys = [[(NSDictionary *)value allKeys] sortedArrayUsingComparator:^NSComparisonResult(id left, id right) {
          return [[left description] localizedCaseInsensitiveCompare:[right description]];
        }];
        NSUInteger maxCount = MIN(sortedKeys.count, 5);
        for (NSUInteger index = 0; index < maxCount; index++) {
            id key = sortedKeys[index];
            preview[[key description]] = [self serializableValueSummary:[(NSDictionary *)value objectForKey:key]] ?: [NSNull null];
        }
        return @{
            @"className" : NSStringFromClass([value class]) ?: @"NSDictionary",
            @"count" : @([(NSDictionary *)value count]),
            @"preview" : preview
        };
    }

    return [self richSummaryForObject:value];
}

+ (NSString *)textRepresentationForModelFieldSnapshot:(NSDictionary *)snapshot {
    NSDictionary *metadata = snapshot[@"metadata"];
    NSMutableString *text = [NSMutableString string];
    [text appendString:@"DYYY 调试导出\n"];
    [text appendFormat:@"导出范围: %@\n", metadata[@"exportDisplayName"] ?: @""];
    [text appendFormat:@"批次: %@\n", metadata[@"batchID"] ?: @""];
    [text appendFormat:@"对象数量: %@\n", snapshot[@"objectCount"] ?: @0];
    [text appendString:@"说明: 仅导出每个对象当前类的一层字段，常用链路对象会单独展开。\n"];

    [text appendString:@"\n== 模型字段值 ==\n"];
    for (NSDictionary *objectDump in snapshot[@"objects"]) {
        [self appendObjectDump:objectDump toString:text];
    }
    return [text copy];
}

+ (void)appendObjectDump:(NSDictionary *)objectDump toString:(NSMutableString *)text {
    NSDictionary *summary = objectDump[@"summary"];
    [text appendFormat:@"\n[%@] %@ <%@> via %@\n",
                       objectDump[@"path"] ?: @"",
                       summary[@"className"] ?: @"",
                       summary[@"address"] ?: @"",
                       objectDump[@"sourceAccessor"] ?: @""];
    if (summary[@"detail"]) {
        [text appendFormat:@"detail: %@\n", summary[@"detail"]];
    }

    for (NSDictionary *segment in objectDump[@"classSegments"]) {
        [text appendFormat:@"  class: %@\n", segment[@"className"] ?: @""];
        if ([segment[@"superclassName"] length] > 0) {
            [text appendFormat:@"  superclass: %@\n", segment[@"superclassName"]];
        }
        [text appendString:@"  properties:\n"];
        for (NSDictionary *property in segment[@"properties"]) {
            [text appendFormat:@"    - %@ = %@\n", property[@"name"] ?: @"", [self safeStringDescriptionForObject:property[@"value"]]];
        }
        [text appendString:@"  ivars:\n"];
        for (NSDictionary *ivar in segment[@"ivars"]) {
            [text appendFormat:@"    - %@ (%@) = %@\n",
                               ivar[@"name"] ?: @"",
                               ivar[@"typeEncoding"] ?: @"",
                               [self safeStringDescriptionForObject:ivar[@"value"]]];
        }
    }
}

#pragma mark - ABTest Export

+ (NSDictionary *)abTestSnapshotForContext:(DYYYDebugExportContext *)context {
    NSDictionary *abTestData = [DYYYABTestHook getCurrentABTestData] ?: @{};
    NSArray *sortedKeys = [[abTestData allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    return @{
        @"metadata" : [self baseMetadataForContext:context exportType:DYYYDebugExportTypeABTestSnapshot],
        @"topLevelKeyCount" : @(sortedKeys.count),
        @"topLevelKeys" : sortedKeys ?: @[],
        @"abTestData" : abTestData ?: @{}
    };
}

+ (NSString *)textRepresentationForABTestSnapshot:(NSDictionary *)snapshot {
    NSDictionary *metadata = snapshot[@"metadata"];
    NSMutableString *text = [NSMutableString string];
    [text appendString:@"DYYY 调试导出\n"];
    [text appendFormat:@"导出范围: %@\n", metadata[@"exportDisplayName"] ?: @""];
    [text appendFormat:@"批次: %@\n", metadata[@"batchID"] ?: @""];
    [text appendFormat:@"顶层 Key 数量: %@\n", snapshot[@"topLevelKeyCount"] ?: @0];
    [text appendString:@"\n== Top Level Keys ==\n"];
    for (NSString *key in [snapshot[@"topLevelKeys"] subarrayWithRange:NSMakeRange(0, MIN(50, [snapshot[@"topLevelKeys"] count]))]) {
        [text appendFormat:@"- %@\n", key];
    }
    if ([snapshot[@"topLevelKeys"] count] > 50) {
        [text appendString:@"...（其余详见 JSON）\n"];
    }
    return [text copy];
}

+ (NSDictionary *)abTestHitSnapshotForContext:(DYYYDebugExportContext *)context {
    NSDictionary *hitSnapshot = [DYYYABTestHook debugABTestHitSnapshotForCurrentPageContext:context] ?: @{};
    NSMutableDictionary *snapshot = [NSMutableDictionary dictionaryWithDictionary:hitSnapshot];
    snapshot[@"metadata"] = [self baseMetadataForContext:context exportType:DYYYDebugExportTypeABTestHitKeys];
    return [snapshot copy];
}

+ (NSString *)textRepresentationForABTestHitSnapshot:(NSDictionary *)snapshot {
    NSDictionary *metadata = snapshot[@"metadata"];
    NSMutableString *text = [NSMutableString string];
    [text appendString:@"DYYY 调试导出\n"];
    [text appendFormat:@"导出范围: %@\n", metadata[@"exportDisplayName"] ?: @""];
    [text appendFormat:@"批次: %@\n", metadata[@"batchID"] ?: @""];
    [text appendFormat:@"页面: %@ <%@>\n", snapshot[@"pageClassName"] ?: @"Unknown", snapshot[@"pageAddress"] ?: @"0x0"];
    [text appendFormat:@"唯一 Key 数量: %@\n", snapshot[@"uniqueKeyCount"] ?: @0];
    [text appendFormat:@"记录数量: %@\n", snapshot[@"recordCount"] ?: @0];

    [text appendString:@"\n== 命中 Key ==\n"];
    NSArray *uniqueKeys = snapshot[@"uniqueKeys"];
    if (uniqueKeys.count == 0) {
        [text appendString:@"(无)\n"];
    } else {
        for (NSString *key in uniqueKeys) {
            [text appendFormat:@"- %@\n", key];
        }
    }

    [text appendString:@"\n== 最近命中记录 ==\n"];
    NSArray *records = snapshot[@"records"];
    NSUInteger startIndex = (records.count > 30) ? (records.count - 30) : 0;
    for (NSUInteger index = startIndex; index < records.count; index++) {
        NSDictionary *record = records[index];
        [text appendFormat:@"- %.3f %@\n", [record[@"timestamp"] doubleValue], record[@"key"] ?: @""];
    }

    return [text copy];
}

#pragma mark - Manifest

+ (NSDictionary *)manifestSnapshotForArtifacts:(NSArray<NSDictionary *> *)artifacts context:(DYYYDebugExportContext *)context {
    NSMutableArray<NSDictionary *> *files = [NSMutableArray array];
    for (NSDictionary *artifact in artifacts) {
        DYYYDebugExportType exportType = [artifact[@"exportType"] integerValue];
        [files addObject:@{
            @"filename" : artifact[@"filename"] ?: @"",
            @"exportType" : [self labelForExportType:exportType],
            @"exportDisplayName" : [self displayNameForExportType:exportType],
            @"contentType" : artifact[@"contentType"] ?: @"json"
        }];
    }

    return @{
        @"metadata" : [self baseMetadataForContext:context exportType:DYYYDebugExportTypeAllCurrentPageDebugData],
        @"fileCount" : @(files.count),
        @"files" : [files copy]
    };
}

+ (NSString *)textRepresentationForManifestSnapshot:(NSDictionary *)snapshot {
    NSDictionary *metadata = snapshot[@"metadata"];
    NSMutableString *text = [NSMutableString string];
    [text appendString:@"DYYY 调试导出清单\n"];
    [text appendFormat:@"批次: %@\n", metadata[@"batchID"] ?: @""];
    [text appendFormat:@"文件数量: %@\n", snapshot[@"fileCount"] ?: @0];
    [text appendString:@"\n== 文件列表 ==\n"];
    for (NSDictionary *file in snapshot[@"files"]) {
        [text appendFormat:@"- %@ (%@ / %@)\n",
                           file[@"filename"] ?: @"",
                           file[@"exportDisplayName"] ?: @"",
                           file[@"contentType"] ?: @""];
    }
    return [text copy];
}

#pragma mark - Rich Object Helpers

+ (NSDictionary *)richSummaryForObject:(id)object {
    NSMutableDictionary *summary = [[self objectSummaryForObject:object] mutableCopy];
    if (!object) {
        return [summary copy];
    }

    NSString *className = summary[@"className"] ?: @"";
    NSMutableArray<NSString *> *details = [NSMutableArray array];

    if ([object isKindOfClass:[UIViewController class]]) {
        UIViewController *viewController = (UIViewController *)object;
        summary[@"title"] = viewController.title ?: @"";
        summary[@"navigationTitle"] = viewController.navigationItem.title ?: @"";
        summary[@"viewLoaded"] = @([viewController isViewLoaded]);
        if (viewController.title.length > 0) {
            [details addObject:[NSString stringWithFormat:@"title=%@", viewController.title]];
        }
    } else if ([className isEqualToString:@"AWEAwemeModel"]) {
        id itemID = [self safeValueForKey:@"itemID" onObject:object];
        id awemeType = [self safeValueForKey:@"awemeType" onObject:object];
        id descriptionString = [self safeValueForKey:@"descriptionString" onObject:object];
        id isLive = [self safeValueForKey:@"isLive" onObject:object];
        id isAds = [self safeValueForKey:@"isAds" onObject:object];
        NSArray *albumImages = [self safeValueForKey:@"albumImages" onObject:object];
        if (itemID) {
            summary[@"itemID"] = itemID;
            [details addObject:[NSString stringWithFormat:@"itemID=%@", itemID]];
        }
        if (awemeType) {
            summary[@"awemeType"] = awemeType;
            [details addObject:[NSString stringWithFormat:@"awemeType=%@", awemeType]];
        }
        if (descriptionString) {
            NSString *desc = [self truncatedString:[descriptionString description] maxLength:60];
            summary[@"descriptionString"] = desc;
            [details addObject:[NSString stringWithFormat:@"desc=%@", desc]];
        }
        if (isLive) {
            summary[@"isLive"] = @([isLive boolValue]);
        }
        if (isAds) {
            summary[@"isAds"] = @([isAds boolValue]);
        }
        if ([albumImages isKindOfClass:[NSArray class]]) {
            summary[@"albumImageCount"] = @([(NSArray *)albumImages count]);
        }
    } else if ([className isEqualToString:@"AWEVideoModel"]) {
        NSArray *bitrateModels = [self safeValueForKey:@"bitrateModels" onObject:object];
        id playURL = [self safeValueForKey:@"playURL" onObject:object];
        summary[@"hasPlayURL"] = @(playURL != nil);
        if ([bitrateModels isKindOfClass:[NSArray class]]) {
            summary[@"bitrateModelCount"] = @([(NSArray *)bitrateModels count]);
        }
    } else if ([className isEqualToString:@"AWEMusicModel"]) {
        id playURL = [self safeValueForKey:@"playURL" onObject:object];
        summary[@"hasPlayURL"] = @(playURL != nil);
    } else if ([className isEqualToString:@"AWEUserModel"]) {
        id nickname = [self safeValueForKey:@"nickname" onObject:object];
        id shortID = [self safeValueForKey:@"shortID" onObject:object];
        if (nickname) {
            summary[@"nickname"] = nickname;
            [details addObject:[NSString stringWithFormat:@"nickname=%@", nickname]];
        }
        if (shortID) {
            summary[@"shortID"] = shortID;
        }
    } else if ([className isEqualToString:@"AWEAwemeStatisticsModel"]) {
        id diggCount = [self safeValueForKey:@"diggCount" onObject:object];
        if (diggCount) {
            summary[@"diggCount"] = diggCount;
            [details addObject:[NSString stringWithFormat:@"diggCount=%@", diggCount]];
        }
    }

    if (details.count == 0) {
        NSString *description = [self safeStringDescriptionForObject:object];
        if (description.length > 0) {
            details = [@[ description ] mutableCopy];
        }
    }

    summary[@"detail"] = [details componentsJoinedByString:@" | "];
    return [summary copy];
}

+ (id)firstAvailableValueForSelectorNames:(NSArray<NSString *> *)selectorNames onObject:(id)object matchedSelector:(NSString **)matchedSelector {
    for (NSString *selectorName in selectorNames) {
        id value = [self safeValueForKey:selectorName onObject:object];
        if (value) {
            if (matchedSelector) {
                *matchedSelector = selectorName;
            }
            return value;
        }
    }
    return nil;
}

+ (id)safeValueForKey:(NSString *)key onObject:(id)object {
    if (key.length == 0 || !object) {
        return nil;
    }

    @try {
        return [object valueForKey:key];
    } @catch (__unused NSException *exception) {
    }

    SEL selector = NSSelectorFromString(key);
    if ([object respondsToSelector:selector]) {
        @try {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            return [object performSelector:selector];
#pragma clang diagnostic pop
        } @catch (__unused NSException *exception) {
            return nil;
        }
    }

    return nil;
}

@end
