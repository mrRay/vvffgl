//
//  FFGLPluginTests.m
//  VVFFGL
//
//  Created by Tom on 30/01/2010.
//  Copyright 2010 Tom Butterworth. All rights reserved.
//

#import "FFGLPluginTests.h"


@implementation FFGLPluginTests
- (void)testReusingInstances
{
	FFGLPlugin *plugin = [[[FFGLPluginManager sharedManager] plugins] lastObject];
	NSString *path = [[plugin attributes] objectForKey:FFGLPluginAttributePathKey];
	FFGLPlugin *duplicate = [[[FFGLPlugin alloc] initWithPath:path] autorelease];
	STAssertTrue(plugin == duplicate, @"FFGLPlugin returned a new instance when it should have re-used one.");
}

- (void)testReleasingPlugins
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	FFGLPlugin *plugin = [[[FFGLPluginManager sharedManager] plugins] lastObject];
	NSString *path = [[[plugin attributes] objectForKey:FFGLPluginAttributePathKey] retain];
	[[FFGLPluginManager sharedManager] unloadPlugin:plugin];
	[pool drain];
	FFGLPlugin *duplicate = [[[FFGLPlugin alloc] initWithPath:path] autorelease];
	[path release];
	STAssertTrue(plugin != duplicate, @"FFGLPlugin didn't release a plugin when it should have.");
}
@end
