//
//  FFGLCPURenderer.m
//  VVOpenSource
//
//  Created by Tom on 10/08/2009.
//

#import "FFGLCPURenderer.h"
#import "FFGLRendererSubclassing.h"
#import "FFGLPluginInstances.h"
#import "FreeFrame.h"
#import <QuartzCore/QuartzCore.h>

@interface FFGLCPURenderer (Private)
- (void)_setBuffer:(void *)buffer forInputAtIndex:(NSUInteger)index;
@end
@implementation FFGLCPURenderer

- (id)initWithPlugin:(FFGLPlugin *)plugin pixelFormat:(NSString *)format forBounds:(NSRect)bounds
{
    if (self = [super initWithPlugin:plugin pixelFormat:format forBounds:bounds]) {
        NSUInteger numBuffers = [plugin _maximumInputFrameCount];
        if (numBuffers > 0) {
            _buffers = malloc(sizeof(void *) * numBuffers);
        }
        _fcStruct.numInputFrames = numBuffers;
        _fcStruct.ppInputFrames = _buffers;
    }
    return self;
}

- (void)dealloc
{
    if (_buffers != NULL)
        free(_buffers);
    [super dealloc];
}

- (void)_setImage:(id)image forInputAtIndex:(NSUInteger)index
{
    // TODO: check image conforms to the pixelFormat and bounds we were inited with, get buffer from image
//    [self _setBuffer:buffer forInputAtIndex:index];
}

- (void)_setBuffer:(void *)buffer forInputAtIndex:(NSUInteger)index
{
    _buffers[index] = buffer;
}

- (void)_render
{
    FFGLPlugin *plugin = [self plugin];
    if ([plugin _prefersFrameCopy]) {
        [plugin _processFrameCopy:&_fcStruct forInstance:[self _instance]];
    } else {
        [plugin _processFrameInPlace:_buffers[0] forInstance:[self _instance]];
    }
}

@end
