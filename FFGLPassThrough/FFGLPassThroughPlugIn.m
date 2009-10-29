//
//  FFGLPassThroughPlugIn.m
//  FFGLPassThrough
//
//  Created by Tom on 29/10/2009.
//  Copyright (c) 2009 Tom Butterworth. All rights reserved.
//

/* It's highly recommended to use CGL macros instead of changing the current context for plug-ins that perform OpenGL rendering */
#import <OpenGL/CGLMacro.h>
#import <VVFFGL/VVFFGL.h>
#import "FFGLPassThroughPlugIn.h"

#define	kQCPlugIn_Name				@"FFGLPassThrough"
#define	kQCPlugIn_Description		@"FFGL Pass-through plugin."

static void FFImageUnlockTexture(CGLContextObj cgl_ctx, GLuint name, void* context)
{
    [(FFGLImage *)context unlockTextureRectRepresentation];
    [(FFGLImage *)context release];
}

@implementation FFGLPassThroughPlugIn

/*
Here you need to declare the input / output properties as dynamic as Quartz Composer will handle their implementation
@dynamic inputFoo, outputBar;
*/
@dynamic inputImage, outputImage;

+ (NSDictionary*) attributes
{
	/*
	Return a dictionary of attributes describing the plug-in (QCPlugInAttributeNameKey, QCPlugInAttributeDescriptionKey...).
	*/
	
	return [NSDictionary dictionaryWithObjectsAndKeys:kQCPlugIn_Name, QCPlugInAttributeNameKey, kQCPlugIn_Description, QCPlugInAttributeDescriptionKey, nil];
}

+ (NSDictionary*) attributesForPropertyPortWithKey:(NSString*)key
{
	/*
	Specify the optional attributes for property based ports (QCPortAttributeNameKey, QCPortAttributeDefaultValueKey...).
	*/
	
	return nil;
}

+ (QCPlugInExecutionMode) executionMode
{
	/*
	Return the execution mode of the plug-in: kQCPlugInExecutionModeProvider, kQCPlugInExecutionModeProcessor, or kQCPlugInExecutionModeConsumer.
	*/
	
	return kQCPlugInExecutionModeProcessor;
}

+ (QCPlugInTimeMode) timeMode
{
	/*
	Return the time dependency mode of the plug-in: kQCPlugInTimeModeNone, kQCPlugInTimeModeIdle or kQCPlugInTimeModeTimeBase.
	*/
	
	return kQCPlugInTimeModeNone;
}

- (id) init
{
	if(self = [super init]) {
		/*
		Allocate any permanent resource required by the plug-in.
		*/
	    _cspace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
	}
	
	return self;
}

- (void) finalize
{
	/*
	Release any non garbage collected resources created in -init.
	*/
	CGColorSpaceRelease(_cspace);
	[super finalize];
}

- (void) dealloc
{
	/*
	Release any resources created in -init.
	*/
	CGColorSpaceRelease(_cspace);
	[super dealloc];
}

@end

@implementation FFGLPassThroughPlugIn (Execution)

- (BOOL) startExecution:(id<QCPlugInContext>)context
{
	/*
	Called by Quartz Composer when rendering of the composition starts: perform any required setup for the plug-in.
	Return NO in case of fatal failure (this will prevent rendering of the composition to start).
	*/
	
	return YES;
}

- (void) enableExecution:(id<QCPlugInContext>)context
{
	/*
	Called by Quartz Composer when the plug-in instance starts being used by Quartz Composer.
	*/
}

- (BOOL) execute:(id<QCPlugInContext>)context atTime:(NSTimeInterval)time withArguments:(NSDictionary*)arguments
{
	/*
	Called by Quartz Composer whenever the plug-in instance needs to execute.
	Only read from the plug-in inputs and produce a result (by writing to the plug-in outputs or rendering to the destination OpenGL context) within that method and nowhere else.
	Return NO in case of failure during the execution (this will prevent rendering of the current frame to complete).
	
	The OpenGL context for rendering can be accessed and defined for CGL macros using:
	CGLContextObj cgl_ctx = [context CGLContextObj];
	*/
	CGLContextObj cgl_ctx = [context CGLContextObj];

	if ([self didValueForInputKeyChange:@"inputImage"]) {
	    id <QCPlugInInputImageSource> input = self.inputImage;
	    if ([input lockTextureRepresentationWithColorSpace:_cspace forBounds:[input imageBounds]])
	    {
		[input bindTextureRepresentationToCGLContext:cgl_ctx textureUnit:GL_TEXTURE0 normalizeCoordinates:NO];
		FFGLImage *output = [[FFGLImage alloc] initWithCopiedTextureRect:[input textureName]
								      CGLContext:cgl_ctx
								      pixelsWide:[input texturePixelsWide]
								      pixelsHigh:[input texturePixelsHigh]];
		[input unbindTextureRepresentationFromCGLContext:cgl_ctx textureUnit:GL_TEXTURE0];
		[input unlockTextureRepresentation];
    #if __BIG_ENDIAN__
		NSString *qcPixelFormat = QCPlugInPixelFormatARGB8;
    #else
		NSString *qcPixelFormat = QCPlugInPixelFormatBGRA8;
    #endif
		if ([output lockTextureRectRepresentation])
		{     
		    self.outputImage = [context outputImageProviderFromTextureWithPixelFormat:qcPixelFormat
										   pixelsWide:[output textureRectPixelsWide]
										   pixelsHigh:[output textureRectPixelsHigh]
											 name:[output textureRectName]
										      flipped:NO
									      releaseCallback:FFImageUnlockTexture
									       releaseContext:output
										   colorSpace:_cspace
									     shouldColorMatch:YES];		    
		} else {
		    NSLog(@"FFGLImage creation or locking failed");
		}

	    }
	    
	}
	return YES;
}

- (void) disableExecution:(id<QCPlugInContext>)context
{
	/*
	Called by Quartz Composer when the plug-in instance stops being used by Quartz Composer.
	*/
}

- (void) stopExecution:(id<QCPlugInContext>)context
{
	/*
	Called by Quartz Composer when rendering of the composition stops: perform any required cleanup for the plug-in.
	*/
}

@end
