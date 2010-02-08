//
//  FFGLRenderer.h
//  VVOpenSource
//
//  Created by Tom on 24/07/2009.
//

#import <Cocoa/Cocoa.h>
#import <OpenGL/OpenGL.h>

@class FFGLPlugin, FFGLImage;

enum {
    FFGLRendererHintNone = 0,
    FFGLRendererHintTextureRect = 1,
    FFGLRendererHintTexture2D = 2,
    FFGLRendererHintBuffer = 3
};
typedef NSUInteger FFGLRendererHint;

@interface FFGLRenderer : NSObject
{
@protected
    FFGLRendererHint	_outputHint;
    FFGLPlugin          *_plugin;
    CGLContextObj       _context;
    NSSize              _size;
    NSString            *_pixelFormat;
    void                *_instance;
@private
	void				*_private;
}
/*
 - (id)initWithPlugin:(FFGLPlugin *)plugin context:(CGLContextObj)context pixelFormat:(NSString *)format outputHint:(FFGLRendererHint)hint size:(NSSize)size
    Initializes a new renderer.
	plugin should be the FFGLPlugin to use for rendering.
	context should be the CGLContext to use for rendering. See renderAtTime: below for guidance on using CGLContexts.
    pixelFormat must be one of the pixel-formats supported by plugin. If plugin is a GPU plugin, pixelFormat may be nil.
    hint should indicate your intentions for the output, and may be used to provide an FFGLImage optimized to suit.
    If you are passing the output of one FFGLRenderer into another FFGLRenderer as input for an image parameter, use FFGLRendererHintNone.
    size determines the dimensions of output frames. For CPU plugins, input frames must also match these dimensions.
*/
- (id)initWithPlugin:(FFGLPlugin *)plugin context:(CGLContextObj)context pixelFormat:(NSString *)format outputHint:(FFGLRendererHint)hint size:(NSSize)size;

@property (readonly) FFGLPlugin *plugin;

@property (readonly) CGLContextObj context;

@property (readonly) NSString *pixelFormat;

@property (readonly) NSSize size;

@property (readonly) FFGLRendererHint outputHint;

/*
 - (BOOL)willUseParameterKey:(NSString *)key
    A plugin may ignore some of its image parameters under certain conditions. Use this method to discover if an input
    will be used with the parameters in their current state.
 */
- (BOOL)willUseParameterKey:(NSString *)key;

/*
 - (void)setValue:(id)value forParameterKey:(NSString *)key

	Sets the value of the named parameter.
	For boolean parameters, value should be a NSNumber with a boolean value.
	For number parameters, value should be a NSNumber with a float value between 0.0 and 1.0.
	For string parameters, value should be a NSString.
	For image parameters, value should be a FFGLImage. For CPU-mode plugins, the image's dimensions must match
	the renderer's dimensions.
	key should be one of the keys obtained by a call to the FFGLRenderer's plugin's parameterKeys method.
 */
- (void)setValue:(id)value forParameterKey:(NSString *)key;

- (id)valueForParameterKey:(NSString *)key;

/*
 @property (readonly) id parameters
    Returns an object interested parties can bind to to get/set parameter values. Bind to aRenderer.parameters.aKey
	Note that although the parameters object itself is readonly, the values for the keys are read-write.
 */
@property (readonly) id parameters;

/*
 @property (readonly) FFGLImage *outputImage
	Returns the product of the last call to renderAtTime: if such a call was made and succeeded, otherwise nil.
 */
@property (readonly) FFGLImage *outputImage;

/*
 - (BOOL)renderAtTime:(NSTimeInterval)time
	Attempts to perform rendering using the currently set parameters at the specified time.
	Returns YES if rendering succeeded, NO otherwise.
 
	Rendering may fail if insufficient image parameters are set, if image parameters are set but they couldn't be used by
	the renderer, or for other reasons.
	
	FreeFrame GL plugins require OpenGL be in its default state before rendering. If the CGLContext used by the FFGLRenderer is the same as
	is used by your drawing code, take care to restore the GL state after you make OpenGL calls. Alternatively, create a seperate CGLContext
	shared with your drawing context to use with your FFGLRenderers. FFGL takes care to restore OpenGL state and multiple FFGLRenderers and FFGLImages can
	share a single CGLContext.
	
	Note that if you are rendering a long chain of FFGLRenderers which share a CGLContext, making that context current (using CGLSetCurrentContext())
	before rendering them will save the FFGLRenderers from having to switch and restore the current context for every render pass. This step is not
	necessary, but may improve performance.
 */
- (BOOL)renderAtTime:(NSTimeInterval)time;
@end
