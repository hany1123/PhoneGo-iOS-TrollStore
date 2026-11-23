//
//  PGScreen.m
//  巨魔无沙盒下截取全屏：优先用 backboardd 的 IOSurface，降级到 UIGraphics 截自身窗口。
//  关键：普通沙盒 App 只能截自己；no-sandbox + 私有 API 才能读到整个 display。
//
#import "PGScreen.h"
#import "PGCommon.h"
#import <dlfcn.h>
#import <CoreGraphics/CoreGraphics.h>

typedef CGImageRef (*PGCaptureScreenFn)(uint32_t display, CGImageRef *out, ...);

@implementation PGScreen {
    BOOL _probed;
    NSString *_info;
    void *_bsLib;
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
    _bsLib = dlopen("/System/Library/PrivateFrameworks/BackBoardServices.framework/BackBoardServices", RTLD_LAZY);
    dlopen("/System/Library/PrivateFrameworks/ScreenCaptureKit.framework/ScreenCaptureKit", RTLD_LAZY);
    dlopen("/System/Library/Frameworks/UIKit.framework/UIKit", RTLD_LAZY);
    _probed = YES;
    _info = [NSString stringWithFormat:@"sandbox=%@ backboard=%@ screenScale=%.2f",
        [self isSandboxed] ? @"YES" : @"NO", _bsLib ? @"OK" : @"--", [UIScreen mainScreen].scale];
    PGLog("%@", _info);
}

- (BOOL)isSandboxed {
    // 通过 sandbox_init 是否可用来粗判；no-sandbox 下 getenv 容器路径仍存在但沙盒profile不生效。
    const char *p = getenv("HOME");
    BOOL sandboxContainer = (p && strstr(p, "Containers/Data/Application") != NULL);
    // platform-application + no-sandbox 时该 HOME 仍可能是容器，故仅作信息展示，不作为能力判据。
    return sandboxContainer;
}

- (NSData *)capturePNG:(CGSize *)outPointSize {
    UIImage *img = nil;

    // 路径 1：CGDisplayCreateImage —— 无沙盒 + platform-application 下可读主 display
    CGDirectDisplayID display = CGMainDisplayID();
    CGImageRef cg = CGDisplayCreateImage(display);
    if (cg) {
        img = [UIImage imageWithCGImage:cg scale:1.0 orientation:UIImageOrientationUp];
        CGImageRelease(cg);
    }

    // 路径 2：UIGraphics 抓当前 keyWindow 的所有 window（自身窗口；跨App需路径1）
    if (!img) {
        CGRect bounds = [UIScreen mainScreen].bounds;
        UIGraphicsBeginImageContextWithOptions(bounds.size, NO, 0);
        NSArray *wins = [[UIApplication sharedApplication] windows];
        for (UIWindow *w in wins) {
            [w drawViewHierarchyInRect:bounds afterScreenUpdates:NO];
        }
        img = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
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
