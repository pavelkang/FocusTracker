//
//  DataBuffer.h
//  FocusTracker
//
//  Created by Ted Li on 4/8/17.
//  Copyright © 2017 Ted Li. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "armadillo"

@interface DataBuffer : NSObject

- (void)hasData;
- (arma::fmat)getData;

@end
