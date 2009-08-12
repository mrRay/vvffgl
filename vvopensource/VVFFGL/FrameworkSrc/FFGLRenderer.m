//
//  FFGLRenderer.m
//  VVOpenSource
//
//  Created by Tom on 24/07/2009.
//

#import "FFGLRenderer.h"
#import "FFGLPlugin.h"
#import "FreeFrame.h"
#import "FFGLGPURenderer.h"
#import "FFGLCPURenderer.h"

@interface FFGLRenderer (Private)
- (id)_initWithPlugin:(FFGLPlugin *)plugin pixelFormat:(NSString *)format context:(CGLContextObj)context forBounds:(NSRect)bounds;
@end
@implementation FFGLRenderer

- (id)init
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (id)_initWithPlugin:(FFGLPlugin *)plugin pixelFormat:(NSString *)format context:(CGLContextObj)context forBounds:(NSRect)bounds
{
    if (self = [super init]) {
        if ([self class] == [FFGLRenderer class]) {
            [self release];
            if ([plugin mode] == FFGLPluginModeGPU) {
                return [[FFGLGPURenderer alloc] initWithPlugin:plugin context:context forBounds:bounds];
            } else if ([plugin mode] == FFGLPluginModeCPU) {
                return [[FFGLCPURenderer alloc] initWithPlugin:plugin pixelFormat:format forBounds:bounds];
            } else {
                return nil;
            }        
        } else {
            _plugin = [plugin retain];
            _pluginContext = CGLRetainContext(context);
            _bounds = bounds;
            _pixelFormat = [format retain];
        }
    }	
    return self;
}

- (id)initWithPlugin:(FFGLPlugin *)plugin pixelFormat:(NSString *)format forBounds:(NSRect)bounds
{
    return [self _initWithPlugin:plugin pixelFormat:format context:NULL forBounds:bounds];
}

- (id)initWithPlugin:(FFGLPlugin *)plugin context:(CGLContextObj)context forBounds:(NSRect)bounds
{
    return [self _initWithPlugin:plugin pixelFormat:nil context:context forBounds:bounds];
}

- (void)dealloc
{
    if(_pluginContext != nil) {
        CGLReleaseContext(_pluginContext);
    }
    [_plugin release];
    [_pixelFormat release];
    [super dealloc];
}

- (FFGLPlugin *)plugin
{
    return _plugin;
}

- (CGLContextObj)context
{
    return _pluginContext;
}

- (NSRect)bounds
{
    return _bounds;
}

- (NSString *)pixelFormat
{
    return _pixelFormat;
}

- (id)valueForParameterKey:(NSString *)key
{
    // TODO: or maybe subclasses override it.
}

- (void)setValue:(id)value forParameterKey:(NSString *)key
{
    // TODO: or maybe subclasses override it.
}

- (void)renderAtTime:(NSTimeInterval)time
{
    // Do nothing, subclasses override this. 
}
@end
