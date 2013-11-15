//
//  NSDictionary+MDMAdditions.m
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

#import <Foundation/Foundation.h>

/**
 * Helper categories on NSDictionary.
 *
 */
@interface NSDictionary (MDMAdditions)

/**
 * Clean-up NSNulls from JSON dictionaries.
 * @param key The key to look for
 * @return The object from the dictionary or nil if that object is an NSNull.
 */
- (id)objectForKeyOrNil:(id)key;

/**
 * Clean-up NSNulls from JSON dictionaries.
 * @param keyPath The key path to look for
 * @return The object from the dictionary or nil if that object is an NSNull.
 */
- (id)objectForKeyPathOrNil:(id)keyPath;

@end
