/*
 *  FFGLGLState.h
 *  VVFFGL
 *
 *  Created by Tom on 29/01/2010.
 *  Copyright 2010 Tom Butterworth. All rights reserved.
 *
 */

#import <OpenGL/OpenGL.h>
#import <stdbool.h>

typedef struct GLState *GLStateRef;

GLStateRef GLStateCreateForContext(CGLContextObj context);
GLStateRef GLStateRetain(GLStateRef state);
void GLStateRelease(GLStateRef state);
bool GLStatesAreEqual(GLStateRef a, GLStateRef b);
