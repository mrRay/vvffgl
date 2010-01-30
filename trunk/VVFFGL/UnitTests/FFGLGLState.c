/*
 *  FFGLGLState.c
 *  VVFFGL
 *
 *  Created by Tom on 29/01/2010.
 *  Copyright 2010 Tom Butterworth. All rights reserved.
 *
 */

#include "FFGLGLState.h"
#import <OpenGL/CGLMacro.h>
#import <libkern/OSAtomic.h>
#import <stdlib.h>

#define kGLGetIntCount 23
#define kGLGetBoolCount 9
#define kGLGetTexParamIntCount 14
#define kGLTargetCount 2
#define kGLTargets GL_TEXTURE_2D, GL_TEXTURE_RECTANGLE_ARB

typedef struct GLState
{
    int32_t retainc;
	CGLContextObj context;
	GLint gotInts[kGLGetIntCount];
	GLboolean gotBools[kGLGetBoolCount];
	GLint gotTexParamInts[kGLGetTexParamIntCount * kGLTargetCount];
} GLState;

GLStateRef GLStateCreateForContext(CGLContextObj context)
{
	if (!context)
	{
		return NULL;
	}
	GLStateRef state = malloc(sizeof(GLState));
	if (state)
	{
		state->retainc = 1;
		state->context = CGLRetainContext(context);
		CGLLockContext(context);
		CGLContextObj cgl_ctx = context;
		GLenum getIntEnums[kGLGetIntCount] = {
			GL_PIXEL_PACK_BUFFER_BINDING,
			GL_PIXEL_UNPACK_BUFFER_BINDING,
			GL_PACK_SKIP_ROWS,
			GL_PACK_SKIP_PIXELS,
			GL_PACK_SKIP_IMAGES,
			GL_PACK_ALIGNMENT,
			GL_PACK_IMAGE_HEIGHT,
			GL_PACK_ROW_LENGTH,
			GL_UNPACK_ALIGNMENT,
			GL_UNPACK_ROW_LENGTH,
			GL_UNPACK_IMAGE_HEIGHT,
			GL_UNPACK_SKIP_IMAGES,
			GL_UNPACK_SKIP_PIXELS,
			GL_UNPACK_SKIP_ROWS,
			GL_TEXTURE_BINDING_2D,
			GL_TEXTURE_BINDING_RECTANGLE_ARB,
			GL_FRAMEBUFFER_BINDING_EXT,
			GL_RENDERBUFFER_BINDING_EXT,
			GL_READ_FRAMEBUFFER_BINDING_EXT,
			GL_DRAW_FRAMEBUFFER_BINDING_EXT,
			GL_MATRIX_MODE,
			GL_CLIENT_ACTIVE_TEXTURE,
			GL_ACTIVE_TEXTURE
			
		};
		
		for (int i = 0; i < kGLGetIntCount; i++) {
			glGetIntegerv(getIntEnums[i], &state->gotInts[i]);
		}
		
		GLenum getBoolEnums[kGLGetBoolCount] = {
			GL_PACK_SWAP_BYTES,
			GL_PACK_LSB_FIRST,
			GL_UNPACK_LSB_FIRST,
			GL_UNPACK_SWAP_BYTES,
			GL_UNPACK_CLIENT_STORAGE_APPLE,
			GL_TEXTURE_2D,
			GL_TEXTURE_RECTANGLE_ARB,
			GL_TEXTURE_COORD_ARRAY,
			GL_VERTEX_ARRAY
		};
		
		for (int i = 0; i < kGLGetBoolCount; i++) {
			glGetBooleanv(getBoolEnums[i], &state->gotBools[i]);
		}
		
		GLenum targets[kGLTargetCount] = {kGLTargets};
		GLenum getTexParamIntEnums[kGLGetTexParamIntCount] = {
			GL_TEXTURE_STORAGE_HINT_APPLE,
			GL_TEXTURE_RANGE_LENGTH_APPLE,
			GL_TEXTURE_MAG_FILTER,
			GL_TEXTURE_MIN_FILTER,
			GL_TEXTURE_MIN_LOD,
			GL_TEXTURE_MAX_LOD,
			GL_TEXTURE_BASE_LEVEL,
			GL_TEXTURE_MAX_LEVEL,
			GL_TEXTURE_WRAP_S,
			GL_TEXTURE_WRAP_T,
			GL_TEXTURE_WRAP_R,
			GL_TEXTURE_BORDER_COLOR,
			GL_TEXTURE_PRIORITY,
			GL_TEXTURE_RESIDENT
		};
		
		for (int i = 0; i < kGLTargetCount; i++) {
			for (int j = 0; j < kGLGetTexParamIntCount; j++) {
				glGetTexParameteriv(targets[i], getTexParamIntEnums[j], &state->gotTexParamInts[(i * kGLGetTexParamIntCount) + j]);
			}
		}
		CGLUnlockContext(context);
	}
	return state;
}

GLStateRef GLStateRetain(GLStateRef state)
{
	if (state)
	{
		OSAtomicIncrement32Barrier(&state->retainc);
	}
	return state;
}

void GLStateRelease(GLStateRef state)
{
	if (state)
	{
		if (OSAtomicDecrement32Barrier(&state->retainc) == 0)
		{
			CGLReleaseContext(state->context);
			free(state);
		}
	}
}

bool GLStatesAreEqual(GLStateRef a, GLStateRef b)
{
	for (int i = 0; i < kGLGetIntCount; i++) {
		if (a->gotInts[i] != b->gotInts[i])
			return false;
	}
	for (int i = 0; i < kGLGetBoolCount; i++) {
		if (a->gotBools[i] != b->gotBools[i])
			return false;
	}
	for (int i = 0; i < kGLTargetCount; i++) {
		for (int j = 0; j < kGLGetTexParamIntCount; j++) {
			if (a->gotTexParamInts[(i * kGLGetTexParamIntCount) + j] != b->gotTexParamInts[(i * kGLGetTexParamIntCount) + j])
				return false;
		}
	}
	return true;
}