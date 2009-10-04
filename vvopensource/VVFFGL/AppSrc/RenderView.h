//
//  RenderView.h
//  VVOpenSource
//
//  Created by Tom on 22/09/2009.
//  Copyright 2009 Tom Butterworth. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>
//#import "RenderChain.h"

@interface RenderView : NSOpenGLView {
//    RenderChain *_chain;
    BOOL _needsReshape;
}
//@property (retain, readwrite) RenderChain *renderChain;
@end
