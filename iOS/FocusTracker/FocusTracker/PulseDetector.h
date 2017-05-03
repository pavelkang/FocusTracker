//
//  PulseDetector.h
//  FocusTracker
//
//  Created by Kai Kang on 4/8/17.
//  Copyright © 2017 Ted Li. All rights reserved.
//

#import <Foundation/Foundation.h>
#include "armadillo"

class DataBuffer;

@interface PulseDetector : NSObject

+ (double)getPulse:(DataBuffer *)db hamming_window:(arma::vec &)hamming_window prevPulse:(double)prevPulse;

@end
