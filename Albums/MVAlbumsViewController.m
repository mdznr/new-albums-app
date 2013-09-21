//
//  MVAlbumsViewController.m
//  Albums
//
//  Created by Michaël on 9/16/12.
//  Copyright (c) 2012 Michael Villar. All rights reserved.
//

#import <StoreKit/StoreKit.h>
#import "MVAlbumsViewController.h"
#import "MVContextSource.h"
#import "MVAlbum.h"
#import "MVArtist.h"
#import "MVAlbumCell.h"
#import "MVView.h"
#import "MVCoreManager.h"
#import "MVPlaceholderView.h"

///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
@interface MVAlbumsViewController () <UITableViewDataSource,
                                      UITableViewDelegate,
                                      NSFetchedResultsControllerDelegate,
                                      MVAlbumCellDelegate,
                                      UIActionSheetDelegate,
                                      SKStoreProductViewControllerDelegate>

@property (strong, readwrite) UITableView *tableView;
@property (strong, readwrite) NSFetchedResultsController *fetchedResultsController;
@property (strong, readwrite) NSDateFormatter *sectionDateFormatter;
@property (strong, readwrite) MVCoreManager *coreManager;
@property (strong, readwrite) MVArtist *actionSheetArtistToHide;
@property (strong, readwrite, nonatomic) MVPlaceholderView *placeholderView;
@property (readwrite, getter = isPlaceholderVisible) BOOL placeholderVisible;
@property (readwrite) NSUInteger iTunesStoreIncrementCall;
@property (strong, readwrite) NSTimer *iTunesStoreTimer;
@property (strong, readwrite) MVAlbum *iTunesStoreLoadingAlbum;
@property (strong, readwrite) NSObject<MVContextSource> *contextSource;

- (void)reloadTableViewAfterBlock:(void(^)(void))block;
- (void)updatePlaceholder:(BOOL)animated;
- (void)displayiTunesError:(NSString*)message;

@end

///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
@implementation MVAlbumsViewController

// -- Private
@synthesize tableView                 = tableView_,
            fetchedResultsController  = fetchedResultsController_,
            sectionDateFormatter      = sectionDateFormatter_,
            coreManager               = coreManager_,
            actionSheetArtistToHide   = actionSheetArtistToHide_,
            placeholderView           = placeholderView_,
            placeholderVisible        = placeholderVisible_,
            iTunesStoreIncrementCall  = iTunesStoreIncrementCall_,
            iTunesStoreTimer          = iTunesStoreTimer_,
            iTunesStoreLoadingAlbum   = iTunesStoreLoadingAlbum_,
            contextSource             = contextSource_;

///////////////////////////////////////////////////////////////////////////////////////////////////
- (id)initWithContextSource:(NSObject<MVContextSource>*)contextSource
                coreManager:(MVCoreManager*)coreManager
{
  self = [super init];
  if (self)
  {
    tableView_ = nil;
    contextSource_ = contextSource;
    coreManager_ = coreManager;
    actionSheetArtistToHide_ = nil;
    placeholderView_ = nil;
    placeholderVisible_ = NO;
    iTunesStoreIncrementCall_ = 0;
    iTunesStoreTimer_ = nil;
    iTunesStoreLoadingAlbum_ = nil;

    NSFetchRequest *req = [[NSFetchRequest alloc] initWithEntityName:[MVAlbum entityName]];
    NSSortDescriptor *sortCreatedAt = [[NSSortDescriptor alloc]
                                          initWithKey:@"createdAt"
                                            ascending:NO];
    NSSortDescriptor *sortReleaseDate = [[NSSortDescriptor alloc]
                                         initWithKey:@"releaseDate"
                                           ascending:NO];
    req.sortDescriptors = [NSArray arrayWithObjects:sortCreatedAt, sortReleaseDate, nil];
    req.fetchBatchSize = 20;
    req.predicate = [NSPredicate predicateWithFormat:
                     @"hidden == %d AND \
                     artist.hidden == %d AND \
                     releaseDate >= %@",
                     NO, NO, [NSDate dateWithTimeIntervalSinceNow:- 2 * 30 * 24 * 3600]];

    fetchedResultsController_ = [[NSFetchedResultsController alloc] initWithFetchRequest:req
																	managedObjectContext:contextSource.uiMoc
																	  sectionNameKeyPath:nil
																			   cacheName:nil];
    fetchedResultsController_.delegate = self;
   
    sectionDateFormatter_ = [[NSDateFormatter alloc] init];
    sectionDateFormatter_.dateFormat = @"MM/dd";
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(syncDidStart:)
                                                 name:kMVNotificationSyncDidStart
                                               object:self.coreManager];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(syncProgress:)
                                                 name:kMVNotificationSyncDidProgress
                                               object:self.coreManager];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(syncDidFinish:)
                                                 name:kMVNotificationSyncDidFinish
                                               object:self.coreManager];
  }
  return self;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)loadView
{
	self.view = [[UIView alloc] initWithFrame:[[UIScreen mainScreen] applicationFrame]];
	self.view.backgroundColor = [UIColor clearColor];

	self.tableView = [[UITableView alloc] initWithFrame:CGRectOffset(self.view.bounds, 0, 20)
												  style:UITableViewStylePlain];
	self.tableView.backgroundColor = [UIColor clearColor];
	self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
	self.tableView.rowHeight = 50.0;
	self.tableView.delegate = self;
	self.tableView.dataSource = self;
	self.tableView.canCancelContentTouches = NO;
	[self.view addSubview:self.tableView];

	[self.fetchedResultsController performFetch:nil];
	[self updatePlaceholder:NO];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)viewDidLoad
{
  [super viewDidLoad];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)viewDidUnload
{
  [super viewDidUnload];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark UITableViewDelegate Methods

///////////////////////////////////////////////////////////////////////////////////////////////////
- (NSIndexPath*)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  NSIndexPath *currentIndexPath = self.tableView.indexPathForSelectedRow;
  if([self.tableView.indexPathsForVisibleRows containsObject:currentIndexPath]) {
    MVAlbumCell *cell = (MVAlbumCell*)[self.tableView cellForRowAtIndexPath:currentIndexPath];
    cell.loading = NO;
  }
  
  return indexPath;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  MVAlbum *album = [self.fetchedResultsController objectAtIndexPath:indexPath];
  
  if(NSClassFromString(@"SKStoreProductViewController"))
  {
    self.iTunesStoreLoadingAlbum = album;

    MVAlbumCell *cell = (MVAlbumCell*)[tableView cellForRowAtIndexPath:indexPath];
    cell.loading = YES;
    SKStoreProductViewController *storeController = [[SKStoreProductViewController alloc] init];
    storeController.delegate = self;
    NSDictionary *productParameters = [NSDictionary dictionaryWithObject:album.iTunesId.copy
                                              forKey:SKStoreProductParameterITunesItemIdentifier];
    
    if(self.iTunesStoreTimer)
      [self.iTunesStoreTimer invalidate];
    self.iTunesStoreTimer = [NSTimer scheduledTimerWithTimeInterval:10 target:self
                                                        selector:@selector(iTunesStoreTimerAction:)
                                                           userInfo:nil repeats:NO];
    
    self.iTunesStoreIncrementCall++;
    NSUInteger currentiTunesStoreIncrementCall = self.iTunesStoreIncrementCall;
    
    [storeController loadProductWithParameters:productParameters
                               completionBlock:^(BOOL result, NSError *error)
     {
       if (currentiTunesStoreIncrementCall != self.iTunesStoreIncrementCall)
         return;
       
       self.iTunesStoreLoadingAlbum = nil;
       
       if(self.iTunesStoreTimer) {
         [self.iTunesStoreTimer invalidate];
         self.iTunesStoreTimer = nil;
       }
       
       if (result) {
         [self presentViewController:storeController animated:YES completion:^{
           cell.loading = NO;
           [tableView deselectRowAtIndexPath:tableView.indexPathForSelectedRow
                                    animated:NO];
         }];
       } else {
         cell.loading = NO;
         [tableView deselectRowAtIndexPath:indexPath animated:YES];
         [self displayiTunesError:error.localizedDescription];
       }
     }];
  }
  else
  {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:album.iTunesStoreUrl]];
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
  }
}

///////////////////////////////////////////////////////////////////////////////////////////////////
- (BOOL)tableView:(UITableView *)tableView shouldShowMenuForRowAtIndexPath:(NSIndexPath *)indexPath
{
  return YES;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
- (BOOL)tableView:(UITableView *)tableView canPerformAction:(SEL)action
forRowAtIndexPath:(NSIndexPath *)indexPath withSender:(id)sender
{
  return action == @selector(copy:);
}

///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)tableView:(UITableView *)tableView performAction:(SEL)action
forRowAtIndexPath:(NSIndexPath *)indexPath withSender:(id)sender
{
  if(action == @selector(copy:))
  {
    MVAlbum *album = [self.fetchedResultsController objectAtIndexPath:indexPath];
    UIPasteboard *pboard = [UIPasteboard generalPasteboard];
    [pboard setURL:[NSURL URLWithString:album.iTunesStoreUrl]];
  }
}

///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark UITableViewDataSource Methods

///////////////////////////////////////////////////////////////////////////////////////////////////
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
  return self.fetchedResultsController.sections.count;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section
{
  NSInteger rows =  [[[self.fetchedResultsController sections] objectAtIndex:section]
                     numberOfObjects];
  return rows;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
  return [MVAlbumCell rowHeight];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  MVAlbum *album = [self.fetchedResultsController objectAtIndexPath:indexPath];
  NSString *cellIdentifier = @"cellIdentifier";
  
  MVAlbumCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
  if(!cell)
  {
    cell = [[MVAlbumCell alloc] initWithStyle:UITableViewCellStyleDefault
                              reuseIdentifier:cellIdentifier];
    cell.tableView = tableView;
  }
  cell.loading = (self.iTunesStoreLoadingAlbum &&
                  [self.iTunesStoreLoadingAlbum.objectID isEqual:album.objectID]);
  cell.delegate = self;
  cell.album = album;
  [cell setNeedsDisplay];
  return cell;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView
{
  return [NSArray array];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark NSFetchedResultsControllerDelegate Methods

///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller
{
}

///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
  [self.tableView reloadData];
  [self updatePlaceholder:YES];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark MVAlbumCellDelegate Methods

///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)albumCellDidTriggerHideAlbum:(MVAlbumCell *)albumCell
{
  [self reloadTableViewAfterBlock:^{
    MVAlbum *album = albumCell.album;
    album.hiddenValue = YES;
    [self.contextSource.uiMoc mv_save];
  }];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)albumCellDidTriggerHideArtist:(MVAlbumCell *)albumCell
{
  NSString *hideTitle = NSLocalizedString(@"Hide Artist", @"Hide Artist in Action Sheet");
  NSString *title = [NSString stringWithFormat:
                     NSLocalizedString(@"Permanently hide %@ from the suggestions",
                                       @"Permanently hide artist from the suggestions"),
                     albumCell.album.artist.name];
  UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:title
                                                           delegate:self
                                                  cancelButtonTitle:NSLocalizedString(@"Cancel",
                                                                                      @"Cancel")
                                             destructiveButtonTitle:hideTitle
                                                  otherButtonTitles:nil];
  self.actionSheetArtistToHide = albumCell.album.artist;
  [actionSheet showInView:self.view];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Notifications Methods

///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)syncDidStart:(NSNotification*)notification
{}

///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)syncDidFinish:(NSNotification*)notification
{}

///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)syncProgress:(NSNotification*)notification
{}

///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Timer Action Methods

///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)iTunesStoreTimerAction:(NSTimer*)timer
{
  if(timer == self.iTunesStoreTimer)
    self.iTunesStoreTimer = nil;
  self.iTunesStoreIncrementCall++;
  NSIndexPath *indexPath = self.tableView.indexPathForSelectedRow;
  [self.tableView deselectRowAtIndexPath:indexPath animated:NO];
  if([self.tableView.indexPathsForVisibleRows containsObject:indexPath]) {
    MVAlbumCell *cell = (MVAlbumCell*)[self.tableView cellForRowAtIndexPath:indexPath];
    cell.loading = NO;
  }
  self.iTunesStoreLoadingAlbum = nil;
  [self displayiTunesError:NSLocalizedString(@"There was an error while opening the iTunes Store",
                                             @"Unknown iTunes Error")];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Private Methods

///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)reloadTableViewAfterBlock:(void(^)(void))block
{
  NSArray *oldObjects = [NSArray arrayWithArray:self.fetchedResultsController.fetchedObjects];
  self.fetchedResultsController.delegate = nil;
  
  block();
  
  [self.fetchedResultsController performFetch:nil];
  self.fetchedResultsController.delegate = self;
  
  NSMutableArray *indexPathsToDelete = [NSMutableArray array];
  NSMutableArray *indexPathsToInsert = [NSMutableArray array];
  NSIndexPath *indexPath;
  MVAlbum *album;
  NSArray *newObjects = [NSArray arrayWithArray:self.fetchedResultsController.fetchedObjects];
  NSUInteger oldObjectsCount = oldObjects.count;
  NSUInteger newObjectsCount = newObjects.count;
  
  for(NSUInteger i=0;i<oldObjectsCount;i++)
  {
    album = [oldObjects objectAtIndex:i];
    if(![newObjects containsObject:album])
    {
      indexPath = [NSIndexPath indexPathForRow:i inSection:0];
      [indexPathsToDelete addObject:indexPath];
    }
  }
  for(NSUInteger i=0;i<newObjectsCount;i++)
  {
    album = [newObjects objectAtIndex:i];
    if(![oldObjects containsObject:album])
    {
      indexPath = [NSIndexPath indexPathForRow:i inSection:0];
      [indexPathsToInsert addObject:indexPath];
    }
  }
  
  [self.tableView beginUpdates];
  if ([indexPathsToDelete count] > 0) {
    [self.tableView deleteRowsAtIndexPaths:indexPathsToDelete
                          withRowAnimation:UITableViewRowAnimationBottom];
  }
  if ([indexPathsToInsert count] > 0) {
    [self.tableView insertRowsAtIndexPaths:indexPathsToInsert
                          withRowAnimation:UITableViewRowAnimationBottom];
  }
  [self.tableView endUpdates];
  
  NSArray *visibleIndexPaths = self.tableView.indexPathsForVisibleRows;
  for (NSIndexPath *indexPath in visibleIndexPaths)
  {
    // if first row is visible, layout it
    // (because if the row before it was removed, corners have changed
    if (indexPath.row == 0)
      [[self.tableView cellForRowAtIndexPath:indexPath] setNeedsLayout];
    // if last row is visible, layout it
    // (because if the row after it was removed, corners have changed
    else if (indexPath.row == newObjects.count - 1)
      [[self.tableView cellForRowAtIndexPath:indexPath] setNeedsLayout];
  }
  
  [self updatePlaceholder:YES];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)updatePlaceholder:(BOOL)animated
{
  if(self.fetchedResultsController.fetchedObjects.count == 0)
  {
    if(!self.placeholderVisible)
    {
      self.placeholderVisible = YES;
      self.placeholderView.alpha = 0.0;
      [self.view addSubview:self.placeholderView];
      [UIView animateWithDuration:0.2 animations:^{
        [UIView setAnimationsEnabled:animated];
        self.placeholderView.alpha = 1.0;
        [UIView setAnimationsEnabled:YES];
      }];
    }
  }
  else if(self.placeholderVisible)
  {
    self.placeholderVisible = NO;
    [UIView animateWithDuration:0.2 animations:^{
      [UIView setAnimationsEnabled:animated];
      self.placeholderView.alpha = 0.0;
      [UIView setAnimationsEnabled:YES];
    } completion:^(BOOL finished) {
      [self.placeholderView removeFromSuperview];
    }];
  }
}

///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)displayiTunesError:(NSString*)message
{
  NSString *title = NSLocalizedString(@"Error",
                                      @"iTunes Error");
  [[[UIAlertView alloc] initWithTitle:title
                              message:message
                             delegate:nil
                    cancelButtonTitle:NSLocalizedString(@"OK", @"iTunes Error OK Button")
                    otherButtonTitles:nil] show];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Private Properties

///////////////////////////////////////////////////////////////////////////////////////////////////
- (MVPlaceholderView*)placeholderView
{
  if(!placeholderView_)
  {
    placeholderView_ = [[MVPlaceholderView alloc] initWithFrame:self.view.bounds];
  }
  return placeholderView_;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark UIActionSheetDelegate

///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
  if(buttonIndex == 0)
  {
    __block __weak MVAlbumsViewController *weakSelf = self;
    [self reloadTableViewAfterBlock:^{
      weakSelf.actionSheetArtistToHide.hiddenValue = YES;
      [weakSelf.contextSource.uiMoc mv_save];
      weakSelf.actionSheetArtistToHide = nil;
    }];
  }
}

///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark SKStoreProductViewControllerDelegate

///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)productViewControllerDidFinish:(SKStoreProductViewController *)viewController
{
  [self dismissViewControllerAnimated:YES completion:^{
  }];
}

@end
