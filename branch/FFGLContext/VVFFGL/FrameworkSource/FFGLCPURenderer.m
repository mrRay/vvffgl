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

- (id)initWithPlugin:(FFGLPlugin *)plugin context:(FFGLContext *)context outputHint:(FFGLRendererHint)hint
{
    if (self = [super initWithPlugin:plugin context:context outputHint:hint]) {
        NSUInteger numBuffers = [plugin _maximumInputFrameCount];
        if (numBuffers > 0)
        {
            _buffers = malloc(sizeof(void *) * numBuffers);
            if (_buffers == NULL)
	    {
                [self release];
                return nil;
            }
        }
        _frameCopies = [_plugin _prefersFrameCopy];
        _fcStruct.inputFrameCount = 0;
        _fcStruct.inputFrames = _buffers;
		NSString *format = [context pixelFormat];
		NSSize size = [context size];
#if __BIG_ENDIAN__
        if ([format isEqualToString:FFGLPixelFormatRGB565]) { _bytesPerRow = 2 * size.width; }
        else if ([format isEqualToString:FFGLPixelFormatRGB888]) { _bytesPerRow = 3 * size.width; }
        else if ([format isEqualToString:FFGLPixelFormatARGB8888]) { _bytesPerRow = 4 * size.width; }
#else
        if ([format isEqualToString:FFGLPixelFormatBGR565]) { _bytesPerRow = 2 * size.width; }
        else if ([format isEqualToString:FFGLPixelFormatBGR888]) { _bytesPerRow = 3 * size.width; }
        else if ([format isEqualToString:FFGLPixelFormatBGRA8888]) { _bytesPerRow = 4 * size.width; }
#endif
        else { // This should never happen, as it is checked in FFGLRenderer at init.
            [NSException raise:@"FFGLRendererException" format:@"Unexpected pixel format."];
        }
		_bytesPerBuffer = _bytesPerRow * size.height;
#if defined(FFGL_USE_BUFFER_POOLS)
		_pool = [_context _bufferPool];
#endif /* FFGL_USE_BUFFER_POOLS */
    }
    return self;
}

- (void)releaseNonGCResources
{
    if (_buffers != NULL)
        free(_buffers);
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

- (BOOL)_implementationSetImage:(id)image forInputAtIndex:(NSUInteger)index
{
    if ([image lockBufferRepresentationWithPixelFormat:[_context pixelFormat]]) {
        if (([image bufferPixelsHigh] != [_context size].height) || ([image bufferPixelsWide] != [_context size].width)
            || ([image bufferPixelFormat] != [_context pixelFormat])) {
            [image unlockBufferRepresentation];
            // Not sure what we do here - for now raise exception, could just return NO.
            // But that failure is only used within FFGLRenderer, not transmitted to client.
            [NSException raise:@"FFGLRendererException" format:@"Input image dimensions or format do not match renderer."];
            return NO;
        }
	// TODO: unlock previous image, in case we ever do anything in unlock
        _buffers[index] = (void *)[image bufferBaseAddress];
        return YES;
    } else {
        return NO;
    }
}

- (void)_implementationSetImageInputCount:(NSUInteger)count
{
    _fcStruct.inputFrameCount = count;
}

- (BOOL)_implementationRender
{
    BOOL result;
#if defined(FFGL_USE_BUFFER_POOLS)
    FFGLPoolObjectRef obj = FFGLPoolObjectCreate(_pool);
    _fcStruct.outputFrame = (void *)FFGLPoolObjectGetData(obj);
#else
    _fcStruct.outputFrame = valloc(_bytesPerBuffer);
#endif
    if (_fcStruct.outputFrame == NULL) {
        return NO;
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
    if (result) {
        output = [[[FFGLImage alloc] initWithBuffer:_fcStruct.outputFrame
                                         CGLContext:[_context CGLContextObj]
                                        pixelFormat:[_context pixelFormat]
                                         pixelsWide:[_context size].width
                                         pixelsHigh:[_context size].height
                                        bytesPerRow:_bytesPerRow
											flipped:NO
#if defined(FFGL_USE_BUFFER_POOLS)
                                    releaseCallback:FFGLCPURendererPoolObjectRelease
                                        releaseInfo:obj] autorelease];
    } else {
        FFGLPoolObjectRelease(obj);
        output = nil;
    }
#else
									releaseCallback:FFGLCPURendererFree
										releaseInfo:NULL] autorelease];
    } else {
        free(_fcStruct.outputFrame);
        output = nil;
    }
#endif
    [self setOutputImage:output];
    return result;
}

@end
