//
//  FFGLTestAppController.h
//  VVOpenSource
//
//  Created by vade on 10/4/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <OpenGL/OpenGL.h>


@interface FFGLTestAppController : NSObject 
{
	NSOpenGLContext* ffglRenderContext;
	IBOutlet NSView* ffglRenderView;
	IBOutlet NSWindow* ffglRenderWindow;
}

@end
