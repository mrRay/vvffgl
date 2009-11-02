//
//  FFGLRenderer.h
//  VVOpenSource
//
//  Created by Tom on 24/07/2009.
//

#import <Cocoa/Cocoa.h>
#import <OpenGL/OpenGL.h>
#import <libkern/OSAtomic.h>
#import <pthread.h> // maybe obscure our ivars in a struct and move this to the .m?

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
// TOM, you will probably hate this, but just for me dicking around...
    // ANTON, ha, let's roll with it, saves duplicating it all in subclasses.
@protected
    FFGLRendererHint	_outputHint;
    FFGLPlugin          *_plugin;
    CGLContextObj       _context;
    NSRect              _bounds;
    NSString            *_pixelFormat;
    void		*_instance;
@private
    NSMutableDictionary *_imageInputs;
    BOOL                _needsToCheckValidity;
    BOOL                *_imageInputValidity;
    FFGLImage           *_output;
    id                  _params;
    pthread_mutex_t     _lock;
    OSSpinLock		_pLock;
}
- (id)initWithPlugin:(FFGLPlugin *)plugin context:(CGLContextObj)context pixelFormat:(NSString *)format outputHint:(FFGLRendererHint)hint forBounds:(NSRect)bounds;
- (FFGLPlugin *)plugin;
- (CGLContextObj)context;
- (NSString *)pixelFormat;
- (NSRect)bounds;
- (FFGLRendererHint)outputHint;
/*
 - (BOOL)willUseParameterKey:(NSString *)key
    A plugin may ignore some of its image parameters under certain conditions. Use this method to discover if an input
    will be used with the parameters in their current state.
 */
- (BOOL)willUseParameterKey:(NSString *)key;
- (id)valueForParameterKey:(NSString *)key;
- (void)setValue:(id)value forParameterKey:(NSString *)key;
/*
 - (id)parameters
    Returns an object interested parties can bind to to get/set parameter values. Bind to aRenderer.parameters.aKey
 */
- (id)parameters;
- (FFGLImage *)outputImage;
- (BOOL)renderAtTime:(NSTimeInterval)time;
@end
