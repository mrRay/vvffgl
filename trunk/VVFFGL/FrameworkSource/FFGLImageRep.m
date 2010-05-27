//
//  FFGLImageRep.m
//  VVFFGL
//
//  Created by Tom on 11/02/2010.
//

#import "FFGLImageRep.h"
#import "FFGLTextureRep.h"
#import "FFGLBufferRep.h"

@implementation FFGLImageRep

- (id)initAsType:(FFGLImageRepType)repType isFlipped:(BOOL)flipped asPrimaryRep:(BOOL)isPrimary
{
	if (self = [super init])
	{
		_isFlipped = flipped;
		_type = repType;
		_isPrimary = isPrimary;
		_subscribers = 0;
	}
	return self;
}

- (void)performCallbackPriorToRelease
{
	// subclasses override this
}

- (FFGLImageRepType)type
{
	return _type;
}

- (BOOL)isFlipped
{
	return _isFlipped;
}

- (NSUInteger)addSubscriber
{
	_subscribers++;
	return _subscribers;
}

- (NSUInteger)removeSubscriber
{
	_subscribers--;
	return _subscribers;
}

- (NSUInteger)subscriptionCount
{
	return _subscribers;
}

- (BOOL)isPrimaryRep
{
	return _isPrimary;
}
-(BOOL)conformsToFreeFrame
{
	// Subclasses override this
	return NO;
}
- (void)drawInContext:(CGLContextObj)context inRect:(NSRect)destRect fromRect:(NSRect)srcRect
{
	// Subclasses override this
}
@end
