//
//  DataBuffer.h
//  FocusTracker
//
//  Created by Ted Li on 4/8/17.
//  Copyright © 2017 Ted Li. All rights reserved.
//

#import <Foundation/Foundation.h>
#include "armadillo"

@interface DataBuffer : NSObject

- (id)initWithMaxLength:(int)length;
- (BOOL)hasData;
- (void)pushData:(double)r g:(double)g b:(double)b;
- (arma::mat)getData;

@end
