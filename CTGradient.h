//
//  CTGradient.h
//
//  Created by Chad Weider on 12/3/05.
//  Copyright (c) 2005 Cotingent.
//  Some rights reserved: <http://creativecommons.org/licenses/by/2.5/>
//

#import <Cocoa/Cocoa.h>

typedef struct _CTGradientElement 
	{
	float red, green, blue, alpha;
	float position;
	
	struct _CTGradientElement *nextElement;
	} CTGradientElement;


@interface CTGradient : NSObject <NSCopying, NSCoding>
	{
	CTGradientElement* elementList;
	
	CGFunctionRef gradientFunction;
	}

+ (id)gradientWithBeginningColor:(NSColor *)begin endingColor:(NSColor *)end;

+ (id)aquaSelectedGradient;
+ (id)aquaNormalGradient;
+ (id)aquaPressedGradient;

+ (id)unifiedSelectedGradient;
+ (id)unifiedNormalGradient;
+ (id)unifiedPressedGradient;
+ (id)unifiedDarkGradient;

- (CTGradient *)gradientWithAlphaComponent:(float)alpha;

- (CTGradient *)addColorStop:(NSColor *)color atPosition:(float)position;	//positions given relative to [0,1]
- (CTGradient *)removeColorStopAtIndex:(unsigned)index;
- (CTGradient *)removeColorStopAtPosition:(float)position;


- (NSColor *)colorStopAtIndex:(unsigned)index;
- (NSColor *)colorAtPosition:(float)position;


- (void)drawSwatchInRect:(NSRect)rect;
- (void)fillRect:(NSRect)rect angle:(float)angle;					//fills rect with axial gradient
																	//	angle in degrees
- (void)radialFillRect:(NSRect)rect;								//fills rect with radial gradient
																	//  gradient from center outwards
@end
