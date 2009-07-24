//
//  VVFFGLRenderer.m
//  VVOpenSource
//
//  Created by Tom on 24/07/2009.
//  Copyright 2009 Tom Butterworth. All rights reserved.
//

#import "VVFFGLRenderer.h"
#import "VVFFGLPlugin.h"

@implementation VVFFGLRenderer

- (id)init
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (id)initWithPlugin:(VVFFGLPlugin *)plugin
{
    if (self = [super init]) {
        _plugin = [plugin retain];
    }
    return self;
}

- (void)dealloc
{
    [_plugin release];
    [super dealloc];
}
@end
