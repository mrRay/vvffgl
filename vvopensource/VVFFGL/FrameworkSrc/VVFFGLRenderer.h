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
	CGLContextObj _pluginContext;
	
}
- (id)initWithPlugin:(VVFFGLPlugin *)plugin;

- (void)setCGLContext:(CGLContextObj)cgl_ctx;
@end
