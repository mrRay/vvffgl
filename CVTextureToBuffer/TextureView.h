//
//  TextureView.h
//  CVTextureToBuffer
//
//  Created by Tom on 01/03/2010.
//  Copyright 2010 Tom Butterworth. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <OpenGL/OpenGL.h>

@interface TextureView : NSOpenGLView {
	GLint _tex;
	float _width;
	float _height;
	BOOL _needsReshape;
}
- (void)setTextureName:(GLint)texName width:(float)texWidth height:(float)texHeight;
@end
