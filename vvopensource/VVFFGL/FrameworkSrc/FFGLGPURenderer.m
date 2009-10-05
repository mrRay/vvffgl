//
//  FFGLGPURenderer.m
//  VVOpenSource
//
//  Created by Tom on 10/08/2009.
//

#import "FFGLGPURenderer.h"
#import "FFGLRendererSubclassing.h"
#import "FFGLImage.h"
#import <OpenGL/CGLMacro.h>

@implementation FFGLGPURenderer
- (id)init
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (id)initWithPlugin:(FFGLPlugin *)plugin context:(CGLContextObj)cgl_ctx bounds:(NSRect)bounds;
{
    if (self = [super initWithPlugin:plugin context:cgl_ctx forBounds:bounds]) {
        
        // this rightnow is totally dependant on how we end up exposing the instantiate functions for the plugin, 
        // but we will need something like this somewhere. Feel free to fiddle :)
		
		// retain GL context
		_context = cgl_ctx;
		CGLRetainContext(cgl_ctx);
		
        // set up our _frameStruct
        NSUInteger numInputs = [plugin _maximumInputFrameCount];
        _frameStruct.inputTextureCount = numInputs;
        NSUInteger i;
        NSUInteger allocated = 0;
        if (numInputs > 0) {
            _frameStruct.inputTextures = malloc(sizeof(void *) * numInputs);
            if (_frameStruct.inputTextures == NULL) {
                [self release];
                return nil;
            }
            for (i = 0; i < numInputs; i++) {
                _frameStruct.inputTextures[i] = malloc(sizeof(FFGLTextureInfo));
                if (_frameStruct.inputTextures[i] != NULL) {
                    allocated++;
                }
            }
            if (allocated != numInputs) {
                [self release];
                return nil;
            }
        } else {
            _frameStruct.inputTextures = NULL;
        }
        // TODO: do we need an FBO to reuse for rendering into our output texture?
    }
    return self;
}

- (void)nonGCCleanup
{
    // TODO: if we add an FBO in init, delete it here.
    CGLReleaseContext(_context);
    if (_frameStruct.inputTextures != NULL) {
        NSUInteger i;
        for (i = 0; i < _frameStruct.inputTextureCount; i++) {
            if (_frameStruct.inputTextures[i] != NULL) {
                free(_frameStruct.inputTextures[i]);
            }
        }
        free(_frameStruct.inputTextures);
    }    
}

- (void)dealloc
{
    [self nonGCCleanup];
    [super dealloc];
}

- (void)finalize
{
    [self nonGCCleanup];
    [super finalize];
}

- (void)_implementationSetImage:(FFGLImage *)image forInputAtIndex:(NSUInteger)index
{
    if ([image lockTexture2DRepresentation]) {
        _frameStruct.inputTextures[index]->texture = [image texture2DName];
        _frameStruct.inputTextures[index]->width = [image imagePixelsWide];
        _frameStruct.inputTextures[index]->height = [image imagePixelsHigh];
        _frameStruct.inputTextures[index]->hardwareWidth = [image texture2DPixelsWide];
        _frameStruct.inputTextures[index]->hardwareHeight = [image texture2DPixelsHigh];
    }
}

- (void)_render
{
	CGLContextObj cgl_ctx = _context;
	CGLLockContext(cgl_ctx);
    
    // TODO: need to set output, bind FBO so we render in output's texture, register FBO in _frameStruct, then do this:
//    _frameStruct.hostFBO = whatever; // or if we reuse the same FBO, do this once in init, and not here.
    [[self plugin] _processFrameGL:&_frameStruct forInstance:[self _instance]];
	
	CGLUnlockContext(cgl_ctx);
//    [self setOutputImage:output];
}

@end
