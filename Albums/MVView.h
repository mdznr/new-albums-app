//
//  MVView.h
//  Albums
//
//  Created by Michaël on 9/30/12.
//  Copyright (c) 2012 Michael Villar. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef void(^DrawBlock)(UIView* v, CGContextRef context);

///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
@interface MVView : UIView

@property (nonatomic,copy) DrawBlock drawBlock;

@end
