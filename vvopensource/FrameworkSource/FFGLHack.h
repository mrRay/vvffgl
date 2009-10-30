/*
 *  FFGLHack.h
 *  VVOpenSource
 *
 *  Created by Tom on 04/10/2009.
 *  Copyright 2009 Tom Butterworth. All rights reserved.
 *
 */
#import "FFGLCPURenderer.h"
#import "FFGLGPURenderer.h"

@interface FFGLCPURenderer (HackPrivate)
- (void)_setBuffer:(void *)buffer forInputAtIndex:(NSUInteger)index;
- (void)_attachOutputBuffer:(void *)buffer;
@end

@interface FFGLGPURenderer (HackPrivate)
- (void)_setTexture:(GLuint)texture forInputAtIndex:(NSUInteger)index;
@end