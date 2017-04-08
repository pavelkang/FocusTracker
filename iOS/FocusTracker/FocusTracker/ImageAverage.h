//
//  ImageAverage.h
//  FocusTracker
//
//  Created by Ted Li on 4/8/17.
//  Copyright © 2017 Ted Li. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>


@interface ImageAverage : NSObject

+ (void)averageOfImage:(UIImage *)image r:(double *)rp g:(double *)gp b:(double *)bp;

@end
