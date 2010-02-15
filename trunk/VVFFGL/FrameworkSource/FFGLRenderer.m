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
    FFGLImage           *output;
    id                  params;
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
			ffglRPrivate(output) = nil;
			ffglRPrivate(params) = nil;
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
			ffglRPrivate(readyState) = FFGLRendererNeedsCheck;

			CGLContextObj prev;
			if ([plugin mode] == FFGLPluginModeGPU)
			{
				ffglSetContext(context, prev);
				CGLLockContext(context);				
			}
            _instance = [plugin _newInstanceWithSize:size pixelFormat:format];
			if ([plugin mode] == FFGLPluginModeGPU)
			{
				CGLUnlockContext(context);
				ffglRestoreContext(context, prev);
			}
            
			if (_instance == 0)
			{
                [self release];
                return nil;
            }
            _plugin = [plugin retain];
			
			_context = CGLRetainContext(context);                
            
            _size = size;
            _pixelFormat = [format retain];
			
            if (pthread_mutex_init(&ffglRPrivate(lock), NULL) != 0)
			{
                [self release];
                return nil;
            }
			_outputHint = hint;
        }
    }	
    return self;
}

- (void)releaseResources {
    if (_instance != 0)
	{
		CGLContextObj prev;
		if ([_plugin mode] == FFGLPluginModeGPU)
		{
			ffglSetContext(_context, prev);
			CGLLockContext(_context);
		}
        [_plugin _disposeInstance:_instance];
		if ([_plugin mode] == FFGLPluginModeGPU)
		{
			CGLUnlockContext(_context);
			ffglRestoreContext(_context, prev);
		}
	}
	if(_context != nil)
	{
		CGLReleaseContext(_context);
	}
	if (_private != NULL)
	{
		if (ffglRPrivate(imageInputValidity) != NULL)
		{
			free(ffglRPrivate(imageInputValidity));
		}
		pthread_mutex_destroy(&ffglRPrivate(lock));
		free(_private);
	}
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
		[ffglRPrivate(params) release];
		[ffglRPrivate(output) release];
	}
	NSUInteger inputCount = [_plugin _maximumInputFrameCount];
	for (int i = 0; i < inputCount; i++) {
		[_inputs[i] release];
	}
    [_plugin release];
    [_pixelFormat release];
    [self releaseResources];
    [super dealloc];
}

- (FFGLPlugin *)plugin
{
    return _plugin;
}

- (CGLContextObj)context
{
    return _context;
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
        NSUInteger min = [_plugin _minimumInputFrameCount];
        if (index < min) {
            return YES;
        }
        pthread_mutex_lock(&ffglRPrivate(lock));
		CGLContextObj prev;
		if ([_plugin mode] == FFGLPluginModeGPU)
		{
			ffglSetContext(_context, prev);
			CGLLockContext(_context);
		}
        BOOL result = [_plugin _imageInputAtIndex:index willBeUsedByInstance:_instance];
		if ([_plugin mode] == FFGLPluginModeGPU)
		{
			CGLUnlockContext(_context);
			ffglRestoreContext(_context, prev);
		}
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
		CGLContextObj prev;
		if ([_plugin mode] == FFGLPluginModeGPU)
		{
			ffglSetContext(_context, prev);
			CGLLockContext(_context);
		}
        output = [_plugin _valueForNonImageParameterKey:key ofInstance:_instance];
		if ([_plugin mode] == FFGLPluginModeGPU)
		{
			CGLUnlockContext(_context);
			ffglRestoreContext(_context, prev);
		}
    }
	[[output retain] autorelease];
    pthread_mutex_unlock(&ffglRPrivate(lock));
    return output;
}

- (void)setValue:(id)value forParameterKey:(NSString *)key
{
    [ffglRPrivate(params) willChangeValueForKey:key];
    [self _performSetValue:value forParameterKey:key];
    [ffglRPrivate(params) didChangeValueForKey:key];
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
		CGLContextObj prev;
		if ([_plugin mode] == FFGLPluginModeGPU)
		{
			ffglSetContext(_context, prev);
			CGLLockContext(_context);
		}
		if ([type isEqualToString:FFGLParameterTypeString])
		{
			[_plugin _setValue:value forStringParameterAtIndex:index ofInstance:_instance];
			ffglRPrivate(readyState) = FFGLRendererNeedsCheck;
		}
		else
		{
			[_plugin _setValue:value forNumberParameterAtIndex:index ofInstance:_instance];
			ffglRPrivate(readyState) = FFGLRendererNeedsCheck;
		}
		if ([_plugin mode] == FFGLPluginModeGPU)
		{
			CGLUnlockContext(_context);
			ffglRestoreContext(_context, prev);
		}
	}
    pthread_mutex_unlock(&ffglRPrivate(lock));
}

- (id)parameters
{
    OSSpinLockLock(&ffglRPrivate(paramsBindableCreationLock));
    if (ffglRPrivate(params) == nil)
    {
        ffglRPrivate(params) = [[FFGLRendererParametersBindable alloc] initWithRenderer:self]; // released in dealloc
    }
    OSSpinLockUnlock(&ffglRPrivate(paramsBindableCreationLock));
    return ffglRPrivate(params);
}

- (FFGLImage *)outputImage
{
	pthread_mutex_lock(&ffglRPrivate(lock));
	FFGLImage *output = ffglRPrivate(output);
	[[output retain] autorelease];
	pthread_mutex_unlock(&ffglRPrivate(lock));
    return output;
}

- (void)setOutputImage:(FFGLImage *)image
{
    // This is called by subclasses from _implementationRender, so we already have the lock.
    [image retain];
    [ffglRPrivate(output) release];
    ffglRPrivate(output) = image;
}

- (BOOL)renderAtTime:(NSTimeInterval)time
{
    BOOL success;
    pthread_mutex_lock(&ffglRPrivate(lock));
    if (ffglRPrivate(readyState) == FFGLRendererNeedsCheck)
    {
        NSUInteger i;
        NSUInteger min = [_plugin _minimumInputFrameCount];
        NSUInteger max = [_plugin _maximumInputFrameCount];
        NSUInteger got = 0;
        ffglRPrivate(readyState) = FFGLRendererReady;
        for (i = 0; i < min; i++) {
            if (ffglRPrivate(imageInputValidity)[i] == NO) {
                ffglRPrivate(readyState) = FFGLRendererNotReady;
                break;
            }
            got++;
        }
        for (; i < max; i++) {
            if ((ffglRPrivate(imageInputValidity)[i] == NO) && [_plugin _imageInputAtIndex:i willBeUsedByInstance:_instance]) {
                ffglRPrivate(readyState) = FFGLRendererNotReady;
                break;
            }
            got++;
        }
        [self _implementationSetImageInputCount:got];
    }
    if (ffglRPrivate(readyState) == FFGLRendererReady)
	{
        if ([_plugin _supportsSetTime])
		{
            [_plugin _setTime:time ofInstance:_instance];
        }
        success = [self _implementationRender];        
    }
	else 
	{
        success = NO;
    }
	if (success == NO)
	{
		[self setOutputImage:nil];
	}
    pthread_mutex_unlock(&ffglRPrivate(lock));
    return success;
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