//
//  ImageAverage.m
//  FocusTracker
//
//  Created by Ted Li on 4/8/17.
//  Copyright © 2017 Ted Li. All rights reserved.
//

#import "ImageAverage.h"

@implementation ImageAverage

+ (void)averageOfImage:(UIImage *)image r:(double *)rp g:(double *)gp b:(double *)bp
{
    *rp = 0.0f;
    *gp = 0.0f;
    *bp = 0.0f;
    CFDataRef pixelData = CGDataProviderCopyData(CGImageGetDataProvider(image.CGImage));
    const UInt8 *data = CFDataGetBytePtr(pixelData);
    for (int x = 0; x < image.size.width; ++x) {
        for (int y = 0; y < image.size.height; ++y) {
            int pixelInfo = ((image.size.width * y) + x) * 4;
            *rp += data[pixelInfo];
            *gp += data[pixelInfo + 1];
            *bp += data[pixelInfo + 2];
        }
    }
    *rp /= image.size.height * image.size.width;
    *gp /= image.size.height * image.size.width;
    *bp /= image.size.height * image.size.width;
    CFRelease(pixelData);
}

@end
