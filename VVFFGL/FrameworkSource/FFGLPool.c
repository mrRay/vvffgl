/*
 *  FFGLPool.c
 *  VVFFGL
 *
 *  Created by Tom on 04/11/2009.
 *  Copyright 2009 Tom Butterworth. All rights reserved.
 *
 */

#include "FFGLPool.h"
#import <stdlib.h>

/*
typedef struct FFPoolCallBacks {
    const void *(*create)(const void *);
    void (*destroy)(const void *, const void *);
}FFPoolCallBacks;
*/

static void _FFGLPoolObjectDispose(FFGLPoolObjectRef object);

typedef struct FFGLPool
{
	unsigned int retainc;
	FFGLPoolCallBacks *callbacks;
	const void *useri;
	unsigned int size;
	FFGLPoolObjectRef *members;
} FFGLPool;

typedef struct FFGLPoolObject
{
	unsigned int retainc;
	FFGLPoolRef pool;
	const void *object;
} FFGLPoolObject;

FFGLPoolRef FFGLPoolCreate(FFGLPoolCallBacks *callbacks, unsigned int sizeMax, const void *userInfo)
{
	if (callbacks == NULL || sizeMax == 0)
		return NULL;
	FFGLPoolRef new = malloc(sizeof(FFGLPool));
	if (new)
	{
		new->members = malloc(sizeof(FFGLPoolObjectRef) * sizeMax);
		if (new->members == NULL)
		{
			free(new);
			return NULL;
		}
		for (unsigned int i = 0; i < sizeMax; i++) {
			new->members[i] = NULL;
		}
		new->callbacks = malloc(sizeof(FFGLPoolCallBacks));
		if (new->callbacks == NULL)
		{
			free(new->members);
			free(new);
			return NULL;
		}
		new->callbacks->create = callbacks->create;
		new->callbacks->destroy = callbacks->destroy;
		new->size = sizeMax;
		new->retainc = 1;
		new->useri = userInfo;
	}
	return new;
}

FFGLPoolRef FFGLPoolRetain(FFGLPoolRef pool)
{
	if (pool)
		pool->retainc++;
	return pool;
}

void FFGLPoolRelease(FFGLPoolRef pool)
{
	if (pool)
	{
		pool->retainc--;
		if (pool->retainc == 0) {
			for (unsigned int i = 0; i < pool->size; i++) {
				FFGLPoolObjectRef object = pool->members[i];
				if (object)
					_FFGLPoolObjectDispose(pool->members[i]);
			}
			free(pool->members);
			free(pool);
		}
	}
}

FFGLPoolObjectRef FFGLPoolObjectCreate(FFGLPoolRef pool)
{
	if (pool == NULL)
		return NULL;
	FFGLPoolObjectRef new = NULL;
	unsigned int i = 0;
	while ((i < pool->size) && (new = pool->members[i]) == NULL) {
		i++;
	}
	if (new == NULL)
	{
		new = malloc(sizeof(FFGLPoolObject));
		if (new)
		{
			new->object = pool->callbacks->create(pool->useri);
			new->pool = pool;
			if (new->object == NULL)
			{
				free(new);
				new = NULL;
			}
		}
	}
	else
	{
		pool->members[i] = NULL;
	}
	if (new != NULL)
	{
		new->retainc = 1;
		FFGLPoolRetain(pool);
	}
	return new;
}

FFGLPoolObjectRef FFGLPoolObjectRetain(FFGLPoolObjectRef object)
{
	if (object)
		object->retainc++;
	return object;
}

void FFGLPoolObjectRelease(FFGLPoolObjectRef object)
{
	if (object)
	{
		object->retainc--;
		if (object->retainc == 0)
		{
			FFGLPoolRef pool = object->pool;
			if (pool != NULL)
			{
				unsigned int i = 0;
				while ((i < pool->size) && (pool->members[i]) != NULL)
				{
					i++;
				}
				if (i < pool->size && pool->members[i] == NULL)
				{
					pool->members[i] = object;
				}
				else
				{	
					_FFGLPoolObjectDispose(object);
				}
				FFGLPoolRelease(pool);
			}
		}
	}
}

static void _FFGLPoolObjectDispose(FFGLPoolObjectRef object)
{
	if (object->pool->callbacks->destroy != NULL)
		object->pool->callbacks->destroy(object->object, object->pool->useri);
	free(object);
}

const void *FFGLPoolObjectGetData(FFGLPoolObjectRef object)
{
	return object->object;
}
