//
//  PulseDetector.h
//  FocusTracker
//
//  Created by Kai Kang on 4/8/17.
//  Copyright © 2017 Ted Li. All rights reserved.
//

#import <Foundation/Foundation.h>

class DataBuffer;

@interface PulseDetector : NSObject

+ (int)getPulse:(DataBuffer *) db;

@end
