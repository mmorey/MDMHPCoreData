//
//  MDMUFOSightingImportOperation.m
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

#import "MDMUFOSightingImportOperation.h"
#import "MDMPersistenceStack.h"
#import "NSDictionary+MDMAdditions.h"
#import "UFOSighting+Additions.h"

NSString *const MDM_NOTIFICATION_IMPORT_OPERATION_COMPLETE = @"MDM_NOTIFICATION_IMPORT_OPERATION_COMPLETE";
static const NSUInteger MDM_BATCH_SIZE_IMPORT = 5000;
static const NSUInteger MDM_BATCH_SIZE_SAVE = 5000;

@interface MDMUFOSightingImportOperation ()

@property (nonatomic, strong) MDMPersistenceStack *persistenceStack;
@property (nonatomic, strong) NSURL *importFileURL;
@property (nonatomic, strong) NSManagedObjectContext *managedObjectContext;

@end

@implementation MDMUFOSightingImportOperation

- (id)initWithPersistenceStack:(MDMPersistenceStack *)persistenceStack importFileURL:(NSURL *)fileURL {

    self = [super init];
    if(self) {
        self.persistenceStack = persistenceStack;
        self.importFileURL = fileURL;
    }
    return self;
}

- (void)main {
    
    //
    // 1) WORST: Main queue context with naive find-or-create algorithm.
    //           Will block UI and take a long time.
    //
    //    self.managedObjectContext = self.persistenceStack.managedObjectContext;
    //    self.managedObjectContext.undoManager = nil;
    //    [self.managedObjectContext performBlockAndWait:^{
    //         [self import];
    //    }];
    
    //
    // 2) BAD: Private queue context with naive find-or-create algorithm.
    //         Will not block UI, but will take a long time.
    //
    //    self.managedObjectContext = [self.persistenceStack newPrivateManagedObjectContext];
    //    self.managedObjectContext.undoManager = nil;
    //    [self.managedObjectContext performBlockAndWait:^{
    //         [self import];
    //    }];
    
    //
    // 3) GOOD: Private queue context with efficient find-or-create importing
    //          algorithm. Will not block UI, but will have high memory usage.
    //
    //    self.managedObjectContext = [self.persistenceStack newPrivateManagedObjectContext];
    //    self.managedObjectContext.undoManager = nil;
    //    [self.managedObjectContext performBlockAndWait:^{
    //        [self importWithEfficientFindOrCreate];
    //    }];
    
    //
    // 4) GOOD: Private queue context with efficient find-or-create importing
    //          and saving algorithm. Will not block UI, but will have high memory usage.
    //
    //    self.managedObjectContext = [self.persistenceStack newPrivateManagedObjectContext];
    //    self.managedObjectContext.undoManager = nil;
    //    [self.managedObjectContext performBlockAndWait:^{
    //        [self importWithEfficientFindOrCreateAndPeriodicSaves];
    //    }];
    
    //
    // 5) GOOD: Private queue context with efficient find-or-create importing
    //          and saving algorithm. Will not block UI, but will have high memory usage.
    //          View controllers should reload/refresh after importing is complete
    //
    //    self.managedObjectContext = [self.persistenceStack newPrivateManagedObjectContext];
    //    self.managedObjectContext.undoManager = nil;
    //    [self.managedObjectContext performBlockAndWait:^{
    //        self.persistenceStack.disableMergeNotifications = YES;
    //        [self importWithEfficientFindOrCreate];
    //        self.persistenceStack.disableMergeNotifications = NO;
    // 
    //        // Notify everyone that an import operation has been completed
    //        [[NSNotificationCenter defaultCenter] postNotificationName:MDM_NOTIFICATION_IMPORT_OPERATION_COMPLETE
    //                                                            object:self];
    //    }];

    //
    // 6) GOOD: Private queue context with independent persistent store coordinator
    //          With batch importing and saving algorithm
    //          Will not block UI, but will have high memory usage
    //          View controllers should reload/refresh after importing is complete
    //          Takes advantage of SQLite WAL mode (only avilable on iOS 7+)
    //
    //    self.managedObjectContext = [self.persistenceStack newPrivateManagedObjectContextWithNewPersistentStoreCoordinator];
    //    self.managedObjectContext.undoManager = nil;
    //    [self.managedObjectContext performBlockAndWait:^{
    //        self.persistenceStack.disableMergeNotifications = YES;
    //        [self importWithEfficientFindOrCreate];
    //        self.persistenceStack.disableMergeNotifications = NO;
    // 
    //        // Notify everyone that an import operation has been completed
    //        [[NSNotificationCenter defaultCenter] postNotificationName:MDM_NOTIFICATION_IMPORT_OPERATION_COMPLETE
    //                                                            object:self];
    //    }];
    
    // 7) BEST: Number 6 but with import batching to reduce memory usage
    //
    self.managedObjectContext = [self.persistenceStack newPrivateManagedObjectContextWithNewPersistentStoreCoordinator];
    self.managedObjectContext.undoManager = nil;
    [self.managedObjectContext performBlockAndWait:^{
        self.persistenceStack.disableMergeNotifications = YES;
        [self batchImportWithEfficientFindOrCreateAndPeriodicSaves];
        self.persistenceStack.disableMergeNotifications = NO;
 
        // Notify everyone that an import operation has been completed
        [[NSNotificationCenter defaultCenter] postNotificationName:MDM_NOTIFICATION_IMPORT_OPERATION_COMPLETE
                                                            object:self];
    }];
}

- (void)saveManagedObjectContext {

    NSError *saveError;
    if ([self.managedObjectContext save:&saveError] == NO) {
        NSLog(@"ERROR: Could not save managed object context\n%@", [saveError localizedDescription]);
        NSAssert(NO, @"ASSERT: NSManagedObjectContext Save Error");
        // TODO: Implement proper error handling for your app/situation
    }
}

- (void)import {
    
    // Serialize JSON data
    NSData *jsonData = [[NSData alloc] initWithContentsOfFile:[self.importFileURL path]];
    NSError *error = nil;
    NSArray *UFOSightingsArray = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingMutableContainers error:&error];
    NSUInteger totalUFOSightings = [UFOSightingsArray count];
    NSUInteger progressCallbackGranularity = totalUFOSightings/100;
 
    // Import data
    NSInteger counter = 0;
    for (NSDictionary *UFOSightingDictionary in UFOSightingsArray) {
        
        counter++;
 
        // Operation was cancelled
        if (self.isCancelled) {
            return;
        }
        
        // Import/create NSManagedObjects
        [UFOSighting importSighting:UFOSightingDictionary intoContext:self.managedObjectContext];
        
        // Update progress callback
        if (counter % progressCallbackGranularity == 0) {
            [self updateProgress:(counter / ((float)totalUFOSightings))];
        }
        
        // Save batch
        if (counter % MDM_BATCH_SIZE_SAVE == 0) {
            // NSLog(@"saving: %li", (long)counter);
            [self saveManagedObjectContext];
        }
    }
    
    // Set progress to 100%
    [self updateProgress:1];
    
    // Perform final save
    [self saveManagedObjectContext];
}

- (void)importWithEfficientFindOrCreate {
    
    // Serialize JSON data
    NSData *jsonData = [[NSData alloc] initWithContentsOfFile:[self.importFileURL path]];
    NSError *error = nil;
    NSArray *UFOSightingsArray = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingMutableContainers error:&error];
    NSUInteger totalUFOSightings = [UFOSightingsArray count];
    NSUInteger progressCallbackGranularity = totalUFOSightings/100;

    // Sort JSON results by unique attribute
    NSArray *sortedArray = [UFOSightingsArray sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *obj1, NSDictionary *obj2) {
        NSString *string1 = obj1[UFO_KEY_JSON_GUID];
        NSString *string2 = obj2[UFO_KEY_JSON_GUID];
        return [string1 compare:string2];
    }];

    // Grab sorted persisted managed objects
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] initWithEntityName:[UFOSighting entityName]];
    NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:UFO_KEY_COREDATA_GUID ascending:YES];
    [fetchRequest setSortDescriptors:@[sortDescriptor]];
    NSError *fetchError;
    NSArray *fetchResults = [self.managedObjectContext executeFetchRequest:fetchRequest error:&fetchError];
    if (fetchResults == nil) {
        NSLog(@"ERROR: Could not execute fetch request\n%@", [fetchError localizedDescription]);
        NSAssert(NO, @"ASSERT: Fetch request failed");
        // TODO: Implement proper error handling for your unique app/situation
    }
    
    // Create enumerators
    NSEnumerator *jsonEnumerator = [sortedArray objectEnumerator];
    NSEnumerator *fetchResultsEnumerator = [fetchResults objectEnumerator];
    NSDictionary *UFOSightingDictionary = [jsonEnumerator nextObject];
    UFOSighting *UFOSightingManagedObject = [fetchResultsEnumerator nextObject];
    
    NSInteger counter = 0;
    while (UFOSightingDictionary) {
        
        counter++;
        
        // Operation was cancelled
        if (self.isCancelled) {
            return;
        }
        
        // Check if managed object already exist
        BOOL isUpdate = NO;
        if ([[UFOSightingDictionary objectForKeyOrNil:UFO_KEY_JSON_GUID] isEqualToString:UFOSightingManagedObject.guid]) {
            isUpdate = YES;
        }
        
        // Not an update, create new managed object
        if (isUpdate == NO) {
            UFOSightingManagedObject = [UFOSighting insertNewObjectIntoContext:self.managedObjectContext];
            UFOSightingManagedObject.guid = [UFOSightingDictionary objectForKeyOrNil:UFO_KEY_JSON_GUID];
        }
        
        // Set new attributes
        UFOSightingManagedObject.reported = [UFOSighting dateFromString:[UFOSightingDictionary objectForKeyOrNil:UFO_KEY_JSON_REPORTED]];
        UFOSightingManagedObject.sighted = [UFOSighting dateFromString:[UFOSightingDictionary objectForKeyOrNil:UFO_KEY_JSON_SIGHTED]];
        UFOSightingManagedObject.shape = [UFOSightingDictionary objectForKeyOrNil:UFO_KEY_JSON_SHAPE];
        UFOSightingManagedObject.location = [UFOSightingDictionary objectForKeyOrNil:UFO_KEY_JSON_LOCATION];
        UFOSightingManagedObject.duration = [UFOSightingDictionary objectForKeyOrNil:UFO_KEY_JSON_DURATION];
        UFOSightingManagedObject.desc = [UFOSightingDictionary objectForKeyOrNil:UFO_KEY_JSON_DESC];
        
        if (isUpdate) {
            UFOSightingDictionary = [jsonEnumerator nextObject];
            UFOSightingManagedObject = [fetchResultsEnumerator nextObject];
        } else {
            UFOSightingDictionary = [jsonEnumerator nextObject];
        }
        
        // Update progress callback
        if (counter % progressCallbackGranularity == 0) {
            [self updateProgress:(counter / ((float)totalUFOSightings))];
        }
    }
    
    // Set progress to 100%
    [self updateProgress:1];
    
    // Perform final save
    [self saveManagedObjectContext];
}

- (void)importWithEfficientFindOrCreateAndPeriodicSaves {
    
    // Serialize JSON data
    NSData *jsonData = [[NSData alloc] initWithContentsOfFile:[self.importFileURL path]];
    NSError *error = nil;
    NSArray *UFOSightingsArray = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingMutableContainers error:&error];
    NSUInteger totalUFOSightings = [UFOSightingsArray count];
    NSUInteger progressCallbackGranularity = totalUFOSightings/100;
    
    // Sort JSON results by unique attribute
    NSArray *sortedArray = [UFOSightingsArray sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *obj1, NSDictionary *obj2) {
        NSString *string1 = obj1[UFO_KEY_JSON_GUID];
        NSString *string2 = obj2[UFO_KEY_JSON_GUID];
        return [string1 compare:string2];
    }];
    
    // Grab sorted persisted managed objects
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] initWithEntityName:[UFOSighting entityName]];
    NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:UFO_KEY_COREDATA_GUID ascending:YES];
    [fetchRequest setSortDescriptors:@[sortDescriptor]];
    NSError *fetchError;
    NSArray *fetchResults = [self.managedObjectContext executeFetchRequest:fetchRequest error:&fetchError];
    if (fetchResults == nil) {
        NSLog(@"ERROR: Could not execute fetch request\n%@", [fetchError localizedDescription]);
        NSAssert(NO, @"ASSERT: Fetch request failed");
        // TODO: Implement proper error handling for your unique app/situation
    }
    
    // Create enumerators
    NSEnumerator *jsonEnumerator = [sortedArray objectEnumerator];
    NSEnumerator *fetchResultsEnumerator = [fetchResults objectEnumerator];
    NSDictionary *UFOSightingDictionary = [jsonEnumerator nextObject];
    UFOSighting *UFOSightingManagedObject = [fetchResultsEnumerator nextObject];
    
    NSInteger counter = 0;
    while (UFOSightingDictionary) {
        
        counter++;
       
        // Operation was cancelled
        if (self.isCancelled) {
            return;
        }
        
        // Check if managed object already exist
        BOOL isUpdate = NO;
        if ([[UFOSightingDictionary objectForKeyOrNil:UFO_KEY_JSON_GUID] isEqualToString:UFOSightingManagedObject.guid]) {
            isUpdate = YES;
        }
        
        // Not an update, create new managed object
        if (isUpdate == NO) {
            UFOSightingManagedObject = [UFOSighting insertNewObjectIntoContext:self.managedObjectContext];
            UFOSightingManagedObject.guid = [UFOSightingDictionary objectForKeyOrNil:UFO_KEY_JSON_GUID];
        }
        
        // Set new attributes
        UFOSightingManagedObject.reported = [UFOSighting dateFromString:[UFOSightingDictionary objectForKeyOrNil:UFO_KEY_JSON_REPORTED]];
        UFOSightingManagedObject.sighted = [UFOSighting dateFromString:[UFOSightingDictionary objectForKeyOrNil:UFO_KEY_JSON_SIGHTED]];
        UFOSightingManagedObject.shape = [UFOSightingDictionary objectForKeyOrNil:UFO_KEY_JSON_SHAPE];
        UFOSightingManagedObject.location = [UFOSightingDictionary objectForKeyOrNil:UFO_KEY_JSON_LOCATION];
        UFOSightingManagedObject.duration = [UFOSightingDictionary objectForKeyOrNil:UFO_KEY_JSON_DURATION];
        UFOSightingManagedObject.desc = [UFOSightingDictionary objectForKeyOrNil:UFO_KEY_JSON_DESC];
        
        if (isUpdate) {
            UFOSightingDictionary = [jsonEnumerator nextObject];
            UFOSightingManagedObject = [fetchResultsEnumerator nextObject];
        } else {
            UFOSightingDictionary = [jsonEnumerator nextObject];
        }
        
        // Update progress callback
        if (counter % progressCallbackGranularity == 0) {
            [self updateProgress:(counter / ((float)totalUFOSightings))];
        }
        
        // Save batch
        if (counter % MDM_BATCH_SIZE_SAVE == 0) {
            // NSLog(@"saving: %li", (long)counter);
            [self saveManagedObjectContext];
        }
        
    }
    
    // Set progress to 100%
    [self updateProgress:1];
    
    // Perform final save
    [self saveManagedObjectContext];
}

- (void)batchImportWithEfficientFindOrCreateAndPeriodicSaves {
    
    // Serialize JSON data
    NSData *jsonData = [[NSData alloc] initWithContentsOfFile:[self.importFileURL path]];
    NSError *error = nil;
    NSArray *UFOSightingsArray = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingMutableContainers error:&error];

    NSUInteger totalUFOSightings = [UFOSightingsArray count];
    NSUInteger progressCallbackGranularity = totalUFOSightings/100;
    NSInteger totalBatches = totalUFOSightings / MDM_BATCH_SIZE_IMPORT;
    
    // Sort JSON results by unique attribute
    NSArray *sortedArray = [UFOSightingsArray sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *obj1, NSDictionary *obj2) {
        NSString *string1 = obj1[UFO_KEY_JSON_GUID];
        NSString *string2 = obj2[UFO_KEY_JSON_GUID];
        return [string1 compare:string2];
    }];
    
    // Create array with just the GUIDs keys
    NSArray *jsonGUIDArray = [sortedArray valueForKey:UFO_KEY_JSON_GUID];
    
    for (NSInteger batchCounter = 0; batchCounter <= totalBatches; batchCounter++) {
        
        // Create batch range based on batch size
        NSRange range = NSMakeRange(batchCounter * MDM_BATCH_SIZE_IMPORT, MDM_BATCH_SIZE_IMPORT);
        
        // Last iteration is not divisable by batch size, recalculate length
        if (batchCounter == totalBatches) {
            range.length = totalUFOSightings - (batchCounter * MDM_BATCH_SIZE_IMPORT);
        }
        NSArray *jsonBatchGUIDArray = [jsonGUIDArray subarrayWithRange:range];
//        NSLog(@"\nIteration: %i of %i\nRange location: %lu\nRange length:%lu", batchCounter, totalBatches, (unsigned long)range.location, (unsigned long)range.length);
        
        // Grab sorted persisted managed objects, based on the batch
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] initWithEntityName:[UFOSighting entityName]];
        NSPredicate *fetchPredicate = [NSPredicate predicateWithFormat:@"%K IN %@", UFO_KEY_COREDATA_GUID, jsonBatchGUIDArray];
        [fetchRequest setPredicate:fetchPredicate];
        NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:UFO_KEY_COREDATA_GUID ascending:YES];
        [fetchRequest setSortDescriptors:@[sortDescriptor]];
        NSError *fetchError;
        NSArray *fetchResults = [self.managedObjectContext executeFetchRequest:fetchRequest error:&fetchError];
        if (fetchResults == nil) {
            NSLog(@"ERROR: Could not execute fetch request\n%@", [fetchError localizedDescription]);
            NSAssert(NO, @"ASSERT: Fetch request failed");
            // TODO: Implement proper error handling for your unique app/situation
        }
        
        // Create enumerators
        NSEnumerator *jsonEnumerator = [[sortedArray subarrayWithRange:range] objectEnumerator];
        NSEnumerator *fetchResultsEnumerator = [fetchResults objectEnumerator];
        NSDictionary *UFOSightingDictionary = [jsonEnumerator nextObject];
        UFOSighting *UFOSightingManagedObject = [fetchResultsEnumerator nextObject];
        
        NSInteger counter = 0;
        while (UFOSightingDictionary) {
            
            counter++;
            
            // Operation was cancelled
            if (self.isCancelled) {
                return;
            }
            
            // Check if managed object already exist
            BOOL isUpdate = NO;
            if ([[UFOSightingDictionary objectForKeyOrNil:UFO_KEY_JSON_GUID] isEqualToString:UFOSightingManagedObject.guid]) {
                isUpdate = YES;
            }
            
            // Not an update, create new managed object
            if (isUpdate == NO) {
                UFOSightingManagedObject = [UFOSighting insertNewObjectIntoContext:self.managedObjectContext];
                UFOSightingManagedObject.guid = [UFOSightingDictionary objectForKeyOrNil:UFO_KEY_JSON_GUID];
            }
            
            // Set new attributes
            UFOSightingManagedObject.reported = [UFOSighting dateFromString:[UFOSightingDictionary objectForKeyOrNil:UFO_KEY_JSON_REPORTED]];
            UFOSightingManagedObject.sighted = [UFOSighting dateFromString:[UFOSightingDictionary objectForKeyOrNil:UFO_KEY_JSON_SIGHTED]];
            UFOSightingManagedObject.shape = [UFOSightingDictionary objectForKeyOrNil:UFO_KEY_JSON_SHAPE];
            UFOSightingManagedObject.location = [UFOSightingDictionary objectForKeyOrNil:UFO_KEY_JSON_LOCATION];
            UFOSightingManagedObject.duration = [UFOSightingDictionary objectForKeyOrNil:UFO_KEY_JSON_DURATION];
            UFOSightingManagedObject.desc = [UFOSightingDictionary objectForKeyOrNil:UFO_KEY_JSON_DESC];
            
            if (isUpdate) {
                UFOSightingDictionary = [jsonEnumerator nextObject];
                UFOSightingManagedObject = [fetchResultsEnumerator nextObject];
            } else {
                UFOSightingDictionary = [jsonEnumerator nextObject];
            }
            
            // Update progress callback
            if (counter % progressCallbackGranularity == 0) {
                [self updateProgress:((counter + (batchCounter * MDM_BATCH_SIZE_IMPORT)) / ((float)totalUFOSightings))];
            }
            
            // Save batch
            if (counter % MDM_BATCH_SIZE_SAVE == 0) {
                // NSLog(@"Saving: %li", (long)counter);
                [self saveManagedObjectContext];
            }
        } // while (UFOSightingDictionary) {
    } // for (NSInteger batchCounter = 0; batchCounter <= totalBatches; batchCounter++) {
    
    // Set final progress to 100%
    [self updateProgress:1];
    
    // Perform final save
    [self saveManagedObjectContext];
}

- (void)updateProgress:(CGFloat)progress {
    
    self.progress = progress;
    if (self.progressBlock) {
        self.progressBlock(progress);
    }
}

@end
