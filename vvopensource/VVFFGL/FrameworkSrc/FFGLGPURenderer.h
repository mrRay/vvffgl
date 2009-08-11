//
//  FFGLGPURenderer.h
//  VVOpenSource
//
//  Created by Tom on 10/08/2009.
//  Copyright 2009 Tom Butterworth. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "FFGLRenderer.h"

typedef struct FFGLGPURendererData FFGLGPURendererData;

@interface FFGLGPURenderer : FFGLRenderer {
    FFGLGPURendererData *_data;
}

@end
