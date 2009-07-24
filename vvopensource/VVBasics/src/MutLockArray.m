
#import "MutLockArray.h"




/*
		RULES:
	- methods which aren't locking can check all conditionals where appropriate
	- methods which lock can ONLY check to make sure existing or passed params are nil or not
	- this class should work transparently with other instances of this class, so in
		some places i have to check to see if i'm being passed an MutLockArray or
		a normal NSMutableArray
	- exception handlers go everywhere something's being released so i don't wind up 
		with a loose lock.  slowly comment them out.  ONLY put them in NON-locking methods.
*/




@implementation MutLockArray


- (NSString *) description	{
	return [NSString stringWithFormat:@"<MutLockArray: %@>",array];
}
+ (id) arrayWithCapacity:(NSUInteger)c	{
	MutLockArray		*returnMe = [[MutLockArray alloc] initWithCapacity:c];
	if (returnMe == nil)
		return nil;
	return [returnMe autorelease];
}
- (id) initWithCapacity:(NSUInteger)c	{
	pthread_rwlockattr_t		attr;
	
	if (self = [super init])	{
		if (c < 0)
			array = [[NSMutableArray alloc] initWithCapacity:0];
		else
			array = [[NSMutableArray alloc] initWithCapacity:c];
		if (array == nil)	{
			[self release];
			return nil;
		}
		pthread_rwlockattr_init(&attr);
		pthread_rwlockattr_setpshared(&attr, PTHREAD_PROCESS_SHARED);
		pthread_rwlock_init(&arrayLock, &attr);
		
		return self;
	}
	
	[self release];
	return nil;
}
- (id) init	{
	return [self initWithCapacity:0];
}

- (void) dealloc	{
	[self lockRemoveAllObjects];
	pthread_rwlock_destroy(&arrayLock);
	if (array != nil)
		[array release];
	array = nil;
	[super dealloc];
}


- (void) rdlock	{
	pthread_rwlock_rdlock(&arrayLock);
}
- (void) wrlock	{
	pthread_rwlock_wrlock(&arrayLock);
}
- (void) unlock	{
	pthread_rwlock_unlock(&arrayLock);
}


- (NSMutableArray *) array	{
	return array;
}
- (NSMutableArray *) createArrayCopy	{
	NSMutableArray		*returnMe = [array mutableCopy];
	if (returnMe == nil)
		return nil;
	return [returnMe autorelease];
}
- (NSMutableArray *) lockCreateArrayCopy	{
	NSMutableArray		*returnMe = nil;
	
	pthread_rwlock_rdlock(&arrayLock);
		//returnMe = [array mutableCopy];
		returnMe = [self createArrayCopy];
	pthread_rwlock_unlock(&arrayLock);
	
	return returnMe;
}


- (void) addObject:(id)o	{
	if ((array != nil)&&(o!=nil))	{
		//@try	{
			[array addObject:o];
		//}
		//@catch (NSException *err)	{
		//	NSLog(@"\t\t%s - %@",__func__,err);
		//}
	}
}
- (void) lockAddObject:(id)o	{
	if ((array != nil)&&(o!=nil))	{
		pthread_rwlock_wrlock(&arrayLock);
			[self addObject:o];
		pthread_rwlock_unlock(&arrayLock);
	}
}
- (void) addObjectsFromArray:(id)a	{
	//NSLog(@"%s",__func__);
	if ((array != nil) && (a != nil) && ([a count] > 0))	{
		//@try	{
			if ([a isKindOfClass:[MutLockArray class]])
				[array addObjectsFromArray:[a lockCreateArrayCopy]];
			else
				[array addObjectsFromArray:a];
		//}
		//@catch (NSException *err)	{
		//	NSLog(@"\t\t%s - %@",__func__,err);
		//}
	}
	//NSLog(@"\t\t%s - FINISHED",__func__);
}
- (void) lockAddObjectsFromArray:(id)a	{
	if ((array != nil) && (a != nil))	{
		pthread_rwlock_wrlock(&arrayLock);
			[self addObjectsFromArray:a];
		pthread_rwlock_unlock(&arrayLock);
	}
}

- (void) replaceWithObjectsFromArray:(id)a	{
	if ((array != nil) && (a != nil))	{
		@try	{
			[array removeAllObjects];
			if ([a count]>0)	{
				if ([a isKindOfClass:[MutLockArray class]])
					[array addObjectsFromArray:[a lockCreateArrayCopy]];
				else
					[array addObjectsFromArray:a];
			}
		}
		@catch (NSException *err)	{
			NSLog(@"\t\t%s - %@",__func__,err);
		}
	}
}
- (void) lockReplaceWithObjectsFromArray:(id)a	{
	if ((array != nil) && (a != nil))	{
		pthread_rwlock_wrlock(&arrayLock);
			[self replaceWithObjectsFromArray:a];
		pthread_rwlock_unlock(&arrayLock);
	}
}

- (void) insertObject:(id)o atIndex:(NSUInteger)i	{
	if ((array != nil) && (o != nil) && (i<=[array count]))	{
		//@try	{
			[array insertObject:o atIndex:i];
		//}
		//@catch (NSException *err)	{
		//	NSLog(@"\t\t%s - %@",__func__,err);
		//}
	}
}
- (void) lockInsertObject:(id)o atIndex:(NSUInteger)i	{
	if ((array != nil) && (o != nil))	{
		pthread_rwlock_wrlock(&arrayLock);
			[self insertObject:o atIndex:i];
		pthread_rwlock_unlock(&arrayLock);
	}
}


- (void) removeAllObjects	{
	if ((array != nil) && ([array count] > 0))	{
		@try	{
			[array removeAllObjects];
		}
		@catch (NSException *err)	{
			NSLog(@"\t\t%s - %@",__func__,err);
		}
	}
}
- (void) lockRemoveAllObjects	{
	if (array != nil)	{
		pthread_rwlock_wrlock(&arrayLock);
			[self removeAllObjects];
		pthread_rwlock_unlock(&arrayLock);
	}
}

- (id) lastObject	{
	if ((array == nil)||([array count]<1))	{
		return nil;
	}
	return [array lastObject];
}
- (id) lockLastObject	{
	id	returnMe = nil;
	
	if ((array != nil) && ([array count]>0))	{
		pthread_rwlock_wrlock(&arrayLock);
			returnMe = [self lastObject];
		pthread_rwlock_unlock(&arrayLock);
	}
	
	return returnMe;
}

- (void) removeLastObject	{
	if ((array != nil) && ([array count]>0))	{
		@try	{
			[array removeLastObject];
		}
		@catch (NSException *err)	{
			NSLog(@"\t\t%s - %@",__func__,err);
		}
	}
}
- (void) lockRemoveLastObject	{
	pthread_rwlock_wrlock(&arrayLock);
		[self removeLastObject];
	pthread_rwlock_unlock(&arrayLock);
}
- (void) removeObject:(id)o	{
	if (array != nil)	{
		@try	{
			[array removeObject:o];
		}
		@catch (NSException *err)	{
			NSLog(@"\t\t%s - %@",__func__,err);
		}
	}
}
- (void) lockRemoveObject:(id)o	{
	pthread_rwlock_wrlock(&arrayLock);
		[self removeObject:o];
	pthread_rwlock_unlock(&arrayLock);
}
- (void) removeObjectAtIndex:(NSUInteger)i	{
	if ((array!=nil) && ([array count]>0) && (i<[array count]) && (i>=0))	{
		@try	{
			[array removeObjectAtIndex:i];
		}
		@catch (NSException *err)	{
			NSLog(@"\t\t%s - %@",__func__,err);
		}
	}
}
- (void) lockRemoveObjectAtIndex:(NSUInteger)i	{
	if (array != nil)	{
		pthread_rwlock_wrlock(&arrayLock);
			[self removeObjectAtIndex:i];
		pthread_rwlock_unlock(&arrayLock);
	}
}
- (void) removeObjectsAtIndexes:(NSIndexSet *)i	{
	if (array != nil)	{
		@try	{
			[array removeObjectsAtIndexes:i];
		}
		@catch (NSException *err)	{
			NSLog(@"\t\t%s - %@",__func__,err);
		}
	}
}
- (void) lockRemoveObjectsAtIndexes:(NSIndexSet *)i	{
	if (array != nil)	{
		pthread_rwlock_wrlock(&arrayLock);
			[self removeObjectsAtIndexes:i];
		pthread_rwlock_unlock(&arrayLock);
	}
}
- (void) removeObjectsInArray:(NSArray *)otherArray	{
	if (array != nil)	{
		@try	{
			[array removeObjectsInArray:otherArray];
		}
		@catch (NSException *err)	{
			NSLog(@"\t\t%s - %@",__func__,err);
		}
	}	
}
- (void) lockRemoveObjectsInArray:(NSArray *)otherArray	{
	if (array != nil)	{
		@try	{
			pthread_rwlock_wrlock(&arrayLock);
				[array removeObjectsInArray:otherArray];
			pthread_rwlock_unlock(&arrayLock);
		}
		@catch (NSException *err)	{
			NSLog(@"\t\t%s - %@",__func__,err);
		}
	}
}
- (id) valueForKey:(NSString *)key	{
	if ((array == nil) || (key == nil))
		return nil;
	return [array valueForKey:key];
}
- (id) lockValueForKey:(NSString *)key	{
	if ((array == nil) || (key == nil))
		return nil;
	id	returnMe = nil;
	pthread_rwlock_wrlock(&arrayLock);
		returnMe = [array valueForKey:key];
	pthread_rwlock_unlock(&arrayLock);	
	
	return returnMe;
}


- (BOOL) containsObject:(id)o	{
	if ((array == nil) || (o == nil))
		return NO;
	return [array containsObject:o];
}
- (BOOL) lockContainsObject:(id)o	{
	if ((array == nil) || (o == nil))
		return NO;
	
	BOOL		returnMe = NO;
	pthread_rwlock_rdlock(&arrayLock);
		returnMe = [self containsObject:o];
	pthread_rwlock_unlock(&arrayLock);
	return returnMe;
}


- (id) objectAtIndex:(NSUInteger)i	{
	if ((array != nil) && (i>=0) && (i<[array count]))	{
		id			returnMe = nil;
		//@try	{
			returnMe = [array objectAtIndex:i];
		//}
		//@catch (NSException *err)	{
		//	NSLog(@"\t\t%s - %@",__func__,err);
		//}
		return returnMe;
	}
	return nil;
}
- (id) lockObjectAtIndex:(NSUInteger)i	{
	id		returnMe = nil;
	pthread_rwlock_rdlock(&arrayLock);
		returnMe = [self objectAtIndex:i];
	pthread_rwlock_unlock(&arrayLock);
	return returnMe;
}
- (NSArray *) objectsAtIndexes:(NSIndexSet *)indexes	{
	NSArray		*returnMe = nil;
	
	if ((array != nil) && (indexes != nil))	{
			returnMe = [array objectsAtIndexes:indexes];	
	}
	
	return returnMe;
}
- (NSArray *) lockObjectsAtIndexes:(NSIndexSet *)indexes	{
	NSArray		*returnMe = nil;
	
	if ((array != nil) && (indexes != nil))	{
		pthread_rwlock_rdlock(&arrayLock);
			returnMe = [array objectsAtIndexes:indexes];
		pthread_rwlock_unlock(&arrayLock);
	}
	
	return returnMe;
}
- (NSUInteger) indexOfObject:(id)o	{
	NSUInteger returnMe = -1;
	if ((array != nil) && (o != nil))	{
		//@try	{
			returnMe = [array indexOfObject:o];
		//}
		//@catch (NSException *err)	{
		//	NSLog(@"\t\t%s - %@",__func__,err);
		//}
	}
	return returnMe;	
}
- (NSUInteger) lockIndexOfObject:(id)o	{
	NSUInteger returnMe = -1;
	if ((array != nil) && (o != nil))	{
		//@try	{
			pthread_rwlock_rdlock(&arrayLock);
				returnMe = [array indexOfObject:o];
			pthread_rwlock_unlock(&arrayLock);
		//}
		//@catch (NSException *err)	{
		//	NSLog(@"\t\t%s - %@",__func__,err);
		//}
	}
	return returnMe;
}


- (BOOL) containsIdenticalPtr:(id)o	{
	BOOL				returnMe = NO;
	
	if ((array!=nil) && (o!=nil) && ([array count]>0))	{
		NSEnumerator		*it = [array objectEnumerator];
		id					anObj;
		while ((anObj = [it nextObject]) && (!returnMe))	{
			if (anObj == o)
				returnMe = YES;
		}
	}
	
	return returnMe;
}
- (BOOL) lockContainsIdenticalPtr:(id)o	{
	BOOL				returnMe = NO;
	
	if ((array!=nil) && (o!=nil) && ([array count]>0))	{
		pthread_rwlock_rdlock(&arrayLock);
			returnMe = [self containsIdenticalPtr:o];
		pthread_rwlock_unlock(&arrayLock);
	}
	return returnMe;
}
- (int) indexOfIdenticalPtr:(id)o	{
	int					delegateIndex = NSNotFound;
	
	if ((array!=nil) && (o!=nil) && ([array count]>0))	{
		NSEnumerator		*it = [array objectEnumerator];
		id					anObj;
		int					indexCount = 0;
		
		while ((anObj = [it nextObject]) && (delegateIndex==NSNotFound))	{
			if (anObj == o)
				delegateIndex = indexCount;
			++indexCount;
		}
	}
	
	return delegateIndex;
}
- (int) lockIndexOfIdenticalPtr:(id)o	{
	int			returnMe = NSNotFound;
	
	if ((array!=nil) && (o!=nil) && ([array count]>0))	{
		pthread_rwlock_rdlock(&arrayLock);
			returnMe = [self indexOfIdenticalPtr:o];
		pthread_rwlock_unlock(&arrayLock);
	}
	
	return returnMe;
}
- (void) removeIdenticalPtr:(id)o	{
	if ((array!=nil) && (o!=nil) && ([array count]>0))	{
		int					delegateIndex = NSNotFound;
		NSEnumerator		*it = [array objectEnumerator];
		id					anObj;
		int					indexCount = 0;
		
		while ((anObj = [it nextObject]) && (delegateIndex==NSNotFound))	{
			if (anObj == o)
				delegateIndex = indexCount;
			++indexCount;
		}
		if (delegateIndex!=NSNotFound)
			[array removeObjectAtIndex:delegateIndex];
	}
}
- (void) lockRemoveIdenticalPtr:(id)o	{
	if ((array!=nil) && (o!=nil) && ([array count]>0))	{
		pthread_rwlock_wrlock(&arrayLock);
			[self removeIdenticalPtr:o];
		pthread_rwlock_unlock(&arrayLock);
	}
}

- (void) makeObjectsPerformSelector:(SEL)s	{
	if (array != nil)	{
		@try	{
			[array makeObjectsPerformSelector:s];
		}
		@catch (NSException *err)	{
			NSLog(@"\t\t%s - %@",__func__,err);
		}
	}
}
- (void) lockMakeObjectsPerformSelector:(SEL)s	{
	if (array != nil)	{
		pthread_rwlock_rdlock(&arrayLock);
			[self makeObjectsPerformSelector:s];
		pthread_rwlock_unlock(&arrayLock);
	}
}
- (void) makeObjectsPerformSelector:(SEL)s withObject:(id)o	{
	if (array != nil)	{
		@try	{
			[array makeObjectsPerformSelector:s withObject:o];
		}
		@catch (NSException *err)	{
			NSLog(@"\t\t%s - %@",__func__,err);
		}
	}
}
- (void) lockMakeObjectsPerformSelector:(SEL)s withObject:(id)o	{
	if (array != nil)	{
		pthread_rwlock_rdlock(&arrayLock);
			[self makeObjectsPerformSelector:s withObject:o];
		pthread_rwlock_unlock(&arrayLock);
	}
}


/*
- (void) makeCopyPerformSelector:(SEL)s	{
	if (array != nil)	{
		NSArray		*copy = [NSArray arrayWithArray:array];
		if (copy != nil)	{
			@try	{
				[copy makeObjectsPerformSelector:s];
			}
			@catch (NSException *err)	{
				NSLog(@"\t\t%s- %@",__func__,err);
			}
		}
	}
}
- (void) lockMakeCopyPerformSelector:(SEL)s	{
	if (array != nil)	{
		pthread_rwlock_rdlock(&arrayLock);
		NSArray		*copy = [NSArray arrayWithArray:array];
		pthread_rwlock_unlock(&arrayLock);
		
		if (copy != nil)	{
			@try	{
				[copy makeObjectsPerformSelector:s];
			}
			@catch (NSException *err)	{
				NSLog(@"\t\t%s- %@",__func__,err);
			}
		}
	}
}
- (void) makeCopyPerformSelector:(SEL)s withObject:(id)o	{
	if (array != nil)	{
		NSArray		*copy = [NSArray arrayWithArray:array];
		if (copy != nil)	{
			@try	{
				[copy makeObjectsPerformSelector:s withObject:o];
			}
			@catch (NSException *err)	{
				NSLog(@"\t\t%s- %@",__func__,err);
			}
		}
	}
}
- (void) lockMakeCopyPerformSelector:(SEL)s withObject:(id)o	{
	if (array != nil)	{
		pthread_rwlock_rdlock(&arrayLock);
		NSArray		*copy = [NSArray arrayWithArray:array];
		pthread_rwlock_unlock(&arrayLock);
		
		if (copy != nil)	{
			@try	{
				[copy makeObjectsPerformSelector:s withObject:o];
			}
			@catch (NSException *err)	{
				NSLog(@"\t\t%s- %@",__func__,err);
			}
		}
	}
}
*/


- (void) sortUsingSelector:(SEL)s	{
	if ((array != nil)&&([array count]>0))
		[array sortUsingSelector:s];
}
- (void) lockSortUsingSelector:(SEL)s	{
	if (array != nil)	{
		pthread_rwlock_wrlock(&arrayLock);
			[self sortUsingSelector:s];
		pthread_rwlock_unlock(&arrayLock);
	}
}


- (NSEnumerator *) objectEnumerator	{
	if (array != nil)
		return [array objectEnumerator];
	else
		return nil;
}
- (NSEnumerator *) reverseObjectEnumerator	{
	if (array != nil)
		return [array reverseObjectEnumerator];
	else
		return nil;
}


- (NSUInteger) count	{
	if (array == nil)
		return 0;
	return [array count];
}
- (NSUInteger) lockCount	{
	if (array == nil)
		return 0;
	int			returnMe = 0;
	pthread_rwlock_rdlock(&arrayLock);
		returnMe = [array count];
	pthread_rwlock_unlock(&arrayLock);
	return returnMe;
}


@end
