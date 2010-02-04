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

#define kGLGetEnumCount 248
#define kGLGetValueCount 346
#define kGLGetPointerCount 6
#define kGLGetTexParamIntCount 14
#define kGLGetTexParamPointerCount 1
#define kGLTargetCount 2
#define kGLTargets GL_TEXTURE_2D, GL_TEXTURE_RECTANGLE_ARB

typedef struct GLState
{
    int32_t retainc;
	CGLContextObj context;
	GLfloat gotValues[kGLGetValueCount];
	GLenum gotEnums[kGLGetValueCount];
	GLvoid *gotPointers[kGLGetPointerCount];
	GLenum gotPointerEnums[kGLGetPointerCount];
	GLint gotTexParamInts[kGLGetTexParamIntCount * kGLTargetCount];
	GLenum gotTexParamIntEnums[kGLGetTexParamIntCount * kGLTargetCount];
	GLvoid *gotTexParamPointers[kGLGetTexParamPointerCount * kGLTargetCount];
	GLenum gotTexParamPointerEnums[kGLGetTexParamPointerCount * kGLTargetCount];
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
		
		GLenum getEnums[kGLGetEnumCount * 2] = {
			GL_ACCUM_ALPHA_BITS, 1,
			GL_ACCUM_BLUE_BITS, 1,
			GL_ACCUM_CLEAR_VALUE, 4,
			GL_ACCUM_GREEN_BITS, 1,
			GL_ACCUM_RED_BITS, 1,
			GL_ACTIVE_TEXTURE, 1,
			GL_ALPHA_BIAS, 1,
			GL_ALPHA_SCALE, 1,
			GL_ALPHA_TEST, 1,
			GL_ALPHA_TEST_FUNC, 1,
			GL_ALPHA_TEST_REF, 1,
			GL_ATTRIB_STACK_DEPTH, 1,
			GL_AUTO_NORMAL, 1,
			GL_AUX_BUFFERS, 1, // ? params returns one value, the number of auxiliary color buffers. The initial value is 0.
			GL_BLEND, 1,
			GL_BLEND_COLOR, 4,
			GL_BLEND_DST, 1,
			GL_BLEND_EQUATION, 1,
			GL_BLEND_SRC, 1,
			GL_BLUE_BIAS, 1,
			GL_BLUE_BITS, 1, // ? params returns one value, the number of blue bitplanes in each color buffer.
			GL_BLUE_SCALE, 1,
			GL_CLIENT_ACTIVE_TEXTURE, 1,
			GL_CLIENT_ATTRIB_STACK_DEPTH, 1, // 24 enums, 30 values to here
			GL_COLOR_ARRAY, 1,
			GL_COLOR_ARRAY_SIZE, 1,
			GL_COLOR_ARRAY_STRIDE, 1,
			GL_COLOR_ARRAY_TYPE, 1,
			GL_COLOR_CLEAR_VALUE, 4,
			GL_COLOR_LOGIC_OP, 1,
			GL_COLOR_MATERIAL, 1,
			GL_COLOR_MATERIAL_FACE, 1,
			GL_COLOR_MATERIAL_PARAMETER, 1, // 42 values to here
			GL_COLOR_MATRIX, 16,
			GL_COLOR_TABLE, 1,
			GL_COLOR_WRITEMASK, 4,
			GL_CONVOLUTION_1D, 1,
			GL_CONVOLUTION_2D, 1,
			GL_CULL_FACE, 1,
			GL_CULL_FACE_MODE, 1,
			GL_CURRENT_COLOR, 4,
			GL_CURRENT_INDEX, 1,
			GL_CURRENT_NORMAL, 3,
			GL_CURRENT_RASTER_COLOR, 4,
			GL_CURRENT_RASTER_DISTANCE, 1, // 70 values to here
			GL_CURRENT_RASTER_INDEX, 1, 
			GL_CURRENT_RASTER_POSITION, 4,
			GL_CURRENT_RASTER_POSITION_VALID, 1,
			GL_CURRENT_RASTER_TEXTURE_COORDS, 4,
			GL_CURRENT_TEXTURE_COORDS, 4,
			GL_DEPTH_BIAS, 1,
			GL_DEPTH_BITS, 1, // ? params returns one value, the number of bitplanes in the depth buffer.
			GL_DEPTH_CLEAR_VALUE, 1,
			GL_DEPTH_FUNC, 1,
			GL_DEPTH_RANGE, 2,
			GL_DEPTH_SCALE, 1,
			GL_DEPTH_TEST, 1,
			GL_DEPTH_WRITEMASK, 1,
			GL_DITHER, 1,
			GL_DRAW_BUFFER, 1,
			GL_EDGE_FLAG, 1,
			GL_EDGE_FLAG_ARRAY, 1,
			GL_EDGE_FLAG_ARRAY_STRIDE, 1,
			GL_FEEDBACK_BUFFER_SIZE, 1,
			GL_FEEDBACK_BUFFER_TYPE, 1, // 100 values to here
			GL_FOG, 1,
			GL_FOG_COLOR, 4, // 67 enums to here, 105 values
			GL_FOG_DENSITY, 1,
			GL_FOG_END, 1,
			GL_FOG_HINT, 1,
			GL_FOG_INDEX, 1,
			GL_FOG_MODE, 1,
			GL_FOG_START, 1,
			GL_FRONT_FACE, 1,
			GL_GREEN_BIAS, 1,
			GL_GREEN_BITS, 1,
			GL_GREEN_SCALE, 1,
			GL_HISTOGRAM, 1,
			GL_INDEX_ARRAY, 1,
			GL_INDEX_ARRAY_STRIDE, 1,
			GL_INDEX_ARRAY_TYPE, 1,
			GL_INDEX_BITS, 1,
			GL_INDEX_CLEAR_VALUE, 1,
			GL_INDEX_LOGIC_OP, 1,
			GL_INDEX_MODE, 1,
			GL_INDEX_OFFSET, 1,
			GL_INDEX_SHIFT, 1,
			GL_INDEX_WRITEMASK, 1,
			GL_LIGHTING, 1,
			GL_LIGHT_MODEL_AMBIENT, 4,
			GL_LIGHT_MODEL_COLOR_CONTROL, 1,
			GL_LIGHT_MODEL_LOCAL_VIEWER, 1,
			GL_LIGHT_MODEL_TWO_SIDE, 1,
			GL_LINE_SMOOTH, 1,
			GL_LINE_SMOOTH_HINT, 1,
			GL_LINE_STIPPLE, 1,
			GL_LINE_STIPPLE_PATTERN, 1,
			GL_LINE_STIPPLE_REPEAT, 1,
			GL_LINE_WIDTH, 1, // 99 enums, 140 values to here
			GL_LIST_BASE, 1,
			GL_LIST_INDEX, 1,
			GL_LIST_MODE, 1,
			GL_LOGIC_OP_MODE, 1,
			GL_MAP1_COLOR_4, 1,
			GL_MAP1_GRID_DOMAIN, 2,
			GL_MAP1_GRID_SEGMENTS, 1,
			GL_MAP1_INDEX, 1,
			GL_MAP1_NORMAL, 1,
			GL_MAP1_TEXTURE_COORD_1, 1,
			GL_MAP1_TEXTURE_COORD_2, 1,
			GL_MAP1_TEXTURE_COORD_3, 1,
			GL_MAP1_TEXTURE_COORD_4, 1,
			GL_MAP1_VERTEX_3, 1,
			GL_MAP1_VERTEX_4, 1,
			GL_MAP2_COLOR_4, 1,
			GL_MAP2_GRID_DOMAIN, 4, // 161 values
			GL_MAP2_GRID_SEGMENTS, 2,
			GL_MAP2_INDEX, 1,
			GL_MAP2_NORMAL, 1,
			GL_MAP2_TEXTURE_COORD_1, 1,
			GL_MAP2_TEXTURE_COORD_2, 1,
			GL_MAP2_TEXTURE_COORD_3, 1,
			GL_MAP2_TEXTURE_COORD_4, 1,
			GL_MAP2_VERTEX_3, 1,
			GL_MAP2_VERTEX_4, 1,
			GL_MAP_COLOR, 1,
			GL_MAP_STENCIL, 1,
			GL_MATRIX_MODE, 1,
			GL_MINMAX, 1, // 129 enums, 175 values
			GL_MODELVIEW_MATRIX, 16,
			GL_MODELVIEW_STACK_DEPTH, 1, // 131 enums
			GL_NAME_STACK_DEPTH, 1,
			GL_NORMAL_ARRAY, 1,
			GL_NORMAL_ARRAY_STRIDE, 1,
			GL_NORMAL_ARRAY_TYPE, 1,
			GL_NORMALIZE, 1,
			GL_PACK_ALIGNMENT, 1,
			GL_PACK_IMAGE_HEIGHT, 1,
			GL_PACK_LSB_FIRST, 1, // 200 values
			GL_PACK_ROW_LENGTH, 1,
			GL_PACK_SKIP_IMAGES, 1, // 141 enums
			GL_PACK_SKIP_PIXELS, 1,
			GL_PACK_SKIP_ROWS, 1,
			GL_PACK_SWAP_BYTES, 1,
			GL_PERSPECTIVE_CORRECTION_HINT, 1,
			GL_PIXEL_MAP_A_TO_A_SIZE, 1,
			GL_PIXEL_MAP_B_TO_B_SIZE, 1,
			GL_PIXEL_MAP_G_TO_G_SIZE, 1,
			GL_PIXEL_MAP_I_TO_A_SIZE, 1,
			GL_PIXEL_MAP_I_TO_B_SIZE, 1,
			GL_PIXEL_MAP_I_TO_G_SIZE, 1,
			GL_PIXEL_MAP_I_TO_I_SIZE, 1,
			GL_PIXEL_MAP_I_TO_R_SIZE, 1,
			GL_PIXEL_MAP_R_TO_R_SIZE, 1,
			GL_PIXEL_MAP_S_TO_S_SIZE, 1,
			GL_POINT_SIZE, 1,
			GL_POINT_SMOOTH, 1,
			GL_POINT_SMOOTH_HINT, 1,
			GL_POLYGON_MODE, 2,
			GL_POLYGON_OFFSET_FACTOR, 1,
			GL_POLYGON_OFFSET_UNITS, 1,
			GL_POLYGON_OFFSET_FILL, 1,
			GL_POLYGON_OFFSET_LINE, 1, // 225 values
			GL_POLYGON_OFFSET_POINT, 1,
			GL_POLYGON_SMOOTH, 1,
			GL_POLYGON_SMOOTH_HINT, 1,
			GL_POLYGON_STIPPLE, 1,
			GL_POST_COLOR_MATRIX_COLOR_TABLE, 1,
			GL_POST_COLOR_MATRIX_RED_BIAS, 1,
			GL_POST_COLOR_MATRIX_GREEN_BIAS, 1,
			GL_POST_COLOR_MATRIX_BLUE_BIAS, 1,
			GL_POST_COLOR_MATRIX_ALPHA_BIAS, 1,
			GL_POST_COLOR_MATRIX_RED_SCALE, 1,
			GL_POST_COLOR_MATRIX_GREEN_SCALE, 1,
			GL_POST_COLOR_MATRIX_BLUE_SCALE, 1,
			GL_POST_COLOR_MATRIX_ALPHA_SCALE, 1,
			GL_POST_CONVOLUTION_COLOR_TABLE, 1,
			GL_POST_CONVOLUTION_RED_BIAS, 1,
			GL_POST_CONVOLUTION_GREEN_BIAS, 1,
			GL_POST_CONVOLUTION_BLUE_BIAS, 1,
			GL_POST_CONVOLUTION_ALPHA_BIAS, 1,
			GL_POST_CONVOLUTION_RED_SCALE, 1,
			GL_POST_CONVOLUTION_GREEN_SCALE, 1,
			GL_POST_CONVOLUTION_BLUE_SCALE, 1,
			GL_POST_CONVOLUTION_ALPHA_SCALE, 1, // 247 values
			GL_PROJECTION_MATRIX, 16,
			GL_PROJECTION_STACK_DEPTH, 1,
			GL_READ_BUFFER, 1, // 265 values
			GL_RED_BIAS, 1,
			GL_RED_BITS, 1,
			GL_RED_SCALE, 1,
			GL_RENDER_MODE, 1,
			GL_RESCALE_NORMAL, 1,
			GL_RGBA_MODE, 1,
			GL_SCISSOR_BOX, 4,
			GL_SCISSOR_TEST, 1,
			GL_SELECTION_BUFFER_SIZE, 1,
			GL_SEPARABLE_2D, 1,
			GL_SHADE_MODEL, 1,
			GL_STENCIL_BITS, 1,
			GL_STENCIL_CLEAR_VALUE, 1,
			GL_STENCIL_FAIL, 1,
			GL_STENCIL_FUNC, 1,
			GL_STENCIL_PASS_DEPTH_FAIL, 1,
			GL_STENCIL_PASS_DEPTH_PASS, 1,
			GL_STENCIL_REF, 1,
			GL_STENCIL_TEST, 1,
			GL_STENCIL_VALUE_MASK, 1,
			GL_STENCIL_WRITEMASK, 1,
			GL_SUBPIXEL_BITS, 1,
			GL_TEXTURE_1D, 1,
			GL_TEXTURE_BINDING_1D, 1,
			GL_TEXTURE_2D, 1,
			GL_TEXTURE_RECTANGLE_ARB, 1,
			GL_TEXTURE_BINDING_2D, 1,
			GL_TEXTURE_BINDING_RECTANGLE_ARB, 1,
			GL_TEXTURE_3D, 1,
			GL_TEXTURE_BINDING_3D, 1,
			GL_TEXTURE_COORD_ARRAY, 1,
			GL_TEXTURE_COORD_ARRAY_SIZE, 1, // 300 values
			GL_TEXTURE_COORD_ARRAY_STRIDE, 1,
			GL_TEXTURE_COORD_ARRAY_TYPE, 1,
			GL_TEXTURE_GEN_Q, 1,
			GL_TEXTURE_GEN_R, 1,
			GL_TEXTURE_GEN_S, 1,
			GL_TEXTURE_GEN_T, 1,
			GL_TEXTURE_MATRIX, 16,
			GL_TEXTURE_STACK_DEPTH, 1,
			GL_UNPACK_ALIGNMENT, 1,
			GL_UNPACK_IMAGE_HEIGHT, 1, // 325 values
			GL_UNPACK_LSB_FIRST, 1,
			GL_UNPACK_ROW_LENGTH, 1,
			GL_UNPACK_SKIP_IMAGES, 1,
			GL_UNPACK_SKIP_PIXELS, 1,
			GL_UNPACK_SKIP_ROWS, 1,
			GL_UNPACK_SWAP_BYTES, 1,
			GL_VERTEX_ARRAY, 1,
			GL_VERTEX_ARRAY_SIZE, 1,
			GL_VERTEX_ARRAY_STRIDE, 1,
			GL_VERTEX_ARRAY_TYPE, 1,
			GL_VIEWPORT, 4, // 241 enums
			GL_ZOOM_X, 1,
			GL_ZOOM_Y, 1, // 243 enums , 341 values
			GL_FRAMEBUFFER_BINDING_EXT, 1,
			GL_RENDERBUFFER_BINDING_EXT, 1,
			GL_READ_FRAMEBUFFER_BINDING_EXT, 1,
			GL_DRAW_FRAMEBUFFER_BINDING_EXT, 1,
			GL_UNPACK_CLIENT_STORAGE_APPLE, 1 // 248 enums, 346 values
//			GL_ALIASED_POINT_SIZE_RANGE, 2, // constant
//			GL_ALIASED_LINE_WIDTH_RANGE, 2, // constant
//			GL_ALPHA_BITS, 1,
//			GL_CLIP_PLANEi
//			params returns a single boolean value indicating whether the specified clipping plane is enabled. The initial value is GL_FALSE. See glClipPlane.			
//			GL_COLOR_MATRIX_STACK_DEPTH, 1, // constant			
//			GL_DOUBLEBUFFER, 1, // constant			
//			GL_LIGHTi
//			params returns a single boolean value indicating whether the specified light is enabled. The initial value is GL_FALSE. See glLight and glLightModel.
//			GL_LINE_WIDTH_GRANULARITY, 1,
//			GL_LINE_WIDTH_RANGE, 2, // constant
//			GL_MAX_3D_TEXTURE_SIZE, 1,
//			GL_MAX_CLIENT_ATTRIB_STACK_DEPTH, 1,
//			GL_MAX_ATTRIB_STACK_DEPTH, 1,
//			GL_MAX_CLIP_PLANES, 1,
//			GL_MAX_COLOR_MATRIX_STACK_DEPTH, 1,
//			GL_MAX_ELEMENTS_INDICES, 1,
//			GL_MAX_ELEMENTS_VERTICES, 1,
//			GL_MAX_EVAL_ORDER, 1,
//			GL_MAX_LIGHTS, 1,
//			GL_MAX_LIST_NESTING, 1,
//			GL_MAX_MODELVIEW_STACK_DEPTH, 1,
//			GL_MAX_NAME_STACK_DEPTH, 1,
//			GL_MAX_PIXEL_MAP_TABLE, 1, // constant
//			GL_MAX_PROJECTION_STACK_DEPTH, 1, // constant
//			GL_MAX_TEXTURE_SIZE, 1, // constant
//			GL_MAX_TEXTURE_STACK_DEPTH, 1, // constant
//			params returns one value, the maximum supported depth of the texture matrix stack. The value must be at least 2. See glPushMatrix.
//			GL_MAX_TEXTURE_UNITS_ARB, 1, // constant
//			GL_MAX_VIEWPORT_DIMS, 2, // constant?
//			GL_POINT_SIZE_GRANULARITY, 1, // constant
//			GL_POINT_SIZE_RANGE, 2, // constant
//			GL_SMOOTH_LINE_WIDTH_RANGE, 2, 	// constant
//			GL_SMOOTH_LINE_WIDTH_GRANULARITY, 1, //	constant
//			GL_SMOOTH_POINT_SIZE_RANGE, 2, // constant
//			GL_SMOOTH_POINT_SIZE_GRANULARITY, 1, // constant
//			GL_STEREO, 1, // constant
		};
		int offset = 0;
		for (int i = 0; i < kGLGetEnumCount; i++) {
			glGetFloatv(getEnums[i*2], &state->gotValues[offset]);
			for (int j = 0; j < getEnums[(i*2)+1]; j++) {
				state->gotEnums[offset + j] = getEnums[i*2];
			}
			offset+=getEnums[(i*2)+1];
		}

		GLenum getPointerEnums[kGLGetPointerCount] = {
			GL_FEEDBACK_BUFFER_POINTER,
			GL_INDEX_ARRAY_POINTER,
			GL_NORMAL_ARRAY_POINTER,
			GL_TEXTURE_COORD_ARRAY_POINTER,
			GL_SELECTION_BUFFER_POINTER,
			GL_VERTEX_ARRAY_POINTER
		};
		for (int i = 0; i < kGLGetPointerCount; i++) {
			glGetPointerv(getPointerEnums[i], &state->gotPointers[i]);
			state->gotPointerEnums[i] = getPointerEnums[i];
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
		
		GLenum getTexParamPointerEnums[kGLGetTexParamPointerCount] = {
			GL_TEXTURE_RANGE_POINTER_APPLE
		};
		
		for (int i = 0; i < kGLTargetCount; i++) {
			for (int j = 0; j < kGLGetTexParamIntCount; j++) {
				glGetTexParameteriv(targets[i], getTexParamIntEnums[j], &state->gotTexParamInts[(i * kGLGetTexParamIntCount) + j]);
				state->gotTexParamIntEnums[(i * kGLGetTexParamIntCount) + j] = getTexParamIntEnums[j];
			}
			for (int k = 0; k < kGLGetTexParamPointerCount; k++) {
				glGetTexParameterPointervAPPLE(targets[i], getTexParamPointerEnums[k], &state->gotTexParamPointers[(i * kGLGetTexParamPointerCount) + k]);
				state->gotTexParamPointerEnums[(i * kGLGetTexParamPointerCount) + k] = getTexParamPointerEnums[k];
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
	return (GLStatesFirstUnequalState(a, b) == 0);
}

GLenum GLStatesFirstUnequalState(GLStateRef a, GLStateRef b)
{
	{
		for (int i = 0; i < kGLGetValueCount; i++) {
			if (a->gotValues[i] != b->gotValues[i])
				return a->gotEnums[i];
		}
		
		for (int i = 0; i < kGLGetPointerCount; i++) {
			if (a->gotPointers[i] != b->gotPointers[i])
				return a->gotPointerEnums[i];
		}
		for (int i = 0; i < kGLTargetCount; i++) {
			for (int j = 0; j < kGLGetTexParamIntCount; j++) {
				if (a->gotTexParamInts[(i * kGLGetTexParamIntCount) + j] != b->gotTexParamInts[(i * kGLGetTexParamIntCount) + j])
					return a->gotTexParamIntEnums[i];
			}
			for (int k = 0; k < kGLGetTexParamPointerCount; k++) {
				if (a->gotTexParamPointers[(i * kGLGetTexParamPointerCount) + k] != b->gotTexParamPointers[(i * kGLGetTexParamPointerCount) + k])
					return a->gotTexParamPointerEnums[i];
			}
		}
		return 0;
	}
}