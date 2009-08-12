/*
 *  FFGLPluginInstances.h
 *  VVOpenSource
 *
 *  Created by Tom on 26/07/2009.
 *
 */

#import "FFGLPlugin.h"

typedef NSUInteger FFGLPluginInstance;

@interface FFGLPlugin (Instances)
/* 
 Here we add methods FFGLRenderer uses to deal with instance-related stuff in FFGLPlugin. This header is not
 exported in the framework, it is private for FFGLPlugin and FFGLRenderer and subclasses.
 */
// GPU renderers can pass in nil for pixelFormat
- (FFGLPluginInstance)newInstanceWithBounds:(NSRect)bounds pixelFormat:(NSString *)format;
- (BOOL)disposeInstance:(FFGLPluginInstance)instance;
@end