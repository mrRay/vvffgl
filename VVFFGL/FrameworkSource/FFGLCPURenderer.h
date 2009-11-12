//
//  FFGLCPURenderer.h
//  VVOpenSource
//
//  Created by Tom on 10/08/2009.
//

#import <Cocoa/Cocoa.h>
#import "FFGLRenderer.h"
#import "FFGLInternal.h"
#import "FFGLPool.h"

@interface FFGLCPURenderer : FFGLRenderer {
    void **_buffers;
    FFGLProcessFrameCopyStruct _fcStruct;
    BOOL _frameCopies;
    NSUInteger _bytesPerRow;
    size_t _bytesPerBuffer;
    FFGLPoolRef _pool;
}

@end
