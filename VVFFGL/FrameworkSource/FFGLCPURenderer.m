//
//  FFGLCPURenderer.m
//  VVOpenSource
//
//  Created by Tom on 10/08/2009.
//

#import "FFGLCPURenderer.h"
#import "FFGLImage.h"
#import <QuartzCore/QuartzCore.h>

#if defined(FFGL_USE_BUFFER_POOLS)

static const void *FFGLCPURendererBufferCreate(const void *userInfo)
{
	return valloc(*(size_t *)userInfo);
}

static void FFGLCPURendererBufferDestroy(const void *baseAddress, const void* context) {
    free((void *)baseAddress);
}

static void FFGLCPURendererPoolObjectRelease(const void *baseAddress, void *context) {
	FFGLPoolObjectRelease((FFGLPoolObjectRef)context);
}

#else /* FFGL_USE_BUFFER_POOLS not defined */

static void FFGLCPURendererFree(const void *baseAddress, void *context)
{
    free((void *)baseAddress);
}

#endif /* FFGL_USE_BUFFER_POOLS */

@implementation FFGLCPURenderer

- (id)initWithPlugin:(FFGLPlugin *)plugin context:(CGLContextObj)context pixelFormat:(NSString *)format outputHint:(FFGLRendererHint)hint size:(NSSize)size
{
    if (self = [super initWithPlugin:plugin context:context pixelFormat:format outputHint:hint size:size]) {
        NSUInteger numBuffers = [plugin _maximumInputFrameCount];
        if (numBuffers > 0)
        {
            _buffers = malloc(sizeof(void *) * numBuffers);
            if (_buffers == NULL)
			{
                [self release];
                return nil;
            }
			for (int i = 0; i < numBuffers; i++) {
				_buffers[i] = NULL;
			}
        }
        _frameCopies = [_plugin _prefersFrameCopy];
        _fcStruct.inputFrameCount = 0;
        _fcStruct.inputFrames = _buffers;
		_bytesPerRow = _size.width * ffglBytesPerPixelForPixelFormat(format);
        _bytesPerBuffer = _bytesPerRow * _size.height;
#if defined(FFGL_USE_BUFFER_POOLS)
        FFGLPoolCallBacks callbacks = {FFGLCPURendererBufferCreate, FFGLCPURendererBufferDestroy};
        _pool = FFGLPoolCreate(&callbacks, 3, &_bytesPerBuffer);
#endif /* FFGL_USE_BUFFER_POOLS */
    }
    return self;
}

- (void)releaseNonGCResources
{
	free(_buffers);
#if defined(FFGL_USE_BUFFER_POOLS)
    FFGLPoolRelease(_pool);
#endif
}

- (void)finalize
{
	[self releaseNonGCResources];
	[super finalize];
}

- (void)dealloc
{
	[self releaseNonGCResources];
    [super dealloc];
}

- (BOOL)_implementationReplaceImage:(FFGLImage *)prevImage withImage:(FFGLImage *)newImage forInputAtIndex:(NSUInteger)index
{
	if (_buffers[index] != NULL)
	{
		[prevImage unlockBufferRepresentation];
		_buffers[index] = NULL;
	}
	if (([newImage imagePixelsHigh] != _size.height) || ([newImage imagePixelsWide] != _size.width))
	{
		// Not sure what we do here - for now raise exception, could just return NO.
		// But that failure is only used within FFGLRenderer, not transmitted outside framework.
		[NSException raise:@"FFGLRendererException" format:@"Input image dimensions or format do not match renderer."];
		return NO;
	}
	else
	{
		return YES;
	}
}

- (void)_implementationSetImageInputCount:(NSUInteger)count
{
    _fcStruct.inputFrameCount = count;
}

- (FFGLImage *)_implementationCreateOutput
{
    BOOL result;
#if defined(FFGL_USE_BUFFER_POOLS)
    FFGLPoolObjectRef obj = FFGLPoolObjectCreate(_pool);
    _fcStruct.outputFrame = (void *)FFGLPoolObjectGetData(obj);
	if (_fcStruct.outputFrame == NULL) {
		FFGLPoolObjectRelease(obj);
        return nil;
    }
#else
    _fcStruct.outputFrame = valloc(_bytesPerBuffer);
	if (_fcStruct.outputFrame == NULL) {
        return nil;
    }
#endif
	for (int i = 0; i < _fcStruct.inputFrameCount; i++) {
		if (_buffers[i] == NULL && [_plugin _imageInputAtIndex:i willBeUsedByInstance:_instance])
		{
			if ([_inputs[i] lockBufferRepresentationWithPixelFormat:_pixelFormat]) {
				_buffers[i] = (void *)[_inputs[i] bufferBaseAddress];
			} else {
#if defined(FFGL_USE_BUFFER_POOLS)
				FFGLPoolObjectRelease(obj);
#else
				free(_fcStruct.outputFrame);
#endif
				return nil;
			}
		}
	}
    if (_frameCopies) {
        result = [_plugin _processFrameCopy:&_fcStruct forInstance:_instance];
    } else {
        if (_fcStruct.inputFrameCount > 0) { // ie we are not a source
            memcpy(_fcStruct.outputFrame, _buffers[0], _bytesPerBuffer);
        }
        result = [_plugin _processFrameInPlace:_fcStruct.outputFrame forInstance:_instance];
    }
    FFGLImage *output;
#if defined(FFGL_USE_BUFFER_POOLS)
    if (result)
	{
        output = [[FFGLImage alloc] initWithBuffer:_fcStruct.outputFrame
										CGLContext:_context
									   pixelFormat:_pixelFormat
										pixelsWide:_size.width
										pixelsHigh:_size.height
									   bytesPerRow:_bytesPerRow
										   flipped:NO
								   releaseCallback:FFGLCPURendererPoolObjectRelease
									   releaseInfo:obj];
    }
	else
	{
        FFGLPoolObjectRelease(obj);
		output = nil;
    }
#else
	if (result)
	{
        output = [[FFGLImage alloc] initWithBuffer:_fcStruct.outputFrame
										CGLContext:_context
									   pixelFormat:_pixelFormat
										pixelsWide:_size.width
										pixelsHigh:_size.height
									   bytesPerRow:_bytesPerRow
										   flipped:NO
								   releaseCallback:FFGLCPURendererFree
									   releaseInfo:NULL];
		
    }
	else
	{
        free(_fcStruct.outputFrame);
		output = nil;
    }
#endif
    return output;
}

@end
