//
//  UIImage+Crop.m
//  FocusTracker
//
//  Created by Ted Li on 4/8/17.
//  Copyright © 2017 Ted Li. All rights reserved.
//

#import "UIImage+Crop.h"

@implementation UIImage (Crop)

- (UIImage *)crop:(CGRect)rect {
    CGRect transformedBounds = CGRectMake(rect.origin.y, rect.origin.x, rect.size.height, rect.size.width);
    CGImageRef imageRef = CGImageCreateWithImageInRect([self CGImage], transformedBounds);
    UIImage *result = [UIImage imageWithCGImage:imageRef scale:self.scale orientation:self.imageOrientation];
    CGImageRelease(imageRef);
    return result;
}

@end
