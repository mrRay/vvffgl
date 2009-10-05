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

@class FFGLImage;

@interface FFGLRenderer (Subclassing)
/* This method is provided by FFGLRenderer for subclasses to use when calling FFGLPlugin's instance methods */
- (FFGLPluginInstance)_instance;

/* Subclasses must implement these methods */
- (void)_implementationSetImage:(FFGLImage *)image forInputAtIndex:(NSUInteger)index;
- (void)_implementationRender;

/* Subclasses should emit output after render using this */
- (void)setOutputImage:(FFGLImage *)image; // using a setter for our public outputImage method makes it play friendly with KVO.
@end
