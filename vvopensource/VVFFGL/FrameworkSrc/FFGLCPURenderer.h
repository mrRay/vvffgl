//
//  FFGLCPURenderer.h
//  VVOpenSource
//
//  Created by Tom on 10/08/2009.
//

#import <Cocoa/Cocoa.h>
#import "FFGLRenderer.h"
//#import "FFGLPluginInstances.h"
#import "FFGLInternal.h"

@interface FFGLCPURenderer : FFGLRenderer {
    void **_buffers;
    FFGLProcessFrameCopyStruct _fcStruct;
    BOOL _frameCopies;
    NSUInteger _bpp;
}

@end
