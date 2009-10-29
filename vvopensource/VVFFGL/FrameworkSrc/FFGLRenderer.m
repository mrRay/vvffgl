//
//  FFGLRenderer.m
//  VVOpenSource
//
//  Created by Tom on 24/07/2009.
//

#import "FFGLRenderer.h"
#import "FFGLPlugin.h"
#import "FFGLGPURenderer.h"
#import "FFGLCPURenderer.h"
#import "FFGLInternal.h"

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
            if ((plugin == nil)
                || (format != nil
#if __BIG_ENDIAN__
                    && ![format isEqualToString:FFGLPixelFormatRGB565]
                    && ![format isEqualToString:FFGLPixelFormatRGB888]
                    && ![format isEqualToString:FFGLPixelFormatARGB8888]
#else
                    && ![format isEqualToString:FFGLPixelFormatBGR565]
                    && ![format isEqualToString:FFGLPixelFormatBGR565]
                    && ![format isEqualToString:FFGLPixelFormatBGRA8888]
#endif
                )
                || (([plugin mode] == FFGLPluginModeCPU)
                    && ![[plugin supportedBufferPixelFormats] containsObject:format])
                ) {
                [NSException raise:@"FFGLRendererException" format:@"Invalid arguments in init"];
                [self release];
                return nil;
            }
            NSUInteger maxInputs = [plugin _maximumInputFrameCount];
            _imageInputValidity = malloc(sizeof(BOOL) * maxInputs);
            _needsToCheckValidity = YES;
            if (_imageInputValidity == NULL) {
                [self release];
                return nil;
            }
            NSUInteger i;
            for (i = 0; i < maxInputs; i++) {
                _imageInputValidity[i] = NO;
            }
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
            if (pthread_mutex_init(&_lock, NULL) != 0) {
                [self release];
                return nil;
            }
            NSLog(@"Renderer initted");
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

- (void)releaseResources {
    NSLog(@"releaseResources");
    if(_pluginContext != nil)
        CGLReleaseContext(_pluginContext);
    if (_instance != 0)
        [[self plugin] _disposeInstance:_instance];
    if (_imageInputValidity != NULL)
        free(_imageInputValidity);
    pthread_mutex_destroy(&_lock);
}

- (void)finalize
{
    [self releaseResources];
    [super finalize];
}

- (void)dealloc
{
    [_params release];
    [_plugin release];
    [_pixelFormat release];
    [_imageInputs release];
    [self releaseResources];
    [super dealloc];
}

- (FFGLPluginInstance)_instance
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

- (BOOL)willUseParameterKey:(NSString *)key
{
    NSDictionary *attributes = [_plugin attributesForParameterWithKey:key];
    if (attributes == nil) {
        [NSException raise:@"FFGLRendererException" format:@"No such key: %@"];
        return NO;
    }
    if ([[attributes objectForKey:FFGLParameterAttributeTypeKey] isEqualToString:FFGLParameterTypeImage]) {
        NSUInteger index = [[attributes objectForKey:FFGLParameterAttributeIndexKey] unsignedIntValue];
        NSUInteger min = [_plugin _minimumInputFrameCount];
        if (index < min) {
            return YES;
        }
        pthread_mutex_lock(&_lock);
        return [_plugin _imageInputAtIndex:index willBeUsedByInstance:_instance];
        pthread_mutex_unlock(&_lock);        
    } else {
        return YES;
    }
}

- (id)valueForParameterKey:(NSString *)key
{
    id output;
    pthread_mutex_lock(&_lock);
    if ([[[_plugin attributesForParameterWithKey:key] objectForKey:FFGLParameterAttributeTypeKey] isEqualToString:FFGLParameterTypeImage]) {
        output = [_imageInputs objectForKey:key];
    } else {
        output = [_plugin _valueForNonImageParameterKey:key ofInstance:_instance];
    }
    pthread_mutex_unlock(&_lock);
    return output;
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
    if (attributes == nil) {
        [NSException raise:@"FFGLRendererException" format:@"No such key: %@"];
        return;
    }
    pthread_mutex_lock(&_lock);
    if ([[attributes objectForKey:FFGLParameterAttributeTypeKey] isEqualToString:FFGLParameterTypeImage]) {
        // check our subclass can use the image
        NSUInteger index = [[attributes objectForKey:FFGLParameterAttributeIndexKey] unsignedIntValue];
        if (value != nil) {
            _imageInputValidity[index] = [self _implementationSetImage:value forInputAtIndex:index];
            [_imageInputs setObject:value forKey:key];
        } else {
            _imageInputValidity[index] = NO;
            [_imageInputs removeObjectForKey:key];
        }
        _needsToCheckValidity = YES;
    } else {
        [_plugin _setValue:value forNonImageParameterKey:key ofInstance:_instance];
    }
    pthread_mutex_unlock(&_lock);
}

- (id)parameters
{
    if (_params == nil) {
        _params = [[FFGLRendererParametersBindable alloc] initWithRenderer:self]; // released in dealloc
    }
    return _params;
}

- (FFGLImage *)outputImage
{
    return _output;
}

- (void)setOutputImage:(FFGLImage *)image
{
    // This is called by subclasses from _implementationRender, so we already have the lock.
    [image retain];
    [_output release];
    _output = image;
}

- (BOOL)renderAtTime:(NSTimeInterval)time
{
    pthread_mutex_lock(&_lock);
    BOOL ready = YES;
    NSUInteger i;
    if (_needsToCheckValidity) {
        NSUInteger min = [_plugin _minimumInputFrameCount];
        NSUInteger max = [_plugin _maximumInputFrameCount];
        for (i = 0; i < min; i++) {
            if (_imageInputValidity[i] == NO) {
                ready = NO;
                break;
            }
        }
        for (; i < max; i++) {
            if ((_imageInputValidity[i] == NO) && [_plugin _imageInputAtIndex:i willBeUsedByInstance:_instance]) {
                ready = NO;
                break;
            }
        }
        if (ready == YES) {
            _needsToCheckValidity = NO;
        }
    }
    BOOL success;
    if (ready) {
        if ([_plugin _supportsSetTime]) {
            [_plugin _setTime:time ofInstance:_instance];
        }
        success = [self _implementationRender];        
    } else {
        NSLog(@"Inputs not set."); // TODO: remove this NSLog
        success = NO;
    }
    pthread_mutex_unlock(&_lock);
    return success;
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

- (id)valueForUndefinedKey:(NSString *)key
{
    if ([[[_renderer plugin] parameterKeys] containsObject:key])
        return [_renderer valueForParameterKey:key];
    else
        return [super valueForUndefinedKey:key];
}

/*
- (id)valueForKeyPath:(NSString *)keyPath
{
    NSArray *pathParts = [keyPath componentsSeparatedByString:@"."];
    if ([[pathParts lastObject] isEqualToString:@"value"] && ([pathParts count] > 1)) {
        return [_renderer valueForParameterKey:[pathParts objectAtIndex:[pathParts count] - 2]];
    } else {
        return [super valueForKeyPath:keyPath];
    }
}
*/
- (void)setValue:(id)value forUndefinedKey:(NSString *)key
{
    if ([[[_renderer plugin] parameterKeys] containsObject:key])
        [_renderer _performSetValue:value forParameterKey:key];
    else
        [super setValue:value forUndefinedKey:key];
}
/*
- (void)setValue:(id)value forKeyPath:(NSString *)keyPath
{
    NSArray *pathParts = [keyPath componentsSeparatedByString:@"."];
    if ([[pathParts lastObject] isEqualToString:@"value"] && ([pathParts count] > 1)) {
        [_renderer _performSetValue:value forParameterKey:[pathParts objectAtIndex:[pathParts count] - 2]];
    } else {
        [super setValue:value forKeyPath:keyPath];
    }
}
 */
@end