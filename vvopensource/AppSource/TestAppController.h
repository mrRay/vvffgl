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
#import "ParametersView.h"
#import "RenderChain.h"

@interface TestAppController : NSObject 
{
        RenderChain *_chain;
        IBOutlet NSTableView *_sourcesTableView;
        IBOutlet NSTableView *_effectsTableView;
	IBOutlet RenderView *_renderView;
        IBOutlet ParametersView *_paramsView;
        IBOutlet NSArrayController *_renderChainRenderersController; // frickin bindings, ugh.
	// render timer
	NSTimer* ffglRenderTimer;
	NSTimeInterval  _renderStart;
        NSTimeInterval  _fpsStart;
        NSUInteger      _frameCount;
        double          _fps;
}
- (IBAction)addRendererFromTableView:(id)sender;
- (RenderChain *)renderChain;
@property (readwrite, assign) double FPS;
@end
