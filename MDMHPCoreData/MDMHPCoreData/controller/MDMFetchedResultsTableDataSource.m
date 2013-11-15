//
//  MDMFetchedREsultsTableDataSource.m
//
//  Created by Matthew Morey (http://matthewmorey.com) on 10/16/13.
//  Copyright (c) 2013 Matthew Morey. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of this
//  software and associated documentation files (the "Software"), to deal in the Software
//  without restriction, including without limitation the rights to use, copy, modify, merge,
//  publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons
//  to whom the Software is furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all copies
//  or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
//  INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
//  PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE
//  FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
//  ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
//  IN THE SOFTWARE.
//

#import "MDMFetchedResultsTableDataSource.h"

@interface MDMFetchedResultsTableDataSource () <NSFetchedResultsControllerDelegate>

@property (nonatomic, strong) NSFetchedResultsController *fetchedResultsController;
@property (nonatomic, strong) UITableView *tableView;

@end

@implementation MDMFetchedResultsTableDataSource

static NSString * const CELL_RESOURCE_IDENTIFIER = @"Cell";

- (id)initWithTableView:(UITableView *)tableView fetchedResultsController:(NSFetchedResultsController *)fetchedResultsController {

    self = [super init];
    if(self) {
        self.tableView = tableView;
        self.fetchedResultsController = fetchedResultsController;
        [self setup];
    }
    return self;
}

- (void)setup {
    
    self.tableView.dataSource = self;
    self.fetchedResultsController.delegate = self;
    BOOL fetchSuccess = [self.fetchedResultsController performFetch:NULL];
    NSAssert(fetchSuccess, @"ASSERT: Fetch request does not include sort descriptor that uses the section name.");
}

- (void)changePredicate:(NSPredicate *)predicate {
    
    NSAssert(self.fetchedResultsController.cacheName == NULL, @"ASSERT: Can't change predicate when you have a caching fetched results controller.");
    NSFetchRequest* fetchRequest = self.fetchedResultsController.fetchRequest;
    fetchRequest.predicate = predicate;
    [self.fetchedResultsController performFetch:NULL];
    [self.tableView reloadData];
}

- (id)itemAtIndexPath:(NSIndexPath *)path {
    
    return [self.fetchedResultsController objectAtIndexPath:[NSIndexPath indexPathForRow:path.row inSection:path.section]];
}

- (id)selectedItem {
    
    return [self itemAtIndexPath:[self.tableView indexPathForSelectedRow]];
}

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)path {
    
    id item = [self itemAtIndexPath:path];
    if(self.configureCellBlock) {
        self.configureCellBlock(cell, item);
    }
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    
    return self.fetchedResultsController.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
   
    NSUInteger i = [self.fetchedResultsController.sections[(NSUInteger) section] numberOfObjects];
    return i;
}

- (NSString*)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
   
    id <NSFetchedResultsSectionInfo> info = [self.fetchedResultsController sections][(NSUInteger) section];
    return info.name;
}

- (UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
   
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CELL_RESOURCE_IDENTIFIER forIndexPath:indexPath];
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

#pragma mark - NSFetchedResultsControllerDelegate

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
    
    [self.tableView endUpdates];
}

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller {
    
    [self.tableView beginUpdates];
}

- (void)controller:(NSFetchedResultsController *)controller
  didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex
     forChangeType:(NSFetchedResultsChangeType)type {
   
    switch(type) {
        case NSFetchedResultsChangeInsert:
            [self.tableView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex]
                          withRowAnimation:UITableViewRowAnimationAutomatic];
            break;

        case NSFetchedResultsChangeDelete:
            [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex]
                          withRowAnimation:UITableViewRowAnimationAutomatic];
            break;
            
        default:
            break;
    }
}

- (void)controller:(NSFetchedResultsController *)controller
   didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath
     forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath {

    switch(type) {
        case NSFetchedResultsChangeInsert:
            [self.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath]
                                  withRowAnimation:UITableViewRowAnimationAutomatic];
            break;

        case NSFetchedResultsChangeDelete:
            [self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
                                  withRowAnimation:UITableViewRowAnimationAutomatic];
            break;

        case NSFetchedResultsChangeUpdate:
            if([self.tableView.indexPathsForVisibleRows indexOfObject:indexPath] != NSNotFound) {
                [self configureCell:[self.tableView cellForRowAtIndexPath:indexPath] atIndexPath:indexPath];
            }
            break;

        case NSFetchedResultsChangeMove:
            [self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
                                  withRowAnimation:UITableViewRowAnimationFade];
            [self.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath]
                                  withRowAnimation:UITableViewRowAnimationAutomatic];
            break;
        default:
            break;
    }
}

@end
