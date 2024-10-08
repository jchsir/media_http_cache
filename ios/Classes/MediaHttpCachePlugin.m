#import "MediaHttpCachePlugin.h"
#import <KTVHTTPCache/KTVHTTPCache.h>

@interface MediaHttpCachePlugin()

@property (nonatomic, strong) FlutterMethodChannel* channel;

@property (nonatomic, strong) NSMutableDictionary *dataLoaderDic;

@end


@implementation MediaHttpCachePlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    FlutterMethodChannel* channel = [FlutterMethodChannel
                                     methodChannelWithName:@"media_http_cache"
                                     binaryMessenger:[registrar messenger]];
    MediaHttpCachePlugin* instance = [[MediaHttpCachePlugin alloc] initWithChannel:channel];
    [registrar addMethodCallDelegate:instance channel:channel];
}

- (instancetype)initWithChannel:(FlutterMethodChannel *)channel{
    if (self = [super init]) {
        _channel = channel;
    }
    return self;
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    if ([@"getPlatformVersion" isEqualToString:call.method]) {
        result([@"iOS " stringByAppendingString:[[UIDevice currentDevice] systemVersion]]);
    } else if ([@"startProxy" isEqualToString:call.method]){
        UInt16 port = [call.arguments[0] unsignedShortValue];
        int64_t maxCacheLength = [call.arguments[1] longLongValue];
        BOOL success = [self proxyStartWithPort:port maxCacheLength:maxCacheLength];
        result(@(success));
    }else if ([@"stopProxy" isEqualToString:call.method]){
        [KTVHTTPCache proxyStop];
        result(@(YES));
    }else if ([@"proxyIsRunning" isEqualToString:call.method]){
        result(@([KTVHTTPCache proxyIsRunning]));
    }else if ([@"getProxyURLWithOriginalURL" isEqualToString:call.method]){
        NSString *url = call.arguments[0];
        BOOL bindToLocalhost = [call.arguments[1] boolValue];
        NSString *proxyUrl = [KTVHTTPCache proxyURLWithOriginalURL:[NSURL URLWithString:url] bindToLocalhost:bindToLocalhost].absoluteString;
        result(proxyUrl);
    }else if ([@"preloadMedia" isEqualToString:call.method]){
        NSString *key = call.arguments[0];
        if (![self.dataLoaderDic objectForKey:key]) {
            NSDictionary *headers = @{};
            NSURL *url = [NSURL URLWithString:call.arguments[1]];
            KTVHCDataRequest *request = [[KTVHCDataRequest alloc] initWithURL:url headers:headers];
            KTVHCDataLoader *loader = [KTVHTTPCache cacheLoaderWithRequest:request];
            [self.dataLoaderDic setObject:loader forKey:key];
            [loader prepare];
        }
        result(@(YES));
    }else if ([@"closePreloadMedia" isEqualToString:call.method]){
        NSString *key = call.arguments;
        [self.dataLoaderDic removeObjectForKey:key];
        result(@(YES));
    }else if ([@"closeAllPreloadMedia" isEqualToString:call.method]){
        [self.dataLoaderDic removeAllObjects];
        result(@(YES));
    }else if ([@"deleteAllCaches" isEqualToString:call.method]){
        [KTVHTTPCache cacheDeleteAllCaches];
        result(@(YES));
    }else {
        result(FlutterMethodNotImplemented);
    }
}


- (BOOL)proxyStartWithPort:(UInt16)port maxCacheLength:(int64_t)maxCacheLength{
    NSError *error = nil;
    BOOL success = [KTVHTTPCache proxyStart:&error];
    [KTVHTTPCache encodeSetURLConverter:^NSURL *(NSURL *URL) {
        NSLog(@"URL Filter reviced URL : %@", URL);
        return URL;
    }];
    [KTVHTTPCache downloadSetUnacceptableContentTypeDisposer:^BOOL(NSURL *URL, NSString *contentType) {
        NSLog(@"Unsupport Content-Type Filter reviced URL : %@, %@", URL, contentType);
        return NO;
    }];
    if (success) {
        [KTVHTTPCache proxySetPort:port];
        [KTVHTTPCache cacheSetMaxCacheLength:maxCacheLength];
    }
    return success;
}

- (NSMutableDictionary *)dataLoaderDic{
    if (!_dataLoaderDic) {
        _dataLoaderDic = [[NSMutableDictionary alloc] init];
    }
    return _dataLoaderDic;
}

@end
