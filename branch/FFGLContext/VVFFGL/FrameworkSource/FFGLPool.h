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

/*
 FFGLPoolRef FFGLPoolCreate(FFGLPoolCallBacks *callbacks, unsigned int sizeMax, const void *userInfo)
 
 callbacks - a pointer to an FFGLPoolCallBacks struct. The contents of the struct is copied, the struct
 need not last beyond the call to FFGLPoolCreate().
	create callback is called when the pool is empty and a new object is requested (by a call to
	FFGLPoolObjectCreate()). It should accept one argument, which is the userInfo pointer passed in
	at pool creation, and should return a pointer to the newly-created user data. For example:
		void *myCreateCallback(const void *userInfo)
	destroy callback is called when the last reference to a pool object is released, and the pool
	is at maximum capacity (ie it contains sizeMax objects waiting to be recycled). It should accept
	two arguments: the first the pointer returned by the create callback, the second the userInfo
	pointer passed in at pool creation. For example:
		void myDestroyCallback(const void *data, const void *userInfo)
 
 sizeMax - The maximum size the pool should grow to.
 
 userInfo - a pointer which is passed to create and destroy callbacks
 
 result - the new FFGLPool
 */
FFGLPoolRef FFGLPoolCreate(FFGLPoolCallBacks *callbacks, unsigned int sizeMax, const void *userInfo);

/*
 FFGLPoolRef FFGLPoolRetain(FFGLPoolRef pool)
 
 pool - pool has its retain-count incremented by one.
 
 result - The same FFGLPool.
 */
FFGLPoolRef FFGLPoolRetain(FFGLPoolRef pool);

/*
 void FFGLPoolRelease(FFGLPoolRef pool)
 
 pool - the retain-count of the pool is decremented. When the retain-count reaches zero, the pool
	will be destroyed. FFGLPoolObjects from the pool can be safely used even after the pool has been
	released.
 */
void FFGLPoolRelease(FFGLPoolRef pool);

typedef struct FFGLPoolObject *FFGLPoolObjectRef;

/*
 FFGLPoolObjectRef FFGLPoolObjectCreate(FFGLPoolRef pool)
 
 pool - The pool from which to recycle or create an object.
 
 result - An existing unused FFGLPoolObject from the pool, or a new one if none such exists.
 */
FFGLPoolObjectRef FFGLPoolObjectCreate(FFGLPoolRef pool);

/*
 FFGLPoolObjectRef FFGLPoolObjectRetain(FFGLPoolObjectRef object)
 
 object - an object from a pool.
 
 result - the same FFGLPoolObject, with its retain-count incremented by one.
 */
FFGLPoolObjectRef FFGLPoolObjectRetain(FFGLPoolObjectRef object);

/*
 void FFGLPoolObjectRelease(FFGLPoolObjectRef object)
 
 object - object has its retain-count decremented. When the retain-count reaches zero, object
	is returned to its pool, or destroyed if the pool has no space.
 */
void FFGLPoolObjectRelease(FFGLPoolObjectRef object);

/*
 const void *FFGLPoolObjectGetData(FFGLPoolObjectRef object)
 
 object - an object from a pool
 
 result - the pointer returned by the create callback when object was created.
 */
const void *FFGLPoolObjectGetData(FFGLPoolObjectRef object);
