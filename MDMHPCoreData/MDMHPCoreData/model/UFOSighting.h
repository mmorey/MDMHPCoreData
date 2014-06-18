//
//  UFOSighting.h
//  MDMHPCoreData
//
//  Created by xzolian on 6/9/14.
//  Copyright (c) 2014 Matthew Morey. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface UFOSighting : NSManagedObject

@property (nonatomic, retain) NSString * desc;
@property (nonatomic, retain) NSString * duration;
@property (nonatomic, retain) NSString * guid;
@property (nonatomic, retain) NSString * location;
@property (nonatomic, retain) NSDate * reported;
@property (nonatomic, retain) NSString * shape;
@property (nonatomic, retain) NSDate * sighted;
@property (nonatomic, retain) NSNumber * read;

@end
