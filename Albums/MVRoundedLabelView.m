//
//  MVRoundedLabelView.m
//  Albums
//
//  Created by Michaël Villar on 1/1/13.
//  Copyright (c) 2013 Michael Villar. All rights reserved.
//

#import "MVRoundedLabelView.h"

#define kMVRoundedLabelMargin 12
#define kMVRoundedLabelHeight 28
#define kMVRoundedLabelFont [UIFont systemFontOfSize:16]
#define kMVRoundedLabelColor [UIColor colorWithWhite:1.0 alpha:0.95]
#define kMVRoundedLabelEnabledColor [UIColor colorWithWhite:1.0 alpha:0.95]
#warning use color of background for font color?
#define kMVRoundedLabelEnabledFontColor [UIColor colorWithWhite:0.14 alpha:1]

///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
@implementation MVRoundedLabelView

@synthesize text    = text_,
            enabled = enabled_;

///////////////////////////////////////////////////////////////////////////////////////////////////
- (id)initWithFrame:(CGRect)frame
{
	self = [super initWithFrame:frame];
	if ( self ) {
		text_ = @"";
		
		self.backgroundColor = [UIColor clearColor];
		self.opaque = NO;
	}
	return self;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)sizeToFit
{
	CGSize labelSize = [self.text sizeWithFont:kMVRoundedLabelFont];
	CGRect frame = self.frame;
	frame.size.width = ceilf(labelSize.width) + kMVRoundedLabelMargin * 2;
	frame.size.height = kMVRoundedLabelHeight;
	self.frame = frame;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)drawRect:(CGRect)rect
{
	CGRect rrect = CGRectInset(self.bounds, 1, 1);
	UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:rrect
													cornerRadius:rrect.size.height / 2];
	if ( !self.isEnabled ) {
		[kMVRoundedLabelColor setStroke];
		path.lineWidth = 1;
		[path stroke];
	} else {
		[kMVRoundedLabelEnabledColor set];
		[path fill];
		[kMVRoundedLabelEnabledColor setStroke];
		path.lineWidth = 1;
		[path stroke];
	}
  
	[(!self.isEnabled ? kMVRoundedLabelColor : kMVRoundedLabelEnabledFontColor) set];
	[self.text drawAtPoint:CGPointMake(kMVRoundedLabelMargin, 4)
				  forWidth:self.bounds.size.width
				  withFont:kMVRoundedLabelFont
			 lineBreakMode:NSLineBreakByCharWrapping];
}

@end
