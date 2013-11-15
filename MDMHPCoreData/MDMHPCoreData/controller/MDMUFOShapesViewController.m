//
//  MDMUFOShapesViewController.m
//  MDMHPCoreData
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

#import "MDMUFOShapesViewController.h"
#import <CoreData/CoreData.h>
#import "UFOSighting+Additions.h"

#define TICK NSDate *startTime = [NSDate date]
#define TICK_RESET startTime = [NSDate date]
#define TOCK NSLog(@"Elapsed Time: %f", -[startTime timeIntervalSinceNow])

@interface MDMUFOShapesViewController ()

@property (nonatomic, strong) NSMutableArray *tableDataSource;

@end

@implementation MDMUFOShapesViewController

#pragma mark - View Lifecycle

- (id)initWithStyle:(UITableViewStyle)style {
    
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad {
    
    [super viewDidLoad];
   
    TICK;
    
    // It is better to fetch only want you need, better yet
    //     have SQL perform the calculations for you
    //
    // 1) Use managed objects
    //    [self setupTableDataSourceUsingMangedObjects];
    //
    // 2) Fetch dictionaries of just the values you need instead of managed objects
    //    [self setupTableDataSourceUsingDictionaries];
    //
    // 3) Use SQLite to perform the calculations
    [self setupTableDataSourceUsingExpression];
    
    TOCK;
}

- (void)didReceiveMemoryWarning {
    
    [super didReceiveMemoryWarning];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {

    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    
    return [self.tableDataSource count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    
    // Configure the cell...
    NSDictionary *item = [self.tableDataSource objectAtIndex:indexPath.row];
    cell.textLabel.text = [item objectForKey:UFO_KEY_COREDATA_SHAPE];
    cell.detailTextLabel.text = [item objectForKey:@"count"];
    
    return cell;
}

#pragma mark - Core Data

// 1) Use managed objects)
- (void)setupTableDataSourceUsingMangedObjects {
 
    NSAssert(self.managedObjectContext, @"ASSERT: Forgot to set the managed object context");
    
    // Fetch all managed objects
    NSFetchRequest *shapesFetchRequest = [NSFetchRequest fetchRequestWithEntityName:[UFOSighting entityName]];
    NSArray *UFOSightingsArray = [self.managedObjectContext executeFetchRequest:shapesFetchRequest error:NULL];
    
    // Count unique items
    NSMutableDictionary *uniqueShapesDictionary = [NSMutableDictionary dictionary];
    for (UFOSighting *sighting in UFOSightingsArray) {
        
        NSString *shapeString = sighting.shape;
        NSNumber *shapeCount = [uniqueShapesDictionary objectForKey:shapeString];
        if (shapeCount == nil) {
            [uniqueShapesDictionary setObject:@(1) forKey:shapeString];
        } else {
            [uniqueShapesDictionary setObject:@([shapeCount intValue] + 1) forKey:shapeString];
        }
    }
    
    // Build data source array
    NSMutableArray *uniqueShapesArray = [NSMutableArray array];
    for (NSString *shapeKey in [uniqueShapesDictionary allKeys]) {
        [uniqueShapesArray addObject:@{
                                       @"shape": shapeKey,
                                       @"count": [[uniqueShapesDictionary objectForKey:shapeKey] stringValue]
                                       }];
    }
    
    // Sort array
    NSArray *sortedArray = [uniqueShapesArray sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *obj1, NSDictionary *obj2) {
        
        NSString *string1 = obj1[@"count"];
        NSString *string2 = obj2[@"count"];
        NSNumber *count1 = [NSNumber numberWithInteger:[string1 integerValue]];
        NSNumber *count2 = [NSNumber numberWithInteger:[string2 integerValue]];
        
        return -1 * [count1 compare:count2]; // Reverse sort
    }];
    
    self.tableDataSource = [NSMutableArray arrayWithArray:sortedArray];
}

// 2) Fetch dictionaries of just the values you need instead of managed objects
- (void)setupTableDataSourceUsingDictionaries {
    
    NSAssert(self.managedObjectContext, @"ASSERT: Forgot to set the managed object context");
    
    // Only fetch the shape attributes of each managed object
    NSFetchRequest *shapesFetchRequest = [NSFetchRequest fetchRequestWithEntityName:[UFOSighting entityName]];
    [shapesFetchRequest setResultType:NSDictionaryResultType];
    [shapesFetchRequest setPropertiesToFetch:@[UFO_KEY_COREDATA_SHAPE]];
    NSArray *shapesArray = [self.managedObjectContext executeFetchRequest:shapesFetchRequest error:NULL];

    // Count unique items
    NSMutableDictionary *uniqueShapesDictionary = [NSMutableDictionary dictionary];
    for (NSDictionary *shape in shapesArray) {
        
        NSString *shapeString = [shape objectForKey:@"shape"];
        NSNumber *shapeCount = [uniqueShapesDictionary objectForKey:shapeString];
        if (shapeCount == nil) {
            [uniqueShapesDictionary setObject:@(1) forKey:shapeString];
        } else {
            [uniqueShapesDictionary setObject:@([shapeCount intValue] + 1) forKey:shapeString];
        }
    }
 
    // Build data source array
    NSMutableArray *uniqueShapesArray = [NSMutableArray array];
    for (NSString *shapeKey in [uniqueShapesDictionary allKeys]) {
        [uniqueShapesArray addObject:@{
                                       @"shape": shapeKey,
                                       @"count": [[uniqueShapesDictionary objectForKey:shapeKey] stringValue]
                                       }];
    }
    
    // Sort array
    NSArray *sortedArray = [uniqueShapesArray sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *obj1, NSDictionary *obj2) {
        
        NSString *string1 = obj1[@"count"];
        NSString *string2 = obj2[@"count"];
        NSNumber *count1 = [NSNumber numberWithInteger:[string1 integerValue]];
        NSNumber *count2 = [NSNumber numberWithInteger:[string2 integerValue]];
        
        return -1 * [count1 compare:count2]; // Reverse sort
    }];
    
    self.tableDataSource = [NSMutableArray arrayWithArray:sortedArray];
}

// 3) Use SQLite to perform the calculations
- (void)setupTableDataSourceUsingExpression {
    
    NSAssert(self.managedObjectContext, @"ASSERT: Forgot to set the managed object context");
    
    // Let SQLite calculate unique shapes
    NSExpressionDescription *expressionDescription = [[NSExpressionDescription alloc] init];
    [expressionDescription setName:@"count"];
    [expressionDescription setExpression:[NSExpression expressionForFunction:@"count:"
                                                                   arguments:@[[NSExpression expressionForKeyPath:UFO_KEY_COREDATA_SHAPE]]]];
    NSFetchRequest *uniqueShapes = [NSFetchRequest fetchRequestWithEntityName:[UFOSighting entityName]];
    [uniqueShapes setPropertiesToFetch:@[UFO_KEY_COREDATA_SHAPE, expressionDescription]];
    [uniqueShapes setPropertiesToGroupBy:@[UFO_KEY_COREDATA_SHAPE]];
    [uniqueShapes setResultType:NSDictionaryResultType];
    NSArray *uniqueShapesArray = [self.managedObjectContext executeFetchRequest:uniqueShapes error:NULL];
    
    // Sort results
    NSArray *sortedArray = [uniqueShapesArray sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *obj1, NSDictionary *obj2) {
        
        NSString *string1 = obj1[@"count"];
        NSString *string2 = obj2[@"count"];
        NSNumber *count1 = [NSNumber numberWithInteger:[string1 integerValue]];
        NSNumber *count2 = [NSNumber numberWithInteger:[string2 integerValue]];
        
        return -1 * [count1 compare:count2]; // Reverse sort
    }];
    
    self.tableDataSource = [NSMutableArray arrayWithArray:sortedArray];
}

@end
