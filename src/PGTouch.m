//
//  PGTouch.m
//  IOHIDEvent 全局触摸派发 —— ABI 来自已验证的「老贝贝连点器」逆向工程。
//  与连点器差异：连点器注入到宿主进程用 _enqueueHIDEvent；本 App 是独立进程，
//  全局派发走 IOHIDEventSystemClientDispatchEvent，无需宿主 UIApplication。
//
#import "PGTouch.h"
#import "PGCommon.h"
#import <dlfcn.h>

#pragma mark - 私有函数指针类型（IOHIDEvent ABI）

typedef CFTypeRef PGHIDEventRef;
typedef CFTypeRef PGHIDClientRef;

// IOHIDEventRef IOHIDEventCreateDigitizerEvent(CFAllocatorRef, uint64_t ts,
//   uint32_t transducer, uint32_t index, uint32_t identity, uint32_t eventMask,
//   uint32_t buttonMask, double x,y,z,tipPressure,barrelPressure,twist,
//   uint8_t range, uint8_t touch);  —— 15 参
typedef PGHIDEventRef (*PGCreateDigitizerFn)(CFAllocatorRef, uint64_t,
    uint32_t, uint32_t, uint32_t, uint32_t, uint32_t,
    double, double, double, double, double, double, uint8_t, uint8_t);
// IOHIDEventRef IOHIDEventCreateDigitizerFingerEvent(CFAllocatorRef, uint64_t ts,
//   uint32_t index, uint32_t identity, uint32_t eventMask,
//   double x,y,z,tipPressure,twist, uint8_t range, uint8_t touch, uint32_t options); —— 13 参
typedef PGHIDEventRef (*PGCreateFingerFn)(CFAllocatorRef, uint64_t,
    uint32_t, uint32_t, uint32_t, double, double, double, double, double,
    uint8_t, uint8_t, uint32_t);
typedef void (*PGAppendFn)(PGHIDEventRef, PGHIDEventRef);
typedef void (*PGSetFloatFn)(PGHIDEventRef, uint32_t, float);
typedef void (*PGSetIntFn)(PGHIDEventRef, uint32_t, uint32_t);
typedef void (*PGSetSenderFn)(PGHIDEventRef, uint64_t);
typedef PGHIDClientRef (*PGClientCreateFn)(CFAllocatorRef);
typedef void (*PGDispatchFn)(PGHIDClientRef, PGHIDEventRef);
// void BKSHIDEventSetDigitizerInfo(IOHIDEventRef, uint32_t contextID,
//   uint8_t systemGestureisTouching, uint8_t isSystemGestureStateChangeEvent,
//   CFStringRef displayUUID, CFTimeInterval initialTouchTimestamp, float maxForce); —— 7 参
typedef void (*PGBKSDigitizerInfoFn)(PGHIDEventRef, uint32_t, uint8_t, uint8_t, void *, double, float);

#define kPGFieldType3         0xb000d
#define kPGFieldType4         0xb000e
#define kPGFieldType5         0xb000f
#define kPGFieldMajorRadius   0xb0014
#define kPGFieldMinorRadius   0xb0015
#define kPGFieldDisplayInt    0xb0019
#define kPGTransducerHand     0x23
#define kPGEventMaskAll       0x7
#define kPGSenderID           0xdefacedbeeffece5ULL

#pragma mark - SpringBoard / 前台 contextId 私有声明

@interface SBApplication : NSObject
- (id)_contextId;
@end
@interface UIApplication (PGPrivate)
- (NSInteger)_frontmostAppOrientation;
@end

@implementation PGTouch {
    PGCreateDigitizerFn _createDigitizer;
    PGCreateFingerFn    _createFinger;
    PGAppendFn          _append;
    PGSetFloatFn        _setFloat;
    PGSetIntFn          _setInt;
    PGSetSenderFn       _setSender;
    PGClientCreateFn    _clientCreate;
    PGDispatchFn        _dispatch;
    PGBKSDigitizerInfoFn _bksInfo;
    PGHIDClientRef      _client;
    uint32_t            _targetContext;
    BOOL                _resolved;
    NSUInteger          _slot;
}

+ (instancetype)shared {
    static PGTouch *s = nil; static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [[PGTouch alloc] init]; });
    return s;
}

- (instancetype)init {
    if (self = [super init]) {
        _slot = 1;
        [self resolveSymbols];
    }
    return self;
}

- (void)resolveSymbols {
    void *io = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_LAZY);
    void *bks = dlopen("/System/Library/PrivateFrameworks/BackBoardServices.framework/BackBoardServices", RTLD_LAZY);
    dlopen("/System/Library/PrivateFrameworks/SpringBoard.framework/SpringBoard", RTLD_LAZY);

    _createDigitizer = (PGCreateDigitizerFn)dlsym(RTLD_DEFAULT, "IOHIDEventCreateDigitizerEvent");
    _createFinger    = (PGCreateFingerFn)dlsym(RTLD_DEFAULT, "IOHIDEventCreateDigitizerFingerEvent");
    _append          = (PGAppendFn)dlsym(RTLD_DEFAULT, "IOHIDEventAppendEvent");
    _setFloat        = (PGSetFloatFn)dlsym(RTLD_DEFAULT, "IOHIDEventSetFloatValue");
    _setInt          = (PGSetIntFn)dlsym(RTLD_DEFAULT, "IOHIDEventSetIntegerValue");
    _setSender       = (PGSetSenderFn)dlsym(RTLD_DEFAULT, "IOHIDEventSetSenderID");
    _clientCreate    = (PGClientCreateFn)dlsym(RTLD_DEFAULT, "IOHIDEventSystemClientCreate");
    _dispatch        = (PGDispatchFn)dlsym(RTLD_DEFAULT, "IOHIDEventSystemClientDispatchEvent");
    if (!_dispatch && bks)     _dispatch     = (PGDispatchFn)dlsym(bks, "IOHIDEventSystemClientDispatchEvent");
    if (!_clientCreate && bks) _clientCreate = (PGClientCreateFn)dlsym(bks, "IOHIDEventSystemClientCreate");
    if (bks) _bksInfo = (PGBKSDigitizerInfoFn)dlsym(bks, "BKSHIDEventSetDigitizerInfo");
    if (io) PGLog("IOKit dlopen=%p bks=%p", io, bks);

    _resolved = (_createDigitizer && _createFinger && _append &&
                 _setFloat && _setInt && _clientCreate && _dispatch);
    if (_resolved) _client = _clientCreate(kCFAllocatorDefault);
    PGLog("%@", [self diagnosticInfo]);
}

- (BOOL)channelsReady { return _resolved && _client != NULL; }

- (NSString *)diagnosticInfo {
    return [NSString stringWithFormat:@"HID: digitizer=%@ finger=%@ append=%@ dispatch=%@ bks=%@ client=%@ context=%u",
        _createDigitizer ? @"OK" : @"--", _createFinger ? @"OK" : @"--",
        _append ? @"OK" : @"--", _dispatch ? @"OK" : @"--",
        _bksInfo ? @"OK" : @"--", _client ? @"OK" : @"--", _targetContext];
}

- (void)refreshFrontmostContext {
    // 通过 SpringBoard 拿当前前台 App 的 contextId；失败则保留上次值。
    Class SBA = NSClassFromString(@"SBApplication");
    Class SBW = NSClassFromString(@"SBWorkspace");
    id ws = [SBW performSelector:@selector(sharedApplication)];
    id app = nil;
    if (ws && [ws respondsToSelector:@selector(_frontmostApplication)]) {
        app = [ws performSelector:@selector(_frontmostApplication)];
    }
    if (!app) {
        Class SBM = NSClassFromString(@"SBSceneManager");
        id mgr = [SBM performSelector:@selector(sharedInstance)];
        if (mgr && [mgr respondsToSelector:@selector(foregroundApplicationScene)]) {
            id scene = [mgr performSelector:@selector(foregroundApplicationScene)];
            if ([scene respondsToSelector:@selector(app)]) app = [scene performSelector:@selector(app)];
        }
    }
    if (app && [app respondsToSelector:@selector(_contextId)]) {
        uint32_t ctx = (uint32_t)[app performSelector:@selector(_contextId)];
        if (ctx) _targetContext = ctx;
    }
    (void)SBA;
}

// 构造 digitizer parent + finger 子事件
- (PGHIDEventRef)makeEventAt:(CGPoint)p phase:(int)phase {
    if (!_resolved) return NULL;
    uint64_t ts = mach_absolute_time();
    PGHIDEventRef parent = _createDigitizer(kCFAllocatorDefault, ts,
        kPGTransducerHand, 0, 0, kPGEventMaskAll, 0,
        p.x, p.y, 0, 0, 0, 0, 0, phase == 1);
    if (!parent) return NULL;
    _setInt(parent, kPGFieldType3, 0x23);
    _setInt(parent, kPGFieldType4, 1);
    _setInt(parent, kPGFieldType5, 1);
    _setFloat(parent, kPGFieldMajorRadius, 0.04);
    _setFloat(parent, kPGFieldMinorRadius, 0.04);
    _setInt(parent, kPGFieldDisplayInt, 1);
    _setSender(parent, kPGSenderID);

    // finger: index/identity = slot+1, mask=7, x/y, tip=0, twist=0, range/touch
    uint8_t touching = (phase == 1) ? 1 : 0;
    PGHIDEventRef finger = _createFinger(kCFAllocatorDefault, ts,
        (uint32_t)(_slot + 1), (uint32_t)(_slot + 1), 7,
        p.x, p.y, 0, (phase == 1) ? 1.0 : 0.0, 0,
        touching, touching, 0);
    if (finger) {
        _setSender(finger, kPGSenderID);
        _append(parent, finger);
        CFRelease(finger);
    }
    return parent;
}

- (void)dispatchEvent:(PGHIDEventRef)event {
    if (!event) return;
    if (_bksInfo && _targetContext) {
        _bksInfo(event, _targetContext, 0, 0, NULL, 0, 0);
    }
    if (_dispatch && _client) _dispatch(_client, event);
    CFRelease(event);
}

- (void)tapAt:(CGPoint)point {
    [self refreshFrontmostContext];
    PGHIDEventRef down = [self makeEventAt:point phase:1];
    [self dispatchEvent:down];
    usleep(60000); // 60ms
    PGHIDEventRef up = [self makeEventAt:point phase:0];
    [self dispatchEvent:up];
    PGLog(@"tap(%.0f,%.0f) ctx=%u", point.x, point.y, _targetContext);
}

- (void)swipeFrom:(CGPoint)from to:(CGPoint)to durationMs:(NSTimeInterval)ms {
    [self refreshFrontmostContext];
    NSInteger steps = MAX(6, (NSInteger)(ms / 16));
    PGHIDEventRef down = [self makeEventAt:from phase:1];
    [self dispatchEvent:down];
    for (NSInteger i = 1; i <= steps; i++) {
        CGFloat t = (CGFloat)i / steps;
        CGPoint p = CGPointMake(from.x + (to.x - from.x) * t, from.y + (to.y - from.y) * t);
        PGHIDEventRef mv = [self makeEventAt:p phase:1];
        [self dispatchEvent:mv];
        usleep(16000);
    }
    PGHIDEventRef up = [self makeEventAt:to phase:0];
    [self dispatchEvent:up];
    PGLog(@"swipe(%.0f,%.0f→%.0f,%.0f) ctx=%u", from.x, from.y, to.x, to.y, _targetContext);
}

- (void)home {
    // 通过 SpringBoard 的 home 按钮按下；失败则用系统 URL scheme 兜底
    Class SBS = NSClassFromString(@"SBSpringBoard");
    id sb = [SBS performSelector:@selector(sharedApplication)];
    if (sb && [sb respondsToSelector:@selector(_simulateHomeButtonPress)]) {
        [sb performSelector:@selector(_simulateHomeButtonPress)];
    } else {
        [[UIApplication sharedApplication] performSelector:@selector(suspend)];
    }
    PGLog(@"home");
}

- (void)cancelAll {
    // 抬起所有手指：发送一次全部 release
    PGHIDEventRef up = [self makeEventAt:CGPointZero phase:0];
    [self dispatchEvent:up];
}
@end
