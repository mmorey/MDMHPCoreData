//
//  MDMAppDelegate.m
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

#import "MDMAppDelegate.h"

#import "MDMPersistenceStack.h"
#import "UFOSighting+Additions.h"
#import "NSDictionary+MDMAdditions.h"
#import "MDMUFOListViewController.h"

@implementation MDMAppDelegate

static NSString * const UFO_SQLITE_FILE = @"UFO.sqlite";
static NSString * const UFO_MODEL_FILENAME = @"UFO";
static NSString * const UFO_MODEL_EXTENSION = @"momd";

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

    // Create Core Data stack
    [self initalizePersistenceStack];
    
    // Set up root view controller:
    //
    // 1) By passing managed object context
    UINavigationController *navigationController = (UINavigationController *)self.window.rootViewController;
    MDMUFOListViewController *viewController = navigationController.viewControllers[0];
    viewController.managedObjectContext = self.stack.managedObjectContext;
    //
    // 2) Or by listening for MDM_NOTIFICATION_COREDATA_STACK_INITIALIZED
    //    in the root view controller

    return YES;
}

- (void)initalizePersistenceStack {
    
    NSURL* documentsDirectory = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory
                                                                       inDomain:NSUserDomainMask
                                                              appropriateForURL:nil
                                                                         create:YES
                                                                          error:NULL];
    NSURL *storeURL = [documentsDirectory URLByAppendingPathComponent:UFO_SQLITE_FILE];
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:UFO_MODEL_FILENAME withExtension:UFO_MODEL_EXTENSION];
 
    // During development it is often useful to replace the store with a prepopulated one
    //    NSURL *replacementStoreURL = [[NSBundle mainBundle] URLForResource:@"UFO_POPULATED" withExtension:@"sqlite"];
    //    [self resetPersistentStoreAtURL:storeURL withStoreAtURL:replacementStoreURL];
    
    self.stack = [[MDMPersistenceStack alloc] initWithStoreURL:storeURL modelURL:modelURL];
}

- (void)resetPersistentStoreAtURL:(NSURL *)storeURL withStoreAtURL:(NSURL *)replacementStoreURL {
 
    NSLog(@"WARNING: Deleting store");
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error;
    
    if([fileManager fileExistsAtPath:storeURL.path]) {

        // Need to delete journaling and write-ahead logging files in additon to .sqlite file
        NSURL *storeDirectoryURL = [storeURL URLByDeletingLastPathComponent];
        NSDirectoryEnumerator *directoryEnumerator = [fileManager enumeratorAtURL:storeDirectoryURL
                                              includingPropertiesForKeys:nil
                                                                 options:0
                                                            errorHandler:NULL];
        
        NSString *storeName = [storeURL.lastPathComponent stringByDeletingPathExtension];
        for (NSURL *URLOfFileInDirecotry in directoryEnumerator) {
           
            NSString *path = [URLOfFileInDirecotry path];
            if ([[path lastPathComponent] hasPrefix:storeName] == NO) {
                continue;
            }
            
            if ([fileManager removeItemAtURL:URLOfFileInDirecotry error:&error] == NO) {
                NSLog(@"ERROR: Could not remove %@\n%@", URLOfFileInDirecotry, [error localizedDescription]);
            } else {
                NSLog(@"SUCCESS: Removed %@", URLOfFileInDirecotry);
            }
        }
    }
    
    error = nil;
    if ([[NSFileManager defaultManager] copyItemAtURL:replacementStoreURL toURL:storeURL error:&error]) {
        NSLog(@"SUCCESS: Copied seed data to %@", [storeURL path]);
    } else {
        NSLog(@"ERROR: Coping seed data to %@\n%@\n%@", [storeURL path], [error localizedDescription], [error userInfo]);
    }
}

@end
