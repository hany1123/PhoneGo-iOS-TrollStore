//
//  PGCommon.m
//
#import "PGCommon.h"

@implementation PGAction
+ (instancetype)base { return [[self alloc] init]; }
+ (instancetype)tapAt:(CGPoint)p thought:(NSString *)t {
    PGAction *a = [self base]; a.type = PGActionTypeTap; a.point = p; a.thought = t; return a;
}
+ (instancetype)swipeFrom:(CGPoint)f to:(CGPoint)t thought:(NSString *)th {
    PGAction *a = [self base]; a.type = PGActionTypeSwipe; a.from = f; a.to = t; a.thought = th; return a;
}
+ (instancetype)inputText:(NSString *)s thought:(NSString *)t {
    PGAction *a = [self base]; a.type = PGActionTypeInput; a.text = s; a.thought = t; return a;
}
+ (instancetype)waitMs:(NSTimeInterval)ms thought:(NSString *)t {
    PGAction *a = [self base]; a.type = PGActionTypeWait; a.waitMs = ms; a.thought = t; return a;
}
+ (instancetype)launch:(NSString *)bundleId thought:(NSString *)t {
    PGAction *a = [self base]; a.type = PGActionTypeLaunch; a.text = bundleId; a.thought = t; return a;
}
+ (instancetype)doneWithThought:(NSString *)t {
    PGAction *a = [self base]; a.type = PGActionTypeDone; a.thought = t; return a;
}
+ (instancetype)failWithReason:(NSString *)r {
    PGAction *a = [self base]; a.type = PGActionTypeFail; a.text = r; return a;
}
+ (instancetype)homeWithThought:(NSString *)t {
    PGAction *a = [self base]; a.type = PGActionTypeHome; a.thought = t; return a;
}
- (NSString *)description {
    switch (self.type) {
        case PGActionTypeTap:    return [NSString stringWithFormat:@"tap(%.0f,%.0f) %@", self.point.x, self.point.y, self.thought ?: @""];
        case PGActionTypeSwipe:  return [NSString stringWithFormat:@"swipe(%.0f,%.0f→%.0f,%.0f) %@", self.from.x, self.from.y, self.to.x, self.to.y, self.thought ?: @""];
        case PGActionTypeInput:  return [NSString stringWithFormat:@"input(%@) %@", self.text ?: @"", self.thought ?: @""];
        case PGActionTypeWait:   return [NSString stringWithFormat:@"wait(%.0fms) %@", self.waitMs, self.thought ?: @""];
        case PGActionTypeLaunch: return [NSString stringWithFormat:@"launch(%@) %@", self.text ?: @"", self.thought ?: @""];
        case PGActionTypeDone:   return [NSString stringWithFormat:@"done: %@", self.thought ?: @""];
        case PGActionTypeFail:   return [NSString stringWithFormat:@"fail: %@", self.text ?: @""];
        case PGActionTypeHome:   return [NSString stringWithFormat:@"home %@", self.thought ?: @""];
        default: return @"unknown";
    }
}
@end
