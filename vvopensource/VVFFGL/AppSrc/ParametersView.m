//
//  ParametersView.m
//  VVOpenSource
//
//  Created by Tom on 02/10/2009.
//  Copyright 2009 Tom Butterworth. All rights reserved.
//

#import "ParametersView.h"

#define SliderHeight 19.0

@implementation ParametersView

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
    }
    return self;
}

- (void)dealloc
{
    [_renderer release];
    [super dealloc];
}

- (void)drawRect:(NSRect)dirtyRect {
    // Drawing code here.
}

- (BOOL)isFlipped {
    return YES;
}

- (FFGLRenderer *)renderer {
    return _renderer;
}

- (void)setRenderer:(FFGLRenderer *)renderer
{
    if ([renderer isEqual:[NSNull null]]) {
        renderer = nil;
    }
    if (![_renderer isEqual:renderer]) {
        /*
         
         The horizontal alignment (controls and their labels) is off and the layout is ridiculous.
         If anyone plans to use this class for anything serious, please clean it up!
         */
        NSMutableArray *views = [NSMutableArray arrayWithCapacity:4];
        NSArray *params = [[renderer plugin] parameterKeys];
        NSString *key;
        NSPoint origin = NSMakePoint(20.0, 20.0);
        BOOL hadFirstImage = NO; // so we can skip it because the test app links it
        for (key in params) {
            origin.x = 20.0;
            NSDictionary *pAttributes = [[renderer plugin] attributesForParameterWithKey:key];
            NSString *type = [pAttributes objectForKey:FFGLParameterAttributeTypeKey];
            NSControl *control;
            NSTextField *label = [[[NSTextField alloc] initWithFrame:NSMakeRect(origin.x, origin.y, 100.0, 14.0)] autorelease];
            [label setBordered:NO];
            [label setEditable:NO];
            [label setDrawsBackground:NO];
            [label setFont:[NSFont systemFontOfSize:[NSFont systemFontSizeForControlSize:NSSmallControlSize]]];
            [[label cell] setControlSize:NSSmallControlSize];
            [label setStringValue:[NSString stringWithFormat:@"%@:", [pAttributes objectForKey:FFGLParameterAttributeNameKey]]];
            [label sizeToFit];
            origin.x += [label frame].size.width + 8; // terrible layout, but will do for now.
            if ([type isEqualToString:FFGLParameterTypeNumber]) {
                control = [[[NSSlider alloc] initWithFrame:NSMakeRect(origin.x, origin.y, [self frame].size.width - 40 - [label frame].size.width - 8, SliderHeight)] autorelease];
                [(NSSlider *)control setMaxValue:1.0];
                [(NSSlider *)control setMinValue:0.0];
                [(NSSlider *)control setNumberOfTickMarks:5];
            } else if ([type isEqualToString:FFGLParameterTypeBoolean]) {
                control = [[[NSButton alloc] initWithFrame:NSMakeRect(origin.x, origin.y, 63, 18)] autorelease];
                [(NSButton *)control setButtonType:NSSwitchButton];
                [(NSButton *)control setTitle:@""];
            } else if ([type isEqualToString:FFGLParameterTypeEvent]) {
                control = [[[NSButton alloc] initWithFrame:NSMakeRect(origin.x, origin.y, 96, 28)] autorelease];
                [(NSButton *)control setButtonType:NSMomentaryLightButton];
                [(NSButton *)control setTitle:@"Trigger"];
            } else if ([type isEqualToString:FFGLParameterTypeString]) {
                control = [[[NSTextField alloc] initWithFrame:NSMakeRect(origin.x, origin.y, 100, 96)] autorelease];
            } else if ([type isEqualToString:FFGLParameterTypeImage]) {
                control = [[[NSTextField alloc] initWithFrame:NSMakeRect(origin.x, origin.y, 100.0, 14.0)] autorelease];
                [(NSTextField *)control setBordered:NO];
                [(NSTextField *)control setEditable:NO];
                [(NSTextField *)control setDrawsBackground:NO];
                [(NSTextField *)control setFont:[NSFont systemFontOfSize:[NSFont systemFontSizeForControlSize:NSSmallControlSize]]];
                [[(NSTextField *)control cell] setControlSize:NSSmallControlSize];                
                [(NSTextField *)control setStringValue:@"-"];
                [(NSTextField *)control sizeToFit];
            }
            [[control cell] setControlSize:NSSmallControlSize];
            [label setFont:[NSFont systemFontOfSize:[NSFont systemFontSizeForControlSize:NSSmallControlSize]]];            
            if (![type isEqualToString:FFGLParameterTypeImage]) {
                NSMutableDictionary* bindingOptions = [NSMutableDictionary dictionary];
                [bindingOptions setObject:[NSNumber numberWithBool:NO] forKey:NSConditionallySetsEnabledBindingOption];
                [bindingOptions setObject:[NSNumber numberWithBool:YES] forKey:NSRaisesForNotApplicableKeysBindingOption];
                [control bind:@"value" toObject:renderer withKeyPath:[NSString stringWithFormat:@"parameters.%@", key] options:bindingOptions];                
            }
            if (![type isEqualToString:FFGLParameterTypeImage] || hadFirstImage) {
                origin.y += 8 + [control frame].size.height;
                [views addObject:label];
                [views addObject:control];
            } else if ([type isEqualToString:FFGLParameterTypeImage]) {
                hadFirstImage = YES;
            }
        }
        [self setSubviews:views];
        [renderer retain];
        [_renderer release];
        _renderer = renderer;        
    }
}
@end
