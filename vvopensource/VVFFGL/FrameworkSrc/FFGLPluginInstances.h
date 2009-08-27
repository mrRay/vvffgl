/*
 *  FFGLPluginInstances.h
 *  VVOpenSource
 *
 *  Created by Tom on 26/07/2009.
 *
 */

#import "FFGLPlugin.h"
#import "FFGL.h"

extern NSString * const FFGLParameterAttributeIndexKey;

typedef uint32_t FFGLPluginInstance;

@interface FFGLPlugin (Instances)
/* 
 Here we add methods FFGLRenderer uses to deal with instance-related stuff in FFGLPlugin. This header is not
 exported in the framework, it is private for FFGLPlugin and FFGLRenderer and subclasses.
 */

/*
 Plugin properties
 */
- (NSUInteger)_minimumInputFrameCount; // TODO: may not need this, could go
- (NSUInteger)_maximumInputFrameCount; // TODO: beth ditto
- (BOOL)_supportsSetTime;
- (BOOL)_prefersFrameCopy;

/*
 Instances
 */
- (FFGLPluginInstance)_newInstanceWithBounds:(NSRect)bounds pixelFormat:(NSString *)format; // GPU renderers can pass in nil for pixelFormat
- (void)_disposeInstance:(FFGLPluginInstance)instance;
- (id)_valueForNonImageParameterKey:(NSString *)key ofInstance:(FFGLPluginInstance)instance;
- (void)_setValue:(id)value forNonImageParameterKey:(NSString *)key ofInstance:(FFGLPluginInstance)instance;
- (void)_setTime:(NSTimeInterval)time ofInstance:(FFGLPluginInstance)instance;
- (void)_processFrameCopy:(ProcessFrameCopyStruct *)frameInfo forInstance:(FFGLPluginInstance)instance;
- (void)_processFrameInPlace:(void *)buffer forInstance:(FFGLPluginInstance)instance;
@end