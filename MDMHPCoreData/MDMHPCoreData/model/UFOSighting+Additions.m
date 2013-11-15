//
//  UFOSighting+Import.m
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

#import "UFOSighting+Additions.h"
#import "NSDictionary+MDMAdditions.h"

// JSON/Dictionary keys
NSString *const UFO_KEY_COREDATA_GUID = @"guid";
NSString *const UFO_KEY_COREDATA_SIGHTED = @"sighted";
NSString *const UFO_KEY_COREDATA_REPORTED = @"reported";
NSString *const UFO_KEY_COREDATA_LOCATION = @"location";
NSString *const UFO_KEY_COREDATA_SHAPE = @"shape";
NSString *const UFO_KEY_COREDATA_DURATION = @"duration";
NSString *const UFO_KEY_COREDATA_DESC = @"desc";
NSString *const UFO_KEY_JSON_GUID = @"guid";
NSString *const UFO_KEY_JSON_SIGHTED = @"sighted_at";
NSString *const UFO_KEY_JSON_REPORTED = @"reported_at";
NSString *const UFO_KEY_JSON_LOCATION = @"location";
NSString *const UFO_KEY_JSON_SHAPE = @"shape";
NSString *const UFO_KEY_JSON_DURATION = @"duration";
NSString *const UFO_KEY_JSON_DESC = @"description";

@implementation UFOSighting (Additions)

+ (instancetype)importSighting:(NSDictionary *)data intoContext:(NSManagedObjectContext *)context {
 
    NSString *guid = [data objectForKeyOrNil:UFO_KEY_JSON_GUID];
    
    UFOSighting *sighting = [self findOrCreateWithIdentifier:guid inContext:context];
    sighting.guid = guid;
    sighting.sighted = [self dateFromString:[data objectForKeyOrNil:UFO_KEY_JSON_SIGHTED]];
    sighting.reported = [self dateFromString:[data objectForKeyOrNil:UFO_KEY_JSON_REPORTED]];
    sighting.location = [data objectForKeyOrNil:UFO_KEY_JSON_LOCATION];
    sighting.shape = [data objectForKeyOrNil:UFO_KEY_JSON_SHAPE];
    sighting.duration = [data objectForKeyOrNil:UFO_KEY_JSON_DURATION];
    sighting.desc = [data objectForKeyOrNil:UFO_KEY_JSON_DESC];
    
    return sighting;
}

+ (instancetype)findOrCreateWithIdentifier:(id)identifier inContext:(NSManagedObjectContext *)context {
    
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:[self entityName]];
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"%K = %@", UFO_KEY_COREDATA_GUID, identifier];
    fetchRequest.fetchLimit = 1;
    
    id object = [[context executeFetchRequest:fetchRequest error:NULL] lastObject];
    if (object == nil) {
        object = [UFOSighting insertNewObjectIntoContext:context];
    }
    return object;
}

+ (NSString *)entityName {
    
    return NSStringFromClass(self);
}

+ (instancetype)insertNewObjectIntoContext:(NSManagedObjectContext *)context {
    
    return [NSEntityDescription insertNewObjectForEntityForName:[self entityName]
                                         inManagedObjectContext:context];
}

+ (NSDate *)dateFromString:(NSString *)string {
    
    static NSDateFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"yyyyMMdd"];
    });
    return [formatter dateFromString:string];
}

+ (NSString *)stringFromDate:(NSDate *)date {

    static NSDateFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"MM/dd/yyyy"];
    });
    return [formatter stringFromDate:date];
}

+ (UIImage *)imageForShape:(NSString *)shape {
    
    UIImage *shapeImage = nil;
    
    if ([shape isEqualToString:@"cigar"]) {
        shapeImage = [UIImage imageNamed:@"shape01"];
    } else if ([shape isEqualToString:@"circle"]) {
        shapeImage = [UIImage imageNamed:@"shape02"];
    } else if ([shape isEqualToString:@"cross"]) {
        shapeImage = [UIImage imageNamed:@"shape03"];
    } else if ([shape isEqualToString:@"diamond"]) {
        shapeImage = [UIImage imageNamed:@"shape04"];
    } else if ([shape isEqualToString:@"disk"]) {
        shapeImage = [UIImage imageNamed:@"shape05"];
    } else if ([shape isEqualToString:@"light"]) {
        shapeImage = [UIImage imageNamed:@"shape06"];
    } else if ([shape isEqualToString:@"rectangle"]){
        shapeImage = [UIImage imageNamed:@"shape07"];
    } else if ([shape isEqualToString:@"sphere"]) {
        shapeImage = [UIImage imageNamed:@"shape08"];
    } else if ([shape isEqualToString:@"triangle"]) {
        shapeImage = [UIImage imageNamed:@"shape09"];
    } else if ([shape isEqualToString:@"other"]) {
        shapeImage = [UIImage imageNamed:@"shape01"];
    } else if ([shape isEqualToString:@"unknown"]) {
        shapeImage = [UIImage imageNamed:@"shape02"];
    } else if ([shape isEqualToString:@"fireball"]) {
        shapeImage = [UIImage imageNamed:@"shape03"];
    } else if ([shape isEqualToString:@"oval"]) {
        shapeImage = [UIImage imageNamed:@"shape04"];
    } else if ([shape isEqualToString:@""]) {
        shapeImage = [UIImage imageNamed:@"shape05"];
    } else if ([shape isEqualToString:@"formation"]) {
        shapeImage = [UIImage imageNamed:@"shape06"];
    } else if ([shape isEqualToString:@"cigar"]) {
        shapeImage = [UIImage imageNamed:@"shape07"];
    } else if ([shape isEqualToString:@"changing"]) {
        shapeImage = [UIImage imageNamed:@"shape08"];
    } else {
        shapeImage = [UIImage imageNamed:@"shape09"];
    }
    
    return shapeImage;
}

@end
