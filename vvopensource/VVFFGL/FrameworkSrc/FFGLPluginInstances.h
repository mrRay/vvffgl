/*
 *  FFGLPluginInstances.h
 *  VVOpenSource
 *
 *  Created by Tom on 26/07/2009.
 *
 */

#import "FFGLPlugin.h"

typedef uint32_t FFGLPluginInstance;

@interface FFGLPlugin (Instances)
/* 
 Here we add methods FFGLRenderer uses to deal with instance-related stuff in FFGLPlugin. This header is not
 exported in the framework, it is private for FFGLPlugin and FFGLRenderer and subclasses.
 */

/*
 Plugin properties
 */
- (NSUInteger)_minimumInputFrameCount;
- (NSUInteger)_maximumInputFrameCount;
- (BOOL)_supportsSetTime;

/*
 Instances
 */
- (FFGLPluginInstance)_newInstanceWithBounds:(NSRect)bounds pixelFormat:(NSString *)format; // GPU renderers can pass in nil for pixelFormat
- (BOOL)_disposeInstance:(FFGLPluginInstance)instance;
- (id)_valueForNonImageParameterKey:(NSString *)key ofInstance:(FFGLPluginInstance)instance;
- (void)_setValue:(id)value forNonImageParameterKey:(NSString *)key ofInstance:(FFGLPluginInstance)instance;
- (void)_setTime:(NSTimeInterval)time ofInstance:(FFGLPluginInstance)instance;
@end