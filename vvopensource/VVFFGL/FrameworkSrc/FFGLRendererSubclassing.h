/*
 *  FFGLRendererSubclassing.h
 *  VVOpenSource
 *
 *  Created by Tom on 25/08/2009.
 *  Copyright 2009 Tom Butterworth. All rights reserved.
 *
 */

#import <Cocoa/Cocoa.h>
#import "FFGLRenderer.h"
#import "FFGLPluginInstances.h"

/*
 Is this getting complicated? Suggestions for simplifying things more than welcome...
 */

@interface FFGLRenderer (Subclassing)
/* This method is provided by FFGLRenderer for subclasses to use when calling FFGLPlugin's instance methods */
- (FFGLPluginInstance)_instance;

/* Subclasses must implement these methods */
- (void)_setImage:(id)image forInputAtIndex:(NSUInteger)index;
- (void)_render;
@end
