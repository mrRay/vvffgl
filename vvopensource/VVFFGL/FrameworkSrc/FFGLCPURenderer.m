//
//  FFGLCPURenderer.m
//  VVOpenSource
//
//  Created by Tom on 10/08/2009.
//

#import "FFGLCPURenderer.h"
#import "FFGLPluginInstances.h"

@implementation FFGLCPURenderer

- (id)initWithPlugin:(FFGLPlugin *)plugin pixelFormat:(NSString *)format forBounds:(NSRect)bounds
{
    if (self = [super initWithPlugin:plugin pixelFormat:format forBounds:bounds]) {

    }
    return self;
}

- (void)dealloc
{

    [super dealloc];
}
- (void)renderAtTime:(NSTimeInterval)time
{
    
}
@end
