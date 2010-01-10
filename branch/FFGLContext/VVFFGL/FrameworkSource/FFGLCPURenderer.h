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
    size_t _bytesPerRow;
	size_t _bytesPerBuffer;
#if defined(FFGL_USE_BUFFER_POOLS)
	FFGLPoolRef _pool;
#endif /* FFGL_USE_BUFFER_POOLS */
}

@end
