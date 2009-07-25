//
//  VVFFGLRenderer.h
//  VVOpenSource
//
//  Created by Tom on 24/07/2009.
//  Copyright 2009 Tom Butterworth. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <OpenGL/OpenGL.h>

@class VVFFGLPlugin;

@interface VVFFGLRenderer : NSObject {
@private
    VVFFGLPlugin *_plugin;
	NSUInteger _pluginInstanceIdentifier;
	CGLContextObj _pluginContext;
	
	// needed to initialize GPU or CPU plugins.
	FFGLViewportStruct _pluginViewport;
	VideoInfoStruct _pluginVideoInfo;
}

// for CPU effects/sources, the last two arguments can be nil.
//
// for GPU effects/sources, they are required.
// context should be set and stick around for the duration of the pluginRenderers lifetime
// if the context changes for whatever reason, probably should re-make the object
// need to pass in a viewport stuct

- (id)initWithPlugin:(VVFFGLPlugin *)plugin context(CGLContextObj)cgl_ctx viewport:(FFGLViewportStruct) vp;

@end
