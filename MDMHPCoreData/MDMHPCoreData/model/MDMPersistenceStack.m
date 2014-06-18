//
//  MDMPersistenceStack.m
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

#import "MDMPersistenceStack.h"
#import <CoreData/CoreData.h>

NSString *const MDM_NOTIFICATION_COREDATA_STACK_INITIALIZED = @"MDM_NOTIFICATION_COREDATA_STACK_INITIALIZED";

@interface MDMPersistenceStack ()

@property (nonatomic, strong, readwrite) NSManagedObjectContext* managedObjectContext;
@property (nonatomic, strong) NSURL *modelURL;
@property (nonatomic, strong) NSURL *storeURL;

@end

@implementation MDMPersistenceStack

- (id)initWithStoreURL:(NSURL*)storeURL modelURL:(NSURL*)modelURL {
    
    self = [super init];
    if (self) {
        _disableMergeNotifications = NO;
        _storeURL = storeURL;
        _modelURL = modelURL;
        
        // On iOS 6 Core Data stack can be set up synchronously or asynchronously
        //     Adding a NSPersistentStore instance to a NSPersistentStoreCoordinator
        //     takes an unknown amount of time due to migrations or iCloud could be
        //     updating and linking. With iOS 7 iCloud linking returns immediatly.
        
        // 1) Setup stack asynchronically
        // [self setupPersistenceStackAsync];

        // 2) Setup stack synchronically
        [self setupPersistenceStack];
    }
    return self;
}

- (void)dealloc {
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)setupPersistenceStack {
    
    // Get model
    NSManagedObjectModel *model = [[NSManagedObjectModel alloc] initWithContentsOfURL:self.modelURL];
    if (model == nil) {
        NSLog(@"ERROR: Cannot generate persistent store as no model exist");
        NSAssert(NO, @"ASSERT: NSManagedObjectModel is nil");
    }
    
    // Create persistent store coordinator
    NSPersistentStoreCoordinator *persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model];
    if (persistentStoreCoordinator == nil) {
        NSLog(@"ERROR: Cannot add persistent store as no persistent store coordinator exist");
        NSAssert(NO, @"ASSERT: NSPersistentStoreCoordinator is nil");
    }
    
    // Add persistent store to store coordinator
    NSDictionary *persistentStoreOptions = @{ // Light migration
                                             NSInferMappingModelAutomaticallyOption:@YES,
                                             NSMigratePersistentStoresAutomaticallyOption:@YES
                                             };
    NSError *error;
    NSPersistentStore *persistentStore = [persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType
                                                                                  configuration:nil
                                                                                            URL:self.storeURL
                                                                                        options:persistentStoreOptions
                                                                                          error:&error];
    if (persistentStore == nil) {
        
        // Model has probably changed, lets delete the old one and try again
        NSError *deleteError = nil;
        if ([[NSFileManager defaultManager] removeItemAtURL:self.storeURL error:&deleteError]) {
            error = nil;
            persistentStore = [persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType
                                                                       configuration:nil
                                                                                 URL:self.storeURL
                                                                             options:persistentStoreOptions
                                                                               error:&error];
        }
        
        // Something bad is happening, last option is to abort
        if (persistentStore == nil) {
            NSLog(@"ERROR: Cannot create managed object context because a persistent store does not exist\n%@", [error localizedDescription]);
            NSLog(@"DELETE ERROR: %@", [deleteError localizedDescription]);
            NSAssert(NO, @"ASSERT: NSPersistentStore is nil");
            abort();
        }
        
    }
    
    // Create managed object context
    self.managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    [self.managedObjectContext setPersistentStoreCoordinator:persistentStoreCoordinator];
    if (self.managedObjectContext == nil) {
        
        // App is useless if a managed object context cannot be created
        NSLog(@"ERROR: Cannot create managed object context");
        NSAssert(NO, @"ASSERT: NSManagedObjectContext is nil");
        abort();
    }
    
    // Setup save notification for private managed object contexts
    [self setupSaveNotification];
    
    // Context is fully initialized, notify view controllers
    [self persistenceStackInitialized];
}

// iOS 6 only, on iOS 7 addPersistentStoreWithType returns immediately
- (void)setupPersistenceStackAsync {
 
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(queue, ^{
 
        // Get model
        NSManagedObjectModel *model = [[NSManagedObjectModel alloc] initWithContentsOfURL:self.modelURL];
        if (model == nil) {
            NSLog(@"ERROR: Cannot generate persistent store as no model exist");
            NSAssert(NO, @"ASSERT: NSManagedObjectModel is nil");
        }

        // Create persistent store coordinator
        NSPersistentStoreCoordinator *persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model];
        if (persistentStoreCoordinator == nil) {
            NSLog(@"ERROR: Cannot add persistent store as no persistent store coordinator exist");
            NSAssert(NO, @"ASSERT: NSPersistentStoreCoordinator is nil");
        }
        
        // Add persistent store to store coordinator
        NSDictionary *persistentStoreOptions = @{ // Light migration
                                  NSInferMappingModelAutomaticallyOption:@YES,
                                  NSMigratePersistentStoresAutomaticallyOption:@YES
                                  };
        NSError *error;
        NSPersistentStore *persistentStore = [persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType
                                                                                      configuration:nil
                                                                                                URL:self.storeURL
                                                                                            options:persistentStoreOptions
                                                                                              error:&error];
        if (persistentStore == nil) {
            
            // Model has probably changed, lets delete the old one and try again
            NSError *deleteError = nil;
            if ([[NSFileManager defaultManager] removeItemAtURL:self.storeURL error:&deleteError]) {
                error = nil;
                persistentStore = [persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType
                                                                           configuration:nil
                                                                                     URL:self.storeURL
                                                                                 options:persistentStoreOptions
                                                                                   error:&error];
            }
            
            // Something bad is happening, last option is to abort
            if (persistentStore == nil) {
                NSLog(@"ERROR: Cannot create managed object context because a persistent store does not exist\n%@", [error localizedDescription]);
                NSLog(@"DELETE ERROR: %@", [deleteError localizedDescription]);
                NSAssert(NO, @"ASSERT: NSPersistentStore is nil");
                abort();
            }
            
        }
       
        // Create managed object context
        self.managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
        [self.managedObjectContext setPersistentStoreCoordinator:persistentStoreCoordinator];

        if (self.managedObjectContext == nil) {
            
            // App is useless if a managed object context cannot be created
            NSLog(@"ERROR: Cannot create managed object context");
            NSAssert(NO, @"ASSERT: NSManagedObjectContext is nil");
        }
        
        // Setup save notification for private managed object contexts
        [self setupSaveNotification];
        
        // Context is fully initialized, notify view controllers
        dispatch_sync(dispatch_get_main_queue(), ^{
            [self persistenceStackInitialized];
        });
    });
}

- (void)persistenceStackInitialized {
    
    [[NSNotificationCenter defaultCenter] postNotificationName:MDM_NOTIFICATION_COREDATA_STACK_INITIALIZED
                                                        object:self];
}

- (void)setupSaveNotification {
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(managedObjectContextDidSaveNotification:)
                                                 name:NSManagedObjectContextDidSaveNotification
                                               object:nil];
}

#pragma mark - Private NSManagedObjectContext

- (void)managedObjectContextDidSaveNotification:(NSNotification *)notification {

    if (_disableMergeNotifications == NO) {
        NSManagedObjectContext *managedObjectContext = self.managedObjectContext;
        NSManagedObjectContext *savedManagedObjectContext = notification.object;
        if (savedManagedObjectContext != managedObjectContext) {
            [managedObjectContext performBlock:^(){
                [managedObjectContext mergeChangesFromContextDidSaveNotification:notification];
            }];
        }
    }
}

- (NSManagedObjectContext *)newPrivateManagedObjectContext {
    
    NSManagedObjectContext *privateManagedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    [privateManagedObjectContext setPersistentStoreCoordinator:self.managedObjectContext.persistentStoreCoordinator];
    return privateManagedObjectContext;
}

- (NSManagedObjectContext *)newPrivateManagedObjectContextWithNewPersistentStoreCoordinator {
    
    // Get model
    NSManagedObjectModel *model = [[NSManagedObjectModel alloc] initWithContentsOfURL:self.modelURL];
    if (model == nil) {
        NSLog(@"ERROR: Cannot generate persistent store as no model exist");
        NSAssert(NO, @"ASSERT: NSManagedObjectModel is nil");
    }
    
    // Create persistent store coordinator
    NSPersistentStoreCoordinator *persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model];
    if (persistentStoreCoordinator == nil) {
        NSLog(@"ERROR: Cannot add persistent store as no persistent store coordinator exist");
        NSAssert(NO, @"ASSERT: NSPersistentStoreCoordinator is nil");
    }
    
    // Add persistent store to store coordinator
    NSDictionary *persistentStoreOptions = @{ // Light migration
                                             NSInferMappingModelAutomaticallyOption:@YES,
                                             NSMigratePersistentStoresAutomaticallyOption:@YES
                                             };
    NSError *error;
    NSPersistentStore *persistentStore = [persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType
                                                                                  configuration:nil
                                                                                            URL:self.storeURL
                                                                                        options:persistentStoreOptions
                                                                                          error:&error];
    if (persistentStore == nil) {
        // Something bad is happening, last option is to abort
        NSLog(@"ERROR: Cannot create managed object context because a persistent store does not exist\n%@", [error localizedDescription]);
        NSAssert(NO, @"ASSERT: NSPersistentStore is nil");
        abort();
    }
    
    // Create private managed object context
    NSManagedObjectContext *privateContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    [privateContext setPersistentStoreCoordinator:persistentStoreCoordinator];
    if (privateContext == nil) {
        NSLog(@"ERROR: Cannot create managed object context");
        NSAssert(NO, @"ASSERT: NSManagedObjectContext is nil");
        abort();
    }
    
    return privateContext;
}

@end
