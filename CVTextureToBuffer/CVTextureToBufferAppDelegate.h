//
//  CVTextureToBufferAppDelegate.h
//  CVTextureToBuffer
//
//  Created by Tom on 26/02/2010.
//  Copyright 2010 Tom Butterworth. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <QuickTime/QuickTime.h>
#import <QTKit/QTKit.h>
#import <OpenGL/OpenGL.h>
#import "TextureView.h"

@interface CVTextureToBufferAppDelegate : NSObject {
	TextureView *_view;

	CGLContextObj cgl_ctx;
	QTVisualContextRef _QTContext;
	QTMovie *_movie;
	NSTimer *_timer;
	uint8_t *_greenBufferSource;
	GLuint _greenTexture;
	CVOpenGLTextureRef _textureRef;
	BOOL _doesBuffer;
	NSUInteger _source;
	uint8_t *_buffer;
	GLuint _bufferTexture;
	NSString *_moviePath;
}
@property (assign) IBOutlet TextureView *view;
@property (assign) BOOL performsBufferStage;
@property (assign) NSUInteger source;
@property (retain) NSString *moviePath;
@end
