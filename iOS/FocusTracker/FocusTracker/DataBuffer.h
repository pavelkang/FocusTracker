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

- (BOOL)hasData;
- (arma::mat)getData;

@end
