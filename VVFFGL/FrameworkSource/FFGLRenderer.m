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
#import <libkern/OSAtomic.h>
#import <pthread.h>

enum FFGLRendererReadyState {
    FFGLRendererNeedsCheck,
    FFGLRendererNotReady,
    FFGLRendererReady
};

typedef struct FFGLRendererPrivate
{
    BOOL                *imageInputValidity;
    NSInteger           readyState;
    id                  paramsBindable;
	char				**stringParams;
    pthread_mutex_t     lock;
    OSSpinLock          paramsBindableCreationLock;
} FFGLRendererPrivate;

#define ffglRPrivate(x) ((FFGLRendererPrivate *)_private)->x

@interface FFGLRendererParametersBindable : NSObject
{
    FFGLRenderer *_renderer;
}
- (id)initWithRenderer:(FFGLRenderer *)renderer;
@end

@interface FFGLRenderer (Private)
- (void)_performSetValue:(id)value forParameterKey:(NSString *)key;
@end
@implementation FFGLRenderer

- (id)init
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (id)initWithPlugin:(FFGLPlugin *)plugin context:(CGLContextObj)context pixelFormat:(NSString *)format outputHint:(FFGLRendererHint)hint size:(NSSize)size
{
    if (self = [super init])
	{
        if ([self class] == [FFGLRenderer class])
		{
            [self release];
            if ([plugin mode] == FFGLPluginModeGPU)
			{
                return [[FFGLGPURenderer alloc] initWithPlugin:plugin context:context pixelFormat:format outputHint:hint size:size];
            }
			else if ([plugin mode] == FFGLPluginModeCPU)
			{
                return [[FFGLCPURenderer alloc] initWithPlugin:plugin context:context pixelFormat:format outputHint:hint size:size];
            } 
			else
			{
                return nil;
            }        
        }
		else
		{			
            if ((plugin == nil)
                || (([plugin mode] == FFGLPluginModeCPU)
                    && ![[plugin supportedBufferPixelFormats] containsObject:format])
				|| (hint > FFGLRendererHintBuffer)
				|| (context == NULL)
				)
			{
				[self release];
                [NSException raise:@"FFGLRendererException" format:@"Invalid arguments in init"];
                return nil;
            }

			_private = malloc(sizeof(FFGLRendererPrivate));

			if (_private == NULL)
			{
				[self release];
				return nil;
			}
			
			NSUInteger maxInputs = [plugin _maximumInputFrameCount];
            
			ffglRPrivate(imageInputValidity) = NULL;
			ffglRPrivate(stringParams) = nil;
			ffglRPrivate(paramsBindable) = nil;
			ffglRPrivate(paramsBindableCreationLock) = OS_SPINLOCK_INIT;

			if (maxInputs > 0)
			{
				ffglRPrivate(imageInputValidity) = malloc(sizeof(BOOL) * maxInputs);	
				_inputs = malloc(sizeof(FFGLImage *) * maxInputs);
			
				if (ffglRPrivate(imageInputValidity) == NULL || _inputs == NULL)
				{
					[self release];
					return nil;
				}
				
				for (unsigned int i = 0; i < maxInputs; i++)
				{
					ffglRPrivate(imageInputValidity)[i] = NO;
					_inputs[i] = nil;
				}
			}
			
			unsigned int paramCount = [[plugin parameterKeys] count];
			if (paramCount > 0)
			{
				ffglRPrivate(stringParams) = malloc(sizeof(char *) * paramCount);
				if (ffglRPrivate(stringParams) == NULL)
				{
					[self release];
					return nil;
				}
				for (unsigned int i = 0; i < paramCount; i++) {
					ffglRPrivate(stringParams)[i] = NULL;
				}
			}
			ffglRPrivate(readyState) = FFGLRendererNeedsCheck;

			CGLContextObj prev;
			FFGLPluginMode mode = [plugin mode];
			if (mode == FFGLPluginModeGPU)
			{
				ffglSetContext(context, prev);
				CGLLockContext(context);				
			}
            _instance = [plugin _newInstanceWithSize:size pixelFormat:format];
			if (mode == FFGLPluginModeGPU)
			{
				CGLUnlockContext(context);
				ffglRestoreContext(context, prev);
			}
            
			if (_instance == FFGLInvalidInstance)
			{
                [self release];
                return nil;
            }
            _plugin = [plugin retain];
			
			cgl_ctx = CGLRetainContext(context);                
            
            _size = size;
            _pixelFormat = [format retain];
			_outputHint = hint;
            if (pthread_mutex_init(&ffglRPrivate(lock), NULL) != 0)
			{
                [self release];
                return nil;
            }
        }
    }	
    return self;
}

- (void)releaseResources {
    if (_instance != 0)
	{
		CGLContextObj prev;
		FFGLPluginMode mode = [_plugin mode];
		if (mode == FFGLPluginModeGPU)
		{
			ffglSetContext(cgl_ctx, prev);
			CGLLockContext(cgl_ctx);
		}
        [_plugin _disposeInstance:_instance];
		if (mode == FFGLPluginModeGPU)
		{
			CGLUnlockContext(cgl_ctx);
			ffglRestoreContext(cgl_ctx, prev);
		}
	}
	if(cgl_ctx != nil)
	{
		CGLReleaseContext(cgl_ctx);
	}
	if (_private != NULL)
	{
		if (ffglRPrivate(imageInputValidity) != NULL)
		{
			free(ffglRPrivate(imageInputValidity));
		}
		pthread_mutex_destroy(&ffglRPrivate(lock));
		if (ffglRPrivate(stringParams) != NULL)
		{
			unsigned int paramCount = [[_plugin parameterKeys] count];
			for (unsigned int i = 0; i < paramCount; i++) {
				free(ffglRPrivate(stringParams)[i]);
			}
			free(ffglRPrivate(stringParams));
		}
		free(_private);
	}
	free(_inputs);
}

- (void)finalize
{
    [self releaseResources];
    [super finalize];
}

- (void)dealloc
{
	if (_private != NULL)
	{
		[ffglRPrivate(paramsBindable) release];
	}
	NSUInteger inputCount = [_plugin _maximumInputFrameCount];
	for (int i = 0; i < inputCount; i++) {
		[_inputs[i] release];
	}
    [_pixelFormat release];
    [self releaseResources];
	[_plugin release];
    [super dealloc];
}

- (FFGLPlugin *)plugin
{
    return _plugin;
}

- (CGLContextObj)context
{
    return cgl_ctx;
}

- (NSSize)size
{
    return _size;
}

- (NSString *)pixelFormat
{
    return _pixelFormat;
}

- (FFGLRendererHint)outputHint
{
    return _outputHint;
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
        pthread_mutex_lock(&ffglRPrivate(lock));
		/*
		 // This is probably over-cautious and isn't required by the spec, so let's try not doing it
		CGLContextObj prev;
		FFGLPluginMode mode = [_plugin mode];
		if (mode == FFGLPluginModeGPU)
		{
			ffglSetContext(cgl_ctx, prev);
			CGLLockContext(cgl_ctx);
		}
		 */
        BOOL result = [_plugin _imageInputAtIndex:index willBeUsedByInstance:_instance];
		/*
		if (mode == FFGLPluginModeGPU)
		{
			CGLUnlockContext(cgl_ctx);
			ffglRestoreContext(cgl_ctx, prev);
		}
		 */
        pthread_mutex_unlock(&ffglRPrivate(lock));
		return result;
    } else {
        return YES;
    }
}

- (id)valueForParameterKey:(NSString *)key
{
    id output;
	NSDictionary *attributes = [_plugin attributesForParameterWithKey:key];
    if (attributes == nil) {
        [NSException raise:@"FFGLRendererException" format:@"No such key: %@"];
        return nil;
    }
	NSUInteger index = [[attributes objectForKey:FFGLParameterAttributeIndexKey] unsignedIntValue];

    pthread_mutex_lock(&ffglRPrivate(lock));
    if ([[attributes objectForKey:FFGLParameterAttributeTypeKey] isEqualToString:FFGLParameterTypeImage]) {
        output = _inputs[index];
    } else {
		/*
		 // This is probably over-cautious and isn't required by the spec, so let's try not doing it
		CGLContextObj prev;
		FFGLPluginMode mode = [_plugin mode];
		if (mode == FFGLPluginModeGPU)
		{
			ffglSetContext(cgl_ctx, prev);
			CGLLockContext(cgl_ctx);
		}
		 */
		// TODO: change this method to accept the index, not key, to save the double index lookup
        output = [_plugin _valueForNonImageParameterKey:key ofInstance:_instance];
		/*
		if (mode == FFGLPluginModeGPU)
		{
			CGLUnlockContext(cgl_ctx);
			ffglRestoreContext(cgl_ctx, prev);
		}
		 */
    }
	[[output retain] autorelease];
    pthread_mutex_unlock(&ffglRPrivate(lock));
    return output;
}

- (void)setValue:(id)value forParameterKey:(NSString *)key
{
    [ffglRPrivate(paramsBindable) willChangeValueForKey:key];
    [self _performSetValue:value forParameterKey:key];
    [ffglRPrivate(paramsBindable) didChangeValueForKey:key];
}

- (void)_performSetValue:(id)value forParameterKey:(NSString *)key
{
    NSDictionary *attributes = [_plugin attributesForParameterWithKey:key];
    if (attributes == nil) {
        [NSException raise:@"FFGLRendererException" format:@"No such key: %@"];
        return;
    }
	NSUInteger index = [[attributes objectForKey:FFGLParameterAttributeIndexKey] unsignedIntValue];
    NSString *type = [attributes objectForKey:FFGLParameterAttributeTypeKey];
    pthread_mutex_lock(&ffglRPrivate(lock));
    if ([type isEqualToString:FFGLParameterTypeImage])
    {
        // check our subclass can use the image
        BOOL validity;
        if (value != nil) {
			validity = [self _implementationReplaceImage:_inputs[index] withImage:value forInputAtIndex:index];
			[value retain];
            [_inputs[index] release];
			_inputs[index] = value;
        } else {
            validity = NO;
            [_inputs[index] release];
			_inputs[index] = nil;
        }
        if (ffglRPrivate(imageInputValidity)[index] != validity)
        {
            ffglRPrivate(imageInputValidity)[index] = validity;
            ffglRPrivate(readyState) = FFGLRendererNeedsCheck;
        }
    }
	else
	{
		/*
		 // This is probably over-cautious and isn't required by the spec, so let's try not doing it
		CGLContextObj prev;
		FFGLPluginMode mode = [_plugin mode];
		if (mode == FFGLPluginModeGPU)
		{
			ffglSetContext(cgl_ctx, prev);
			CGLLockContext(cgl_ctx);
		}
		 */
		if ([type isEqualToString:FFGLParameterTypeString])
		{
			free(ffglRPrivate(stringParams)[index]);
			if (value == nil)
			{
				ffglRPrivate(stringParams)[index] = NULL;
			}
			else
			{
				ffglRPrivate(stringParams)[index] = strdup([value cStringUsingEncoding:NSASCIIStringEncoding]);
			}
			[_plugin _setValue:ffglRPrivate(stringParams)[index] forStringParameterAtIndex:index ofInstance:_instance];
			ffglRPrivate(readyState) = FFGLRendererNeedsCheck;
		}
		else
		{
			[_plugin _setValue:value forNumberParameterAtIndex:index ofInstance:_instance];
			ffglRPrivate(readyState) = FFGLRendererNeedsCheck;
		}
		/*
		if (mode == FFGLPluginModeGPU)
		{
			CGLUnlockContext(cgl_ctx);
			ffglRestoreContext(cgl_ctx, prev);
		}
		 */
	}
    pthread_mutex_unlock(&ffglRPrivate(lock));
}

- (id)parameters
{
    OSSpinLockLock(&ffglRPrivate(paramsBindableCreationLock));
    if (ffglRPrivate(paramsBindable) == nil)
    {
        ffglRPrivate(paramsBindable) = [[FFGLRendererParametersBindable alloc] initWithRenderer:self]; // released in dealloc
    }
    OSSpinLockUnlock(&ffglRPrivate(paramsBindableCreationLock));
    return ffglRPrivate(paramsBindable);
}

- (FFGLImage *)createOutputAtTime:(NSTimeInterval)time
{
    FFGLImage *result;
    pthread_mutex_lock(&ffglRPrivate(lock));
    if (ffglRPrivate(readyState) == FFGLRendererNeedsCheck)
    {
        NSUInteger max = [_plugin _maximumInputFrameCount];
        NSUInteger got;
        ffglRPrivate(readyState) = FFGLRendererReady;
        for (got = 0; got < max; got++) {
            if (ffglRPrivate(imageInputValidity)[got] == NO) {
				if ([_plugin _imageInputAtIndex:got willBeUsedByInstance:_instance])
				{
					ffglRPrivate(readyState) = FFGLRendererNotReady;
				}
				break;
            }
        }
        [self _implementationSetImageInputCount:got];
    }
    if (ffglRPrivate(readyState) == FFGLRendererReady)
	{
		[_plugin _setTime:time ofInstance:_instance];
        result = [self _implementationCreateOutput];        
    }
	else 
	{
        result = nil;
    }
    pthread_mutex_unlock(&ffglRPrivate(lock));
    return result;
}
@end

@implementation FFGLRendererParametersBindable
- (id)initWithRenderer:(FFGLRenderer *)renderer
{
    if (self = [super init])
    {
	/* Don't retain the renderer, or it will never be released */
        _renderer = renderer;
    }
    return self;
}

- (id)valueForUndefinedKey:(NSString *)key
{
    if ([[[_renderer plugin] parameterKeys] containsObject:key])
        return [_renderer valueForParameterKey:key];
    else
        return [super valueForUndefinedKey:key];
}


- (void)setValue:(id)value forUndefinedKey:(NSString *)key
{
    if ([[[_renderer plugin] parameterKeys] containsObject:key])
        [_renderer _performSetValue:value forParameterKey:key];
    else
        [super setValue:value forUndefinedKey:key];
}

@end