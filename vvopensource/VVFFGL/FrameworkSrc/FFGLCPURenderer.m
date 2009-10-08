//
//  FFGLCPURenderer.m
//  VVOpenSource
//
//  Created by Tom on 10/08/2009.
//

#import "FFGLCPURenderer.h"
//#import "FFGLRendererSubclassing.h"
#import "FFGLImage.h"
#import <QuartzCore/QuartzCore.h>

static void FFGLCPURendererBufferRelease(void *baseAddress, void* context) {
    // for now, just free the buffer, could make them reusable, or use a CVPixelBufferPool
    free(baseAddress);
}

@implementation FFGLCPURenderer

- (id)initWithPlugin:(FFGLPlugin *)plugin pixelFormat:(NSString *)format forBounds:(NSRect)bounds
{
    if (self = [super initWithPlugin:plugin pixelFormat:format forBounds:bounds]) {
        NSUInteger numBuffers = [plugin _maximumInputFrameCount];
        if (numBuffers > 0) {
            _buffers = malloc(sizeof(void *) * numBuffers);
        }
        _fcStruct.inputFrameCount = numBuffers;
        _fcStruct.inputFrames = _buffers;
    }
    return self;
}

- (void)dealloc
{
    if (_buffers != NULL)
        free(_buffers);
    [super dealloc];
}

- (void)_implementationSetImage:(id)image forInputAtIndex:(NSUInteger)index
{
    if ([image lockBufferRepresentationWithPixelFormat:[self pixelFormat]]) {
        if (([image bufferPixelsHigh] != [self bounds].size.height) || ([image bufferPixelsWide] != [self bounds].size.width)
            || ([image bufferPixelFormat] != [self pixelFormat])) {
            [image unlockBufferRepresentation];
            [NSException raise:@"FFGLRendererException" format:@"Input image dimensions or format do not match renderer."];
            return;
        }
        _buffers[index] = [image bufferBaseAddress];
    }    
}

- (BOOL)_implementationRender
{
    FFGLPlugin *plugin = [self plugin];
    NSRect bounds = [self bounds];
    NSString *pFormat = [self pixelFormat];
    NSUInteger bpp;
    BOOL result;
#if __BIG_ENDIAN__
    if ([pFormat isEqualToString:FFGLPixelFormatRGB565]) { bpp = 2; }
    else if ([pFormat isEqualToString:FFGLPixelFormatRGB888]) { bpp = 3; }
    else if ([pFormat isEqualToString:FFGLPixelFormatARGB8888]) { bpp = 4; }
#else
    if ([pFormat isEqualToString:FFGLPixelFormatBGR565]) { bpp = 2; }
    else if ([pFormat isEqualToString:FFGLPixelFormatBGR888]) { bpp = 3; }
    else if ([pFormat isEqualToString:FFGLPixelFormatBGRA8888]) { bpp = 4; }
#endif
    else { // This should never happen, as it is checked in FFGLRenderer at init.
        [NSException raise:@"FFGLRendererException" format:@"Unexpected pixel format in FFGLRenderer"];
     }
    _fcStruct.outputFrame = valloc(bounds.size.width * bpp * bounds.size.height);
    if (_fcStruct.outputFrame == NULL) {
        return NO;
    }
    if ([plugin _prefersFrameCopy]) {
        result = [plugin _processFrameCopy:&_fcStruct forInstance:[self _instance]];
    } else {
        if (_fcStruct.inputFrameCount > 0) { // ie we are not a source
            memcpy(_fcStruct.outputFrame, _buffers[0], bounds.size.width * bpp * bounds.size.height);
        }
        result = [plugin _processFrameInPlace:_fcStruct.outputFrame forInstance:[self _instance]];
    }
    FFGLImage *output;
    if (result) {
        output = [[[FFGLImage alloc] initWithBuffer:_fcStruct.outputFrame
                                        pixelFormat:pFormat
                                         pixelsWide:bounds.size.width
                                         pixelsHigh:bounds.size.height
                                        bytesPerRow:bounds.size.width * bpp
                                    releaseCallback:FFGLCPURendererBufferRelease
                                     releaseContext:NULL] autorelease];
    } else {
        free(_fcStruct.outputFrame);
        output = nil;
    }
    [self setOutputImage:output];
    return result;
}

@end
