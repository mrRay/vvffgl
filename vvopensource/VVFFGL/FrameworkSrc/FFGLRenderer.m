//
//  FFGLRenderer.m
//  VVOpenSource
//
//  Created by Tom on 24/07/2009.
//

#import "FFGLRenderer.h"
#import "FFGLRendererSubclassing.h"
#import "FFGLPlugin.h"
#import "FFGLPluginInstances.h"
#import "FreeFrame.h"
#import "FFGLGPURenderer.h"
#import "FFGLCPURenderer.h"

@interface FFGLRendererParametersBindable : NSObject
{
    FFGLRenderer *_renderer;
}
- (id)initWithRenderer:(FFGLRenderer *)renderer;
@end

@interface FFGLRenderer (Private)
- (id)_initWithPlugin:(FFGLPlugin *)plugin pixelFormat:(NSString *)format context:(CGLContextObj)context forBounds:(NSRect)bounds;
- (void)_performSetValue:(id)value forParameterKey:(NSString *)key;
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
            _instance = [plugin _newInstanceWithBounds:bounds pixelFormat:format];
            if (_instance == 0) {
                [self release];
                return nil;
            }
            _plugin = [plugin retain];
            if (_pluginContext != NULL) {
                _pluginContext = CGLRetainContext(context);                
            }
            _bounds = bounds;
            _pixelFormat = [format retain];
            _imageInputs = [[NSMutableDictionary alloc] initWithCapacity:4];
            
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
    [_params release];
    if(_pluginContext != nil) {
        CGLReleaseContext(_pluginContext);
    }
    [_plugin release];
    [_pixelFormat release];
    [_imageInputs release];
    if (_instance != 0) {
        [[self plugin] _disposeInstance:_instance];
    }
    [super dealloc];
}

- (NSUInteger)_instance
{
    return _instance;
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
    if ([[[_plugin attributesForParameterWithKey:key] objectForKey:FFGLParameterAttributeTypeKey] isEqualToString:FFGLParameterTypeImage]) {
        return [_imageInputs objectForKey:key];
    } else {
        return [_plugin _valueForNonImageParameterKey:key ofInstance:_instance];
    }
}

- (void)setValue:(id)value forParameterKey:(NSString *)key
{
    [_params willChangeValueForKey:key];
    [self _performSetValue:value forParameterKey:key];
    [_params didChangeValueForKey:key];
}

- (void)_performSetValue:(id)value forParameterKey:(NSString *)key
{
    NSDictionary *attributes = [_plugin attributesForParameterWithKey:key];
    if ([[attributes objectForKey:FFGLParameterAttributeTypeKey] isEqualToString:FFGLParameterTypeImage]) {
        [self _implementationSetImage:value forInputAtIndex:[[attributes objectForKey:FFGLParameterAttributeIndexKey] unsignedIntValue]];
        [_imageInputs setObject:value forKey:key];
    } else {
        [_plugin _setValue:value forNonImageParameterKey:key ofInstance:_instance];
    }
}

- (id)parameters
{
    if (_params == nil) {
        _params = [[FFGLRendererParametersBindable alloc] initWithRenderer:self];
    }
    return _params;
}

- (FFGLImage *)outputImage
{
    return _output;
}

- (void)setOutputImage:(FFGLImage *)image
{
    [image retain];
    [_output release];
    _output = image;
}

- (void)renderAtTime:(NSTimeInterval)time
{
    if ([_plugin _supportsSetTime]) {
        [_plugin _setTime:time ofInstance:_instance];
    }
    [self _implementationRender];
}
@end

@implementation FFGLRendererParametersBindable
- (id)initWithRenderer:(FFGLRenderer *)renderer
{
    if (self = [super init]) {
        _renderer = [renderer retain];
    }
    return self;
}

- (void)dealloc
{
    [_renderer release];
    [super dealloc];
}

- (id)valueForKeyPath:(NSString *)keyPath
{
    NSArray *pathParts = [keyPath componentsSeparatedByString:@"."];
    if ([[pathParts lastObject] isEqualToString:@"value"] && ([pathParts count] > 1)) {
        return [_renderer valueForParameterKey:[pathParts objectAtIndex:[pathParts count] - 2]];
    } else {
        return [super valueForKeyPath:keyPath];
    }
}

- (void)setValue:(id)value forKeyPath:(NSString *)keyPath
{
    NSArray *pathParts = [keyPath componentsSeparatedByString:@"."];
    if ([[pathParts lastObject] isEqualToString:@"value"] && ([pathParts count] > 1)) {
        [_renderer _performSetValue:value forParameterKey:[pathParts objectAtIndex:[pathParts count] - 2]];
    } else {
        [super setValue:value forKeyPath:keyPath];
    }
}
@end