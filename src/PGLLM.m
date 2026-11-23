//
//  PGLLM.m
//  OpenAI 兼容 /chat/completions。视觉消息用 image_url base64。
//  强约束模型输出单个 JSON 动作对象，解析时做多层容错。
//
#import "PGLLM.h"
#import "PGConfig.h"

@implementation PGLLM
+ (instancetype)shared {
    static PGLLM *s = nil; static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [[PGLLM alloc] init]; });
    return s;
}

- (NSString *)systemPromptWithSize:(CGSize)size {
    return [NSString stringWithFormat:
@"You are PhoneGo, a phone-use AI agent controlling an iPhone by tapping and swiping. "
@"You will receive a screenshot (%.0fx%.0f points) and a user task. "
@"Respond with ONLY one JSON object describing the single next action, no markdown, no explanation outside JSON. "
@"Coordinates are in points with origin at top-left. Allowed actions:\n"
@"- {\"action\":\"tap\",\"x\":N,\"y\":N,\"thought\":\"...\"}\n"
@"- {\"action\":\"swipe\",\"x1\":N,\"y1\":N,\"x2\":N,\"y2\":N,\"thought\":\"...\"}\n"
@"- {\"action\":\"input\",\"text\":\"...\",\"thought\":\"...\"}\n"
@"- {\"action\":\"home\",\"thought\":\"...\"}\n"
@"- {\"action\":\"wait\",\"ms\":N,\"thought\":\"...\"}\n"
@"- {\"action\":\"done\",\"thought\":\"final answer to user\"}\n"
@"- {\"action\":\"fail\",\"reason\":\"why it cannot be done\"}\n"
@"Rules: prefer tap/swipe to navigate. Use input only when a text field is focused. "
@"When the task is complete, return done with a concise report. "
@"Return done or fail within a reasonable number of steps.", size.width, size.height];
}

- (NSURLRequest *)requestForMessages:(NSArray *)messages vision:(BOOL)vision {
    PGConfig *c = [PGConfig shared];
    NSString *url = [c.baseURL stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"/"]];
    url = [url stringByAppendingString:@"/chat/completions"];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]
        cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:60];
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [req setValue:[NSString stringWithFormat:@"Bearer %@", c.apiKey] forHTTPHeaderField:@"Authorization"];
    NSDictionary *body = @{
        @"model": vision ? c.visionModel : c.model,
        @"messages": messages,
        @"max_tokens": @(c.maxTokens),
        @"temperature": @(0.2)
    };
    NSError *e = nil;
    NSData *json = [NSJSONSerialization dataWithJSONObject:body options:0 error:&e];
    if (e) PGLog("JSON 序列化失败 %@", e);
    [req setHTTPMethod:@"POST"];
    [req setHTTPBody:json];
    return req;
}

- (NSString *)extractContent:(NSData *)data error:(NSError **)err {
    NSError *e = nil;
    NSDictionary *obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:&e];
    if (e || !obj) { if (err) *err = e; return nil; }
    // OpenAI / most compatible: choices[0].message.content
    NSArray *choices = obj[@"choices"];
    if (choices.count) {
        NSDictionary *msg = choices[0][@"message"];
        id content = msg[@"content"];
        if ([content isKindOfClass:[NSString class]]) return content;
        // 部分视觉模型返回数组 [{type:text,text:...}]
        if ([content isKindOfClass:[NSArray class]]) {
            for (NSDictionary *part in content) {
                if ([part isKindOfClass:[NSDictionary class]] && [part[@"type"] isEqualToString:@"text"])
                    return part[@"text"];
            }
        }
        // reasoning 模型可能把内容放 reasoning_content
        if (msg[@"reasoning_content"]) return msg[@"reasoning_content"];
    }
    if (obj[@"error"]) {
        if (err) *err = [NSError errorWithDomain:@"PGLLM" code:2 userInfo:@{NSLocalizedDescriptionKey: [obj[@"error"] description]}];
    }
    return nil;
}

- (PGAction *)parseActionFromText:(NSString *)text {
    if (!text) return [PGAction failWithReason:@"模型返回空内容"];
    // 去掉可能的 ```json ... ``` 包裹
    NSString *clean = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([clean hasPrefix:@"```"]) {
        NSRange nl = [clean rangeOfString:@"\n"];
        if (nl.location != NSNotFound) clean = [clean substringFromIndex:nl.location + 1];
        clean = [clean stringByReplacingOccurrencesOfString:@"```" withString:@""];
        clean = [clean stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }
    // 截取第一个 { 到最后一个 }
    NSRange lb = [clean rangeOfString:@"{"];
    NSRange rb = [clean rangeOfString:@"}" options:NSBackwardsSearch];
    if (lb.location != NSNotFound && rb.location != NSNotFound && rb.location > lb.location) {
        clean = [clean substringWithRange:NSMakeRange(lb.location, rb.location - lb.location + 1)];
    }
    NSError *e = nil;
    NSDictionary *d = [NSJSONSerialization JSONObjectWithData:[clean dataUsingEncoding:NSUTF8StringEncoding] options:0 error:&e];
    if (!d || ![d isKindOfClass:[NSDictionary class]]) {
        return [PGAction failWithReason:[NSString stringWithFormat:@"无法解析动作: %@", [text substringToIndex:MIN(120, text.length)]]];
    }
    NSString *act = [[d[@"action"] description] lowercaseString];
    NSString *thought = d[@"thought"] ?: @"";
    if ([act isEqualToString:@"tap"])
        return [PGAction tapAt:CGPointMake([d[@"x"] doubleValue], [d[@"y"] doubleValue]) thought:thought];
    if ([act isEqualToString:@"swipe"])
        return [PGAction swipeFrom:CGPointMake([d[@"x1"] doubleValue], [d[@"y1"] doubleValue])
                                to:CGPointMake([d[@"x2"] doubleValue], [d[@"y2"] doubleValue]) thought:thought];
    if ([act isEqualToString:@"input"] || [act isEqualToString:@"type"])
        return [PGAction inputText:d[@"text"] ?: @"" thought:thought];
    if ([act isEqualToString:@"home"])
        return [PGAction homeWithThought:thought];
    if ([act isEqualToString:@"wait"])
        return [PGAction waitMs:[d[@"ms"] doubleValue] thought:thought];
    if ([act isEqualToString:@"done"])
        return [PGAction doneWithThought:thought];
    if ([act isEqualToString:@"fail"])
        return [PGAction failWithReason:d[@"reason"] ?: thought];
    return [PGAction failWithReason:[NSString stringWithFormat:@"未知动作: %@", act]];
}

- (void)decideWithTask:(NSString *)task screenshot:(NSData *)png pointSize:(CGSize)size
             stepIndex:(NSInteger)step history:(NSArray<NSString *> *)history
            completion:(void (^)(PGAction *, NSString *, NSError *))completion {
    NSString *sys = [self systemPromptWithSize:size];
    NSString *userText = [NSString stringWithFormat:@"User task: %@\nCurrent step: %ld\nRecent actions:\n%@",
        task, (long)step, history.count ? [history componentsJoinedByString:@"\n"] : @"(none)"];

    // options=0 表示无换行；NSDataBase64Encoding64LineLengthLineBreaks 在新 SDK 已移除
    NSString *b64 = [png base64EncodedStringWithOptions:0];
    NSString *dataURL = [NSString stringWithFormat:@"data:image/png;base64,%@", b64];

    NSArray *messages = @[
        @{@"role": @"system", @"content": sys},
        @{@"role": @"user", @"content": @[
            @{@"type": @"text", @"text": userText},
            @{@"type": @"image_url", @"image_url": @{@"url": dataURL, @"detail": @"high"}}
        ]}
    ];
    NSURLRequest *req = [self requestForMessages:messages vision:YES];
    NSURLSession *sess = [NSURLSession sharedSession];
    [[sess dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *resp, NSError *error) {
        if (error) { dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, nil, error); }); return; }
        NSError *perr = nil;
        NSString *content = [self extractContent:data error:&perr];
        if (perr || !content) {
            NSString *dbg = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"";
            PGLog("模型返回错误: %@ body=%@", perr, [dbg substringToIndex:MIN(300, dbg.length)]);
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, dbg, perr ?: [NSError errorWithDomain:@"PGLLM" code:3 userInfo:@{NSLocalizedDescriptionKey:@"模型未返回内容"}]);
            });
            return;
        }
        PGAction *a = [self parseActionFromText:content];
        dispatch_async(dispatch_get_main_queue(), ^{ completion(a, content, nil); });
    }] resume];
}

- (void)summarize:(NSString *)prompt completion:(void (^)(NSString *, NSError *))completion {
    NSArray *messages = @[@{@"role": @"user", @"content": prompt}];
    NSURLRequest *req = [self requestForMessages:messages vision:NO];
    [[[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *resp, NSError *error) {
        if (error) { dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, error); }); return; }
        NSError *e = nil;
        NSString *c = [self extractContent:data error:&e];
        dispatch_async(dispatch_get_main_queue(), ^{ completion(c, e); });
    }] resume];
}
@end
