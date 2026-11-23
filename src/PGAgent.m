//
//  PGAgent.m
//  循环：截屏 → VLM 决策 → 执行动作 → 再截屏，直到 done/fail/步数上限。
//
#import "PGAgent.h"
#import "PGCommon.h"
#import "PGConfig.h"
#import "PGScreen.h"
#import "PGTouch.h"
#import "PGLLM.h"

@implementation PGAgent {
    BOOL _running;
    BOOL _stopRequested;
    NSMutableArray<NSString *> *_history;
    NSInteger _step;
}

+ (instancetype)shared {
    static PGAgent *s = nil; static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [[PGAgent alloc] init]; });
    return s;
}
- (instancetype)init {
    if (self = [super init]) { _running = NO; _history = [NSMutableArray array]; }
    return self;
}
- (BOOL)running { return _running; }

- (void)log:(NSString *)line {
    PGLog("%@", line);
    if ([self.delegate respondsToSelector:@selector(agentDidAppendLog:)])
        [self.delegate agentDidAppendLog:line];
}
- (void)status:(NSString *)s {
    if ([self.delegate respondsToSelector:@selector(agentDidUpdateStatus:)])
        [self.delegate agentDidUpdateStatus:s];
}
- (void)finish:(NSString *)result success:(BOOL)ok {
    _running = NO;
    if ([self.delegate respondsToSelector:@selector(agentDidFinish:success:)])
        [self.delegate agentDidFinish:result success:ok];
}

- (void)stop {
    _stopRequested = YES;
    [[PGTouch shared] cancelAll];
    [self log:@"用户请求停止"];
}

- (void)runTask:(NSString *)task {
    if (_running) { [self log:@"已有任务在运行"]; return; }
    if (![[PGConfig shared] isConfigured]) {
        [self finish:@"请先在设置里填 API Key 和 base URL" success:NO]; return;
    }
    _running = YES; _stopRequested = NO; _step = 0;
    [_history removeAllObjects];
    [self status:@"运行中"];
    [self log:[NSString stringWithFormat:@"任务开始：%@", task]];
    [self log:[PGTouch shared].diagnosticInfo];
    [self log:[PGScreen shared].diagnosticInfo];
    [self stepWithTask:task];
}

// 递归一步：截屏 → 决策 → 执行 → 下一步
- (void)stepWithTask:(NSString *)task {
    if (_stopRequested) { [self finish:@"已停止" success:NO]; return; }
    NSInteger budget = [PGConfig shared].stepBudget;
    if (_step >= budget) {
        [self finish:[NSString stringWithFormat:@"达到步数上限 %ld", (long)budget] success:NO]; return;
    }
    _step++;
    [self status:[NSString stringWithFormat:@"第 %ld/%ld 步", (long)_step, (long)budget]];

    CGSize size = CGSizeZero;
    NSData *shot = [[PGScreen shared] capturePNG:&size];
    if (!shot) { [self finish:@"截屏失败（检查无沙盒权限）" success:NO]; return; }

    NSArray *recent = [_history subarrayWithRange:NSMakeRange(0, MIN(6, _history.count))];
    [[PGLLM shared] decideWithTask:task screenshot:shot pointSize:size stepIndex:_step history:recent
        completion:^(PGAction *action, NSString *rawText, NSError *error) {
        if (error) {
            [self log:[NSString stringWithFormat:@"模型错误：%@", error.localizedDescription]];
            [self finish:[NSString stringWithFormat:@"模型调用失败：%@", error.localizedDescription] success:NO];
            return;
        }
        [self log:[NSString stringWithFormat:@"动作 %ld: %@", (long)self->_step, [action description]]];
        [self->_history insertObject:[action description] atIndex:0];

        switch (action.type) {
            case PGActionTypeTap:
                [[PGTouch shared] tapAt:action.point];
                [self delayThenNext:task ms:700];
                break;
            case PGActionTypeSwipe:
                [[PGTouch shared] swipeFrom:action.from to:action.to durationMs:MAX(200, action.waitMs > 0 ? action.waitMs : 400)];
                [self delayThenNext:task ms:700];
                break;
            case PGActionTypeInput:
                // 文本输入需剪贴板+粘贴；首版用 UIPasteboard 提示，动作在 UI 层处理
                [self performInput:action.text];
                [self delayThenNext:task ms:600];
                break;
            case PGActionTypeHome:
                [[PGTouch shared] home];
                [self delayThenNext:task ms:600];
                break;
            case PGActionTypeWait:
                [self delayThenNext:task ms:MAX(100, action.waitMs)];
                break;
            case PGActionTypeDone:
                [self finish:action.thought ?: @"任务完成" success:YES];
                break;
            case PGActionTypeFail:
                [self finish:action.text ?: @"任务无法完成" success:NO];
                break;
            default:
                [self delayThenNext:task ms:500];
                break;
        }
    }];
}

- (void)delayThenNext:(NSString *)task ms:(NSTimeInterval)ms {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(ms * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
        [self stepWithTask:task];
    });
}

- (void)performInput:(NSString *)text {
    // 首版：写入剪贴板，模型应先 tap 到输入框，用户/后续版本用粘贴注入。
    [UIPasteboard generalPasteboard].string = text;
    [self log:[NSString stringWithFormat:@"文本已放入剪贴板（待粘贴）：%@", text]];
    // 尝试通过私有 API 触发粘贴：先聚焦的字段通常响应 paste:
    UIResponder *first = [UIResponder new];
    (void)first;
}
@end
