//
//  FFGLRenderer.h
//  VVOpenSource
//
//  Created by Tom on 24/07/2009.
//

#import <Cocoa/Cocoa.h>
#import <OpenGL/OpenGL.h>

#ifndef NS_RETURNS_RETAINED
#if defined(__clang__)
#define NS_RETURNS_RETAINED __attribute__((ns_returns_retained))
#else
#define NS_RETURNS_RETAINED
#endif
#endif

@class FFGLPlugin, FFGLImage;



/**
@defgroup FFGLRendererConstants
@{
*/

/**
Used to describe the intended output type of an FFGLRenderer
*/
typedef enum {
    FFGLRendererHintNone = 0,		/*!<	No rendering hint; default will be used.		*/
    FFGLRendererHintTextureRect = 1,	/*!<	The renderer will try to optimize for rectangular textures	*/
    FFGLRendererHintTexture2D = 2,	/*!<	The renderer will try to optimize for 2D (square) textures	*/
    FFGLRendererHintBuffer = 3	/*!<	The renderer will try to optimize for CPU-based output	*/
} FFGLRendererHint;
/**
@}
*/



///	Object which renders and lets you communicate with an FFGLPlugin instance
/**
FFGLRenderer is conceptually and behaviorally similar to QCRenderer.  The general workflow is that you create a FFGLPlugin instance, then create an FFGLRenderer from that plugin instance and an OpenGL context.  The FFGLRenderer is what you send/receive values to/from, and is what actually does the rendering (it outputs FFGLImage instances).  In addition to FFGLImage, this is another high-level and important class that you will probably use a lot.
<BR><BR>There are some FFGLRenderer-related constants listed in the @ref FFGLRendererConstants section.
*/
@interface FFGLRenderer : NSObject
{
@protected
    FFGLRendererHint	_outputHint;
    FFGLPlugin          *_plugin;
    CGLContextObj       cgl_ctx;
    NSSize              _size;
    NSString            *_pixelFormat;
    void                *_instance;
	FFGLImage			**_inputs;
@private
	void				*_private;
}
/*!
    Initializes a new renderer.
	@param plugin should be the FFGLPlugin to use for rendering.
	@param context should be the CGLContext to use for rendering. See renderAtTime: below for guidance on using CGLContexts.
	@param pixelFormat must be one of the pixel-formats supported by plugin. If plugin is a GPU plugin, pixelFormat may be nil.
	@param  hint should indicate your intentions for the output, and may be used to provide an FFGLImage optimized to suit.  If you are passing the output of one FFGLRenderer into another FFGLRenderer as input for an image parameter, use FFGLRendererHintNone.
	@param size determines the dimensions of output frames. For CPU plugins, input frames must also match these dimensions.
*/
- (id)initWithPlugin:(FFGLPlugin *)plugin context:(CGLContextObj)context pixelFormat:(NSString *)format outputHint:(FFGLRendererHint)hint size:(NSSize)size;

@property (readonly) FFGLPlugin *plugin;

@property (readonly) CGLContextObj context;

@property (readonly) NSString *pixelFormat;

@property (readonly) NSSize size;

@property (readonly) FFGLRendererHint outputHint;

/*!
    A plugin may ignore some of its image parameters under certain conditions. Use this method to discover if an input will be used with the parameters in their current state.
 */
- (BOOL)willUseParameterKey:(NSString *)key;

/*!
	Sets the value of the named parameter.<BR>
	For boolean parameters, value should be a NSNumber with a boolean value.<BR>
	For number parameters, value should be a NSNumber with a float value between 0.0 and 1.0.<BR>
	For string parameters, value should be a NSString.<BR>
	For image parameters, value should be a FFGLImage. For CPU-mode plugins, the image's dimensions must match the renderer's dimensions.<BR>
	@param key should be one of the keys obtained by a call to the FFGLRenderer's plugin's parameterKeys method.
 */
- (void)setValue:(id)value forParameterKey:(NSString *)key;

- (id)valueForParameterKey:(NSString *)key;

/*!
	Returns an object interested parties can bind to to get/set parameter values. Bind to aRenderer.parameters.aKey  Note that although the parameters object itself is readonly, the values for the keys are read-write.
 */
@property (readonly) id parameters;

/*!
	Attempts to perform rendering using the currently set parameters at the specified time.  Returns an FFGLImage if rendering succeeded, nil otherwise. You are responsible for releasing this image when you no longer need it.<BR>
	Rendering may fail if insufficient image parameters are set, if image parameters are set but they couldn't be used by the renderer, or for other reasons.<BR>
	FreeFrame GL plugins require OpenGL be in its default state before rendering. If the CGLContext used by the FFGLRenderer is the same as is used by your drawing code, take care to restore the GL state after you make OpenGL calls. Alternatively, create a seperate CGLContext shared with your drawing context to use with your FFGLRenderers. FFGL takes care to restore OpenGL state and multiple FFGLRenderers and FFGLImages can share a single CGLContext.<BR>
	Note that if you are rendering a long chain of FFGLRenderers which share a CGLContext, making that context current (using CGLSetCurrentContext()) before rendering them will save the FFGLRenderers from having to switch and restore the current context for every render pass. This step is not necessary, but may improve performance.
 */
- (FFGLImage *)createOutputAtTime:(NSTimeInterval)time NS_RETURNS_RETAINED;
@end
