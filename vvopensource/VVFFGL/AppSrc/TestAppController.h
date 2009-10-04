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
#import "RenderView.h"
#import "RenderChain.h"

@interface TestAppController : NSObject 
{
	// FFGL plugin manager from IB
    // This is a singleton object, so we can get it with [FFGLPluginManager sharedManager]
//	IBOutlet FFGLPluginManager* ffglManager;
	
	// our plugin renderer. Render an instance of a plugin to our GL Context
//	FFGLRenderer* ffglRenderRenderer; // yea, this needs a better name.
        RenderChain *_chain;
	// context, view and window
        IBOutlet NSTableView *_sourcesTableView;
        IBOutlet NSTableView *_effectsTableView;
	IBOutlet RenderView *_renderView;
	IBOutlet NSWindow* ffglRenderWindow;

	// render timer
	NSTimer* ffglRenderTimer;
	NSTimeInterval _renderStart;
}
- (IBAction)addRendererFromTableView:(id)sender;
@end
