//
//  FFGLCPURenderer.h
//  VVOpenSource
//
//  Created by Tom on 10/08/2009.
//

#import <Cocoa/Cocoa.h>
#import "FFGLRenderer.h"
#import "FFGL.h"

@interface FFGLCPURenderer : FFGLRenderer {
    void **_buffers;
    ProcessFrameCopyStruct _fcStruct;
    BOOL _frameCopies;
}

@end
