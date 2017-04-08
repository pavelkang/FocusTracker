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
    CGRect bds = CGRectMake(transformedBounds.origin.x + transformedBounds.size.width * 0.2, transformedBounds.origin.y + transformedBounds.size.height * 0.2, transformedBounds.size.width * 0.6, transformedBounds.size.height * 0.6);
    CGImageRef imageRef = CGImageCreateWithImageInRect([self CGImage], bds);
    UIImage *result = [UIImage imageWithCGImage:imageRef scale:self.scale orientation:self.imageOrientation];
    CGImageRelease(imageRef);
    return result;
}

@end
