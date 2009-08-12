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
- (FFGLPluginInstance)_newInstanceWithBounds:(NSRect)bounds pixelFormat:(NSString *)format;
- (BOOL)_disposeInstance:(FFGLPluginInstance)instance;
- (id)_valueForNonImageParameterKey:(NSString *)key ofInstance:(FFGLPluginInstance)instance;
- (void)_setValue:(id)value forNonImageParameterKey:(NSString *)key ofInstance:(FFGLPluginInstance)instance;
@end