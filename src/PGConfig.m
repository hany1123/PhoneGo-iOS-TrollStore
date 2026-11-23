//
//  PGConfig.m
//
#import "PGConfig.h"
#import "PGCommon.h"

@implementation PGConfig
+ (instancetype)shared {
    static PGConfig *s = nil; static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [[PGConfig alloc] init]; });
    return s;
}
- (instancetype)init {
    if (self = [super init]) {
        NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
        _baseURL    = [[d stringForKey:kPGKeyBaseURL] copy] ?: [kPGDefaultBaseURL copy];
        _apiKey     = [[d stringForKey:kPGKeyAPIKey] copy] ?: @"";
        _model      = [[d stringForKey:kPGKeyModel] copy] ?: [kPGDefaultModel copy];
        _visionModel= [[d stringForKey:kPGKeyVisionModel] copy] ?: [kPGDefaultVision copy];
        _stepBudget = [d integerForKey:kPGKeyStepBudget] ?: 20;
        _maxTokens  = [d integerForKey:kPGKeyMaxTokens] ?: 1024;
    }
    return self;
}
- (void)save {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    [d setObject:_baseURL ?: @"" forKey:kPGKeyBaseURL];
    [d setObject:_apiKey ?: @"" forKey:kPGKeyAPIKey];
    [d setObject:_model ?: @"" forKey:kPGKeyModel];
    [d setObject:_visionModel ?: @"" forKey:kPGKeyVisionModel];
    [d setInteger:_stepBudget forKey:kPGKeyStepBudget];
    [d setInteger:_maxTokens forKey:kPGKeyMaxTokens];
    [d synchronize];
}
- (BOOL)isConfigured {
    return self.apiKey.length > 0 && self.baseURL.length > 0;
}
@end
