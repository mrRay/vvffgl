//
//  ParametersView.h
//  VVOpenSource
//
//  Created by Tom on 02/10/2009.
//  Copyright 2009 Tom Butterworth. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <VVFFGL/VVFFGL.h>

@interface ParametersView : NSView {
    FFGLRenderer *_renderer;
}
- (FFGLRenderer *)renderer;
- (void)setRenderer:(FFGLRenderer *)renderer;
@end
