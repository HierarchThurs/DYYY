#import "DYYYBackupPickerDelegate.h"

@implementation DYYYBackupPickerDelegate
- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    if (urls.count > 0 && self.completionBlock) {
        self.completionBlock(urls.firstObject);
    }
    [self cleanupTempFile];
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
    [self cleanupTempFile];
}

- (void)cleanupTempFile {
    NSMutableArray<NSString *> *paths = [NSMutableArray array];
    if (self.tempFilePaths.count > 0) {
        [paths addObjectsFromArray:self.tempFilePaths];
    }
    if (self.tempFilePath.length > 0) {
        [paths addObject:self.tempFilePath];
    }

    NSFileManager *fileManager = [NSFileManager defaultManager];
    for (NSString *path in paths) {
        if (path.length == 0 || ![fileManager fileExistsAtPath:path]) {
            continue;
        }
        NSError *error = nil;
        [fileManager removeItemAtPath:path error:&error];
        if (error) {
            NSLog(@"[DYYY] \u6e05\u7406\u4e34\u65f6\u6587\u4ef6\u5931\u8d25: %@", error.localizedDescription);
        }
    }
}
@end
