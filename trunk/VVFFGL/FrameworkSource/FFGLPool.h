/*
 *  FFGLPool.h
 *  VVFFGL
 *
 *  Created by Tom on 04/11/2009.
 *  Copyright 2009 Tom Butterworth. All rights reserved.
 *
 */

// FFGLPools and FFGLPoolObjects are thread-safe.
// Your create/destroy callbacks must themselves be thread-safe
// if you wish to maintain thread-safety (the destroy callback will
// never be called for an object until its create callback has
// returned).

typedef struct FFGLPoolCallBacks {
    const void *(*create)(const void *);
    void (*destroy)(const void *, const void *);
} FFGLPoolCallBacks;

typedef struct FFGLPool *FFGLPoolRef;

FFGLPoolRef FFGLPoolCreate(FFGLPoolCallBacks *callbacks, unsigned int sizeMax, const void *userInfo);
FFGLPoolRef FFGLPoolRetain(FFGLPoolRef pool);
void FFGLPoolRelease(FFGLPoolRef pool);

typedef struct FFGLPoolObject *FFGLPoolObjectRef;

FFGLPoolObjectRef FFGLPoolObjectCreate(FFGLPoolRef pool);
FFGLPoolObjectRef FFGLPoolObjectRetain(FFGLPoolObjectRef object);
void FFGLPoolObjectRelease(FFGLPoolObjectRef object);
const void *FFGLPoolObjectGetData(FFGLPoolObjectRef object);
