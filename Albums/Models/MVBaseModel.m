//
//  MVBaseModel.m
//  Albums
//
//  Created by Michaël on 9/16/12.
//  Copyright (c) 2012 Michael Villar. All rights reserved.
//

#import "MVBaseModel.h"

///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
@interface MVBaseModel ()
+ (NSString *)entityName;
@end

///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
@implementation MVBaseModel

///////////////////////////////////////////////////////////////////////////////////////////////////
+ (MVBaseModel *)objectWithiTunesId:(NSNumber *)iTunesId inMoc:(NSManagedObjectContext *)moc
{
  NSPredicate *predicate = [NSPredicate predicateWithFormat:@"iTunesId == %@", iTunesId];
  NSString *entityName = [self entityName];
  NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:entityName];
  [request setPredicate:predicate];
  
  __block NSArray *requestResults = nil;
  [moc performBlockAndWait:^{
    NSError *error;
    requestResults = [moc executeFetchRequest:request error:&error];
  }];
  
  
  int nbRequests = (int)[requestResults count];
  if (nbRequests != 1)
  {
    if(nbRequests > 1)
      NSLog(@"!!! we should have found 1 %@ but found %d. We were trying to find %@ (remoteId %@)",
            entityName, nbRequests, entityName, iTunesId);
    return nil;
  }
  return [requestResults objectAtIndex:0];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
+ (NSString *)entityName
{
  NSLog(@"entityName should be defined in the mogenerator model and super shouldn't be called");
  return nil;
}

@end