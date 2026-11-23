//
//  PGCommon.h — PhoneGo iOS 公共定义
//
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#define PGLog(fmt, ...) NSLog(@"[PhoneGo] " fmt, ##__VA_ARGS__)

// 配置存储键
static NSString * const kPGKeyBaseURL   = @"PG_baseURL";
static NSString * const kPGKeyAPIKey    = @"PG_apiKey";
static NSString * const kPGKeyModel     = @"PG_model";
static NSString * const kPGKeyVisionModel = @"PG_visionModel";
static NSString * const kPGKeyStepBudget = @"PG_stepBudget";
static NSString * const kPGKeyMaxTokens = @"PG_maxTokens";

static NSString * const kPGDefaultBaseURL = @"https://api.openai.com/v1";
static NSString * const kPGDefaultModel   = @"gpt-4o-mini";
static NSString * const kPGDefaultVision  = @"gpt-4o";

// Agent 动作
typedef NS_ENUM(NSInteger, PGActionType) {
    PGActionTypeTap = 0,
    PGActionTypeSwipe,
    PGActionTypeInput,
    PGActionTypeHome,
    PGActionTypeWait,
    PGActionTypeLaunch,
    PGActionTypeDone,
    PGActionTypeFail,
    PGActionTypeUnknown
};

@interface PGAction : NSObject
@property (nonatomic, assign) PGActionType type;
@property (nonatomic, assign) CGPoint point;      // tap
@property (nonatomic, assign) CGPoint from;       // swipe
@property (nonatomic, assign) CGPoint to;         // swipe
@property (nonatomic, copy)   NSString *text;     // input / launch(bundle id) / fail reason
@property (nonatomic, assign) NSTimeInterval waitMs; // wait
@property (nonatomic, copy)   NSString *thought;  // 模型给出的理由
+ (instancetype)tapAt:(CGPoint)p thought:(NSString *)t;
+ (instancetype)swipeFrom:(CGPoint)f to:(CGPoint)t thought:(NSString *)th;
+ (instancetype)inputText:(NSString *)s thought:(NSString *)t;
+ (instancetype)waitMs:(NSTimeInterval)ms thought:(NSString *)t;
+ (instancetype)launch:(NSString *)bundleId thought:(NSString *)t;
+ (instancetype)doneWithThought:(NSString *)t;
+ (instancetype)failWithReason:(NSString *)r;
+ (instancetype)homeWithThought:(NSString *)t;
@end
