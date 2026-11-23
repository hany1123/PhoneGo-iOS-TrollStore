//
//  PGScreen.m
//  巨魔无沙盒下截取全屏。iOS SDK 不公开 CGDisplayCreateImage，全部用 dlsym 动态解析。
//  路径优先级：
//   1) CoreGraphics CGDisplayCreateImage —— 无沙盒 + platform-application 下可读主 display
//   2) UIGraphics 抓自身所有 window（自身窗口，跨 App 需路径 1）
//
#import "PGScreen.h"
#import "PGCommon.h"
#import <dlfcn.h>
#import <CoreGraphics/CoreGraphics.h>

// iOS 上 CGDirectDisplayID = uint32_t；符号用 dlsym 取，避免 implicit declaration
typedef uint32_t PGDisplayID;
typedef CGImageRef (*PGCaptureScreenFn)(PGDisplayID display);
typedef PGDisplayID (*PGMainDisplayFn)(void);

@implementation PGScreen {
    BOOL _probed;
    NSString *_info;
    void *_cgLib;
    PGCaptureScreenFn _captureScreen;
    PGMainDisplayFn _mainDisplay;
}

+ (instancetype)shared {
    static PGScreen *s = nil; static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [[PGScreen alloc] init]; });
    return s;
}

- (instancetype)init {
    if (self = [super init]) [self probe];
    return self;
}

- (void)probe {
    _cgLib = dlopen("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics", RTLD_LAZY);
    void *bks = dlopen("/System/Library/PrivateFrameworks/BackBoardServices.framework/BackBoardServices", RTLD_LAZY);
    _mainDisplay = (PGMainDisplayFn)dlsym(RTLD_DEFAULT, "CGMainDisplayID");
    _captureScreen = (PGCaptureScreenFn)dlsym(RTLD_DEFAULT, "CGDisplayCreateImage");
    if (!_captureScreen && _cgLib) _captureScreen = (PGCaptureScreenFn)dlsym(_cgLib, "CGDisplayCreateImage");
    _probed = YES;
    _info = [NSString stringWithFormat:@"CG截图=%@ 主屏=%@ backboard=%@ scale=%.2f",
        _captureScreen ? @"OK" : @"--", _mainDisplay ? @"OK" : @"--",
        bks ? @"OK" : @"--", [UIScreen mainScreen].scale];
    PGLog("%@", _info);
}

- (NSData *)capturePNG:(CGSize *)outPointSize {
    UIImage *img = nil;

    // 路径 1：CGDisplayCreateImage（dlsym）—— 无沙盒下读整个 display
    if (_captureScreen) {
        PGDisplayID display = _mainDisplay ? _mainDisplay() : 0;
        CGImageRef cg = _captureScreen(display);
        if (cg) {
            img = [UIImage imageWithCGImage:cg scale:1.0 orientation:UIImageOrientationUp];
            CGImageRelease(cg);
            PGLog("路径1 CGDisplayCreateImage 成功");
        }
    }

    // 路径 2：UIGraphics 抓自身所有 window（自身窗口；跨 App 需路径 1）
    if (!img) {
        CGRect bounds = [UIScreen mainScreen].bounds;
        UIGraphicsBeginImageContextWithOptions(bounds.size, NO, 0);
        NSArray *wins = [[UIApplication sharedApplication] windows];
        for (UIWindow *w in wins) {
            [w drawViewHierarchyInRect:bounds afterScreenUpdates:NO];
        }
        img = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        if (img) PGLog("路径2 UIGraphics 成功（仅自身窗口）");
    }

    if (!img) {
        PGLog("截屏失败：两条路径均无图像");
        if (outPointSize) *outPointSize = CGSizeZero;
        return nil;
    }
    if (outPointSize) *outPointSize = img.size;
    NSData *png = UIImagePNGRepresentation(img);
    PGLog("截屏成功 %.0fx%.0f png=%lu bytes", img.size.width, img.size.height, (unsigned long)png.length);
    return png;
}

- (NSString *)diagnosticInfo { return _info ?: @"未探测"; }
@end
