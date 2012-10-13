//
//  KOUAsset_Private.h
//  URLKit
//
//  Created by Michael Villar on 4/23/12.
//  Copyright (c) 2012 Noaliasing. All rights reserved.
//

#import "MVAsset.h"

@class MVFileDownload,
       KOUFileUpload;

///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
@interface MVAsset ()

@property (strong, readwrite, nonatomic) MVFileDownload *fileDownload;
@property (strong, readwrite, nonatomic) KOUFileUpload *fileUpload;

@end