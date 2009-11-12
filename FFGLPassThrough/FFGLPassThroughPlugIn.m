//
//  FFGLPassThroughPlugIn.m
//  FFGLPassThrough
//
//  Created by Tom on 29/10/2009.
//  Copyright (c) 2009 Tom Butterworth. All rights reserved.
//

/* It's highly recommended to use CGL macros instead of changing the current context for plug-ins that perform OpenGL rendering */
//#import <OpenGL/CGLMacro.h>
#import <VVFFGL/VVFFGL.h>
#import "FFGLPassThroughPlugIn.h"

#define	kQCPlugIn_Name				@"FFGLPassThrough"
#define	kQCPlugIn_Description		@"FFGL Pass-through plugin."

static void FFImageUnlockTextureAndRelease(CGLContextObj cgl_ctx, GLuint name, void* context)
{
    [(FFGLImage *)context unlockTextureRectRepresentation];
    [(FFGLImage *)context release];
}

static void FFGLImageUnlockBufferAndRelease(const void *buffer, void *context)
{
	[(FFGLImage *)context unlockBufferRepresentation];
    [(FFGLImage *)context release];
}
@implementation FFGLPassThroughPlugIn

/*
Here you need to declare the input / output properties as dynamic as Quartz Composer will handle their implementation
@dynamic inputFoo, outputBar;
*/
@dynamic inputImage, inputMode, inputFlipped, outputImage;

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
	if ([key isEqualToString:@"inputImage"])
		return [NSDictionary dictionaryWithObject:@"Image" forKey:QCPortAttributeNameKey];
	else if ([key isEqualToString:@"inputMode"])
		return [NSDictionary dictionaryWithObjectsAndKeys:@"Mode", QCPortAttributeNameKey, [NSNumber numberWithUnsignedInt:0], QCPortAttributeMinimumValueKey,
				[NSNumber numberWithUnsignedInt:1], QCPortAttributeMaximumValueKey, [NSArray arrayWithObjects:@"OpenGL", @"Memory", nil], QCPortAttributeMenuItemsKey,
				[NSNumber numberWithUnsignedInt:0], QCPortAttributeDefaultValueKey, nil];
	else if ([key isEqualToString:@"inputFlipped"])
		return [NSDictionary dictionaryWithObjectsAndKeys:@"Flipped", QCPortAttributeNameKey, [NSNumber numberWithBool:NO], QCPortAttributeDefaultValueKey, nil];
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

	CGLSetCurrentContext(cgl_ctx);
	
	if ([self didValueForInputKeyChange:@"inputImage"])
	{
#if __BIG_ENDIAN__
		NSString *qcPixelFormat = QCPlugInPixelFormatARGB8;
		NSString *ffPixelFormat = FFGLPixelFormatARGB8888;
#else
		NSString *qcPixelFormat = QCPlugInPixelFormatBGRA8;
		NSString *ffPixelFormat = FFGLPixelFormatBGRA8888;
#endif
	    id <QCPlugInInputImageSource> input = self.inputImage;
		if (self.inputMode == 0)
		{
			if ([input lockTextureRepresentationWithColorSpace:_cspace forBounds:[input imageBounds]])
			{
				[input bindTextureRepresentationToCGLContext:cgl_ctx textureUnit:GL_TEXTURE0 normalizeCoordinates:NO];
				FFGLImage *output = [[FFGLImage alloc] initWithCopiedTextureRect:[input textureName]
																	  CGLContext:cgl_ctx
																	  pixelsWide:[input texturePixelsWide]
																	  pixelsHigh:[input texturePixelsHigh]
																		 flipped:(self.inputFlipped ? ![input textureFlipped] : [input textureFlipped])];
				[input unbindTextureRepresentationFromCGLContext:cgl_ctx textureUnit:GL_TEXTURE0];
				[input unlockTextureRepresentation];

				if ([output lockTextureRectRepresentation])
				{     
					self.outputImage = [context outputImageProviderFromTextureWithPixelFormat:qcPixelFormat
																				   pixelsWide:[output textureRectPixelsWide]
																				   pixelsHigh:[output textureRectPixelsHigh]
																						 name:[output textureRectName]
																					  flipped:NO
																			  releaseCallback:FFImageUnlockTextureAndRelease
																			   releaseContext:output
																				   colorSpace:_cspace
																			 shouldColorMatch:YES];		    
				} 
				else 
				{
					NSLog(@"FFGLImage creation or locking failed");
				}

			}
		}
		else
		{
			if ([input lockBufferRepresentationWithPixelFormat:qcPixelFormat colorSpace:_cspace forBounds:[input imageBounds]])
			{
				FFGLImage *output = [[FFGLImage alloc] initWithCopiedBuffer:[input bufferBaseAddress]
																 CGLContext:cgl_ctx
																pixelFormat:ffPixelFormat
																 pixelsWide:[input bufferPixelsWide]
																 pixelsHigh:[input bufferPixelsHigh]
																bytesPerRow:[input bufferBytesPerRow]
																	flipped:(self.inputFlipped ? YES : NO)];
				[input unlockBufferRepresentation];
				
				if ([output lockBufferRepresentationWithPixelFormat:ffPixelFormat])
				{
					self.outputImage = [context outputImageProviderFromBufferWithPixelFormat:qcPixelFormat
																				  pixelsWide:[output bufferPixelsWide]
																				  pixelsHigh:[output bufferPixelsHigh]
																				 baseAddress:[output bufferBaseAddress]
																				 bytesPerRow:[output bufferBytesPerRow]
																			 releaseCallback:FFGLImageUnlockBufferAndRelease
																			  releaseContext:output
																				  colorSpace:_cspace
																			shouldColorMatch:YES];
				}
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
