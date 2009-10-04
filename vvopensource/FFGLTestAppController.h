//
//  FFGLTestAppController.h
//  VVOpenSource
//
//  Created by vade on 10/4/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <OpenGL/OpenGL.h>
#import "VVFFGL.h"

@interface FFGLTestAppController : NSObject 
{
	// FFGL plugin manager from IB
	IBOutlet FFGLPluginManager* ffglManager;
	
	// our plugin renderer. Render an instance of a plugin to our GL Context
	FFGLRenderer* ffglRenderRenderer; // yea, this needs a better name.
	
	// context, view and window
	NSOpenGLContext* ffglRenderContext;
	IBOutlet NSView* ffglRenderView;
	IBOutlet NSWindow* ffglRenderWindow;

	// render timer
	NSTimer* ffglRenderTimer;
	NSTimeInterval* ffglRenderTimerStartInterval;
}

// render method
- (void) render;

// window resize notification handler and gl handler
- (void) updateRenderView:(NSNotification *) notification;

@end
