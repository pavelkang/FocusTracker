//
//  ViewController.m
//  FocusTracker
//
//  Created by Ted Li on 4/8/17.
//  Copyright © 2017 Ted Li. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import <GoogleMobileVision/GoogleMobileVision.h>

#import "ViewController.h"
#import "DrawingUtility.h"
#import "UIImage+Crop.h"
#import "ImageAverage.h"
#import "PulseDetector.h"

#ifdef __cplusplus
#include "DataBuffer.hpp"
#include <opencv2/opencv.hpp>
#include <iostream>
#include <ctime>
#include <opencv2/imgproc/imgproc.hpp>
#endif

#define FFT_SIZE 1024
#define HISTORY_LEN 10
#define WIN_WIDTH 300
#define WIN_HEIGHT 200
#define PADDING 10
#define INT_LEN 29

@interface ViewController ()<AVCaptureVideoDataOutputSampleBufferDelegate> {
    DataBuffer *_buffer;
    int count;
    int64 curr_time_;
    std::clock_t prev;
    double _pulse;
    arma::vec _hamming_window;
    std::vector<double> _pulses;
    int _curr;
}

@property (nonatomic, strong) UIView *placeHolder;
@property (nonatomic, strong) UIView *overlayView;

// Video objects.
@property(nonatomic, strong) AVCaptureSession *session;
@property(nonatomic, strong) AVCaptureVideoDataOutput *videoDataOutput;
@property(nonatomic, strong) dispatch_queue_t videoDataOutputQueue;
@property(nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;
@property(nonatomic, assign) UIDeviceOrientation lastKnownDeviceOrientation;

// Detector.
@property(nonatomic, strong) GMVDetector *faceDetector;

@end

@implementation ViewController

const cv::Scalar GREEN = cv::Scalar(0,255,0,1);
const cv::Scalar DARKGREEN = cv::Scalar(145, 191, 156, 1);

cv::Point2f pulse2Point(double index, double pulse) {
    double x = PADDING + index * INT_LEN;
    double y = WIN_HEIGHT - 20;
    if (pulse >= 60 && pulse <= 100) {
        y = 180 + (60.0 - pulse) * 180 / 40;
    }
    return cv::Point2f(x, y);
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _buffer = new DataBuffer(1024);
    count = 0;

    self.placeHolder = [[UIView alloc] initWithFrame:self.view.frame];
    self.overlayView = [[UIView alloc] initWithFrame:self.view.frame];
    
    [self.view addSubview:self.placeHolder];
    [self.view addSubview:self.overlayView];

    self.videoDataOutputQueue = dispatch_queue_create("VideoDataOutputQueue", DISPATCH_QUEUE_SERIAL);
    self.session = [[AVCaptureSession alloc] init];
    self.session.sessionPreset = AVCaptureSessionPresetMedium;
    [self updateCameraSelection];

    // Setup video processing pipeline.
    [self setupVideoProcessing];

    // Setup camera preview.
    [self setupCameraPreview];

    // Initialize the face detector.
    NSDictionary *options = @{
                              GMVDetectorFaceLandmarkType : @(GMVDetectorFaceLandmarkAll),
                              GMVDetectorFaceMinSize : @(0.3),
                              GMVDetectorFaceTrackingEnabled : @(YES)
                              };
    self.faceDetector = [GMVDetector detectorOfType:GMVDetectorTypeFace options:options];
    
    _hamming_window.zeros(FFT_SIZE);
    for (int i = 0; i < FFT_SIZE; i++) {
        _hamming_window(i) = 0.54 - 0.46 * cos(2*M_PI*i / (FFT_SIZE - i));
    }
    
    _pulses.reserve(HISTORY_LEN);
    _curr = 0;
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    self.previewLayer.frame = self.view.layer.bounds;
    self.previewLayer.position = CGPointMake(CGRectGetMidX(self.previewLayer.frame),
                                             CGRectGetMidY(self.previewLayer.frame));
}

- (void)viewDidUnload {
    [self cleanupCaptureSession];
    [super viewDidUnload];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self.session startRunning];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self.session stopRunning];
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
                                         duration:(NSTimeInterval)duration {
    // Camera rotation needs to be manually set when rotation changes.
    if (self.previewLayer) {
        if (toInterfaceOrientation == UIInterfaceOrientationPortrait) {
            self.previewLayer.connection.videoOrientation = AVCaptureVideoOrientationPortrait;
        } else if (toInterfaceOrientation == UIInterfaceOrientationPortraitUpsideDown) {
            self.previewLayer.connection.videoOrientation = AVCaptureVideoOrientationPortraitUpsideDown;
        } else if (toInterfaceOrientation == UIInterfaceOrientationLandscapeLeft) {
            self.previewLayer.connection.videoOrientation = AVCaptureVideoOrientationLandscapeLeft;
        } else if (toInterfaceOrientation == UIInterfaceOrientationLandscapeRight) {
            self.previewLayer.connection.videoOrientation = AVCaptureVideoOrientationLandscapeRight;
        }
    }
}

#pragma mark - AVCaptureVideoPreviewLayer Helper method

- (CGRect)scaledRect:(CGRect)rect
              xScale:(CGFloat)xscale
              yScale:(CGFloat)yscale
              offset:(CGPoint)offset {
    CGRect resultRect = CGRectMake(rect.origin.x * xscale,
                                   rect.origin.y * yscale,
                                   rect.size.width * xscale,
                                   rect.size.height * yscale);
    resultRect = CGRectOffset(resultRect, offset.x, offset.y);
    return resultRect;
}

- (CGPoint)scaledPoint:(CGPoint)point
                xScale:(CGFloat)xscale
                yScale:(CGFloat)yscale
                offset:(CGPoint)offset {
    CGPoint resultPoint = CGPointMake(point.x * xscale + offset.x, point.y * yscale + offset.y);
    return resultPoint;
}

- (void)setLastKnownDeviceOrientation:(UIDeviceOrientation)orientation {
    if (orientation != UIDeviceOrientationUnknown &&
        orientation != UIDeviceOrientationFaceUp &&
        orientation != UIDeviceOrientationFaceDown) {
        _lastKnownDeviceOrientation = orientation;
    }
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate

- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection {

    UIImage *image = [GMVUtility sampleBufferTo32RGBA:sampleBuffer];

    AVCaptureDevicePosition devicePosition = AVCaptureDevicePositionFront;

    // Establish the image orientation.
    UIDeviceOrientation deviceOrientation = [[UIDevice currentDevice] orientation];
    GMVImageOrientation orientation = [GMVUtility
                                       imageOrientationFromOrientation:deviceOrientation
                                       withCaptureDevicePosition:devicePosition
                                       defaultDeviceOrientation:self.lastKnownDeviceOrientation];
    NSDictionary *options = @{
                              GMVDetectorImageOrientation : @(orientation)
                              };
    
    if (image.imageOrientation != UIImageOrientationUp) {
        UIGraphicsBeginImageContextWithOptions(image.size, NO, image.scale);
        [image drawInRect:(CGRect){0, 0, image.size}];
        UIImage *normalizedImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        image = normalizedImage;
    }
    
    // Detect features using GMVDetector.
    NSArray<GMVFaceFeature *> *faces = [self.faceDetector featuresInImage:image options:options];

    // The video frames captured by the camera are a different size than the video preview.
    // Calculates the scale factors and offset to properly display the features.
    CMFormatDescriptionRef fdesc = CMSampleBufferGetFormatDescription(sampleBuffer);
    CGRect clap = CMVideoFormatDescriptionGetCleanAperture(fdesc, false);
    CGSize parentFrameSize = self.previewLayer.frame.size;

    // Assume AVLayerVideoGravityResizeAspect
    CGFloat cameraRatio = clap.size.height / clap.size.width;
    CGFloat viewRatio = parentFrameSize.width / parentFrameSize.height;
    CGFloat xScale = 1;
    CGFloat yScale = 1;
    CGRect videoBox = CGRectZero;
    if (viewRatio > cameraRatio) {
        videoBox.size.width = parentFrameSize.height * clap.size.width / clap.size.height;
        videoBox.size.height = parentFrameSize.height;
        videoBox.origin.x = (parentFrameSize.width - videoBox.size.width) / 2;
        videoBox.origin.y = (videoBox.size.height - parentFrameSize.height) / 2;

        xScale = videoBox.size.width / clap.size.width;
        yScale = videoBox.size.height / clap.size.height;
    } else {
        videoBox.size.width = parentFrameSize.width;
        videoBox.size.height = clap.size.width * (parentFrameSize.width / clap.size.height);
        videoBox.origin.x = (videoBox.size.width - parentFrameSize.width) / 2;
        videoBox.origin.y = (parentFrameSize.height - videoBox.size.height) / 2;

        xScale = videoBox.size.width / clap.size.height;
        yScale = videoBox.size.height / clap.size.width;
    }

    dispatch_sync(dispatch_get_main_queue(), ^{
        // Remove previously added feature views.
        for (UIView *featureView in self.overlayView.subviews) {
            [featureView removeFromSuperview];
        }

        // Display detected features in overlay.
        for (GMVFaceFeature *face in faces) {
            CGRect faceRect = [self scaledRect:face.bounds
                                        xScale:xScale
                                        yScale:yScale
                                        offset:videoBox.origin];
            [DrawingUtility addRectangle:faceRect
                                  toView:self.overlayView
                               withColor:[UIColor redColor]];

            // Tracking Id.
            if (face.hasTrackingID) {
                CGPoint point = [self scaledPoint:face.bounds.origin
                                           xScale:xScale
                                           yScale:yScale
                                           offset:videoBox.origin];
                UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(point.x, point.y, 100, 20)];
                label.text = [NSString stringWithFormat:@"id: %lu", (unsigned long)face.trackingID];
                [self.overlayView addSubview:label];
            }

            // Push to data buffer
            UIImage *croppedImage = [image crop:face.bounds];
            double r, g, b;
            if (croppedImage == nil) {
                continue;
            }
            [ImageAverage averageOfImage:croppedImage r:&r g:&g b:&b];
            _buffer->pushData(r, g, b);
         
            count += 1;
            if (count % 50 == 49) {
                double prevPulse = _pulses[(_curr - 1) % HISTORY_LEN];
                _pulse = [PulseDetector getPulse:_buffer hamming_window:_hamming_window prevPulse:prevPulse];
                std::cout << _pulse << std::endl;
                _pulses[_curr % HISTORY_LEN] = _pulse;
                _curr = (_curr + 1) % HISTORY_LEN;
            }
            
            if (count % 100 == 99) {
                NSMutableArray<UIImage *> *eyeRegions = [NSMutableArray array];
            
                float eyeWidth = faceRect.size.width * 0.21;
                float eyeHeight = faceRect.size.height * 0.15;
                
                UIImage *leftEye;
                UIImage *rightEye;
                
                if (face.hasLeftEyePosition) {
                    CGPoint leftEyePos = face.leftEyePosition;
                    CGRect leftEyeRect = CGRectMake(leftEyePos.x - eyeWidth / 2.0, leftEyePos.y - eyeHeight / 2.0, eyeWidth, eyeHeight);
                    leftEye = [image crop:leftEyeRect];
                }
            
                if (face.hasRightEyePosition) {
                    CGPoint rightEyePos = face.rightEyePosition;
                    CGRect rightEyeRect = CGRectMake(rightEyePos.x - eyeWidth / 2.0, rightEyePos.y - eyeHeight / 2.0, eyeWidth, eyeHeight);
                    rightEye = [image crop:rightEyeRect];
                }
                
                // UIImage to float *
                leftEye = [UIImage imageWithCGImage:leftEye.CGImage scale:leftEye.scale orientation:UIImageOrientationUp];
                rightEye = [UIImage imageWithCGImage:rightEye.CGImage scale:rightEye.scale orientation:UIImageOrientationUp];
                
                cv::Mat leftMat = [self cvMatFromUIImage:leftEye];
                cv::Mat rightMat = [self cvMatFromUIImage:rightEye];
                
                cv::Mat leftGreyMat, rightGreyMat;
                cv::cvtColor(leftMat, leftGreyMat, CV_BGR2GRAY);
                cv::cvtColor(rightMat, rightGreyMat, CV_BGR2GRAY);
                
                // Apply Neural Network here
                
                
            }
            
            NSString *pulseStr = [NSString stringWithFormat:@"%f", _pulse];
            CGRect resultRect = CGRectMake(500, 500, 50, 20);
            [DrawingUtility addTextLabel:pulseStr atRect:resultRect toView:self.overlayView withColor:UIColor.blueColor];
            
            // Draw the line graph
            
            cv::Mat mat = cv::Mat(WIN_HEIGHT,WIN_WIDTH, CV_8UC4, cv::Scalar(0,0,0,0));
            
            // Draw horizontal lines:
            
            for (int y = 10; y <= WIN_HEIGHT - 10; y+=10) {
                std::vector<cv::Point2f> line(2);
                line.push_back(cv::Point2f( 0 , y ));
                line.push_back(cv::Point2f( WIN_WIDTH, y));
                DrawLines(mat, line, DARKGREEN);
            }
            
            // Draw vertical lines:
            
            for (int x = 10; x <= WIN_WIDTH - 10; x+=10) {
                std::vector<cv::Point2f> line(2);
                line.push_back(cv::Point2f(x, 0));
                line.push_back(cv::Point2f(x, WIN_HEIGHT));
                DrawLines(mat, line, DARKGREEN);
            }
            
            // Draw the line graph

            std::vector<cv::Point2f> cv_pts(HISTORY_LEN);
            for (int i = 0; i < HISTORY_LEN; i++) {
                cv_pts[i] = pulse2Point(i, _pulses[(_curr+i) % HISTORY_LEN]);
            }
            DrawLines(mat, cv_pts, GREEN);
            DrawPts(mat, cv_pts, GREEN);
            
            UIImageView *imageView_ = [[UIImageView alloc] initWithFrame:CGRectMake(0.0, 0.0, WIN_WIDTH, WIN_HEIGHT)];
            [self.view addSubview:imageView_];
            imageView_.image = [self UIImageFromCVMat:mat];
        }
    });
}

#pragma mark - Camera setup

- (void)cleanupVideoProcessing {
    if (self.videoDataOutput) {
        [self.session removeOutput:self.videoDataOutput];
    }
    self.videoDataOutput = nil;
}

- (void)cleanupCaptureSession {
    [self.session stopRunning];
    [self cleanupVideoProcessing];
    self.session = nil;
    [self.previewLayer removeFromSuperlayer];
}

- (void)setupVideoProcessing {
    self.videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
    NSDictionary *rgbOutputSettings = @{
                                        (__bridge NSString*)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA)
                                        };
    [self.videoDataOutput setVideoSettings:rgbOutputSettings];

    if (![self.session canAddOutput:self.videoDataOutput]) {
        [self cleanupVideoProcessing];
        NSLog(@"Failed to setup video output");
        return;
    }
    [self.videoDataOutput setAlwaysDiscardsLateVideoFrames:YES];
    [self.videoDataOutput setSampleBufferDelegate:self queue:self.videoDataOutputQueue];
    [self.session addOutput:self.videoDataOutput];
}

- (void)setupCameraPreview {
    self.previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.session];
    [self.previewLayer setBackgroundColor:[[UIColor whiteColor] CGColor]];
    [self.previewLayer setVideoGravity:AVLayerVideoGravityResizeAspect];
    CALayer *rootLayer = [self.placeHolder layer];
    [rootLayer setMasksToBounds:YES];
    [self.previewLayer setFrame:[rootLayer bounds]];
    [rootLayer addSublayer:self.previewLayer];
}

- (void)updateCameraSelection {
    [self.session beginConfiguration];

    // Remove old inputs
    NSArray *oldInputs = [self.session inputs];
    for (AVCaptureInput *oldInput in oldInputs) {
        [self.session removeInput:oldInput];
    }

    AVCaptureDevicePosition desiredPosition = AVCaptureDevicePositionFront;
    AVCaptureDeviceInput *input = [self cameraForPosition:desiredPosition];
    if (!input) {
        // Failed, restore old inputs
        for (AVCaptureInput *oldInput in oldInputs) {
            [self.session addInput:oldInput];
        }
    } else {
        // Succeeded, set input and update connection states
        [self.session addInput:input];
    }
    [self.session commitConfiguration];
}

- (AVCaptureDeviceInput *)cameraForPosition:(AVCaptureDevicePosition)desiredPosition {
    for (AVCaptureDevice *device in [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo]) {
        if ([device position] == desiredPosition) {
            NSError *error = nil;
            AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device
                                                                                error:&error];
            if ([self.session canAddInput:input]) {
                return input;
            }
        }
    }
    return nil;
}

void DrawPts(cv::Mat &display_im, std::vector<cv::Point2f> cv_pts, const cv::Scalar &pts_clr)
{
    for(int i=0; i<cv_pts.size(); i++) {
        cv::circle(display_im, cv_pts[i], 2, pts_clr, 2); // Draw the points
    }
}

void DrawLines(cv::Mat &display_im, std::vector<cv::Point2f> &cv_pts, const cv::Scalar &pts_clr)
{
    for(int i=0; i<cv_pts.size()-1; i++) {
        cv::line(display_im, cv_pts[i], cv_pts[i+1], pts_clr, 1); // Draw the line
    }
}

-(UIImage *)UIImageFromCVMat:(cv::Mat)cvMat
{
    NSData *data = [NSData dataWithBytes:cvMat.data length:cvMat.elemSize()*cvMat.total()];
    CGColorSpaceRef colorSpace;
    
    if (cvMat.elemSize() == 1) {
        colorSpace = CGColorSpaceCreateDeviceGray();
    } else {
        colorSpace = CGColorSpaceCreateDeviceRGB();
    }
    
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    
    // Creating CGImage from cv::Mat
    CGImageRef imageRef = CGImageCreate(cvMat.cols,                                 //width
                                        cvMat.rows,                                 //height
                                        8,                                          //bits per component
                                        8 * cvMat.elemSize(),                       //bits per pixel
                                        cvMat.step[0],                            //bytesPerRow
                                        colorSpace,                                 //colorspace
                                        kCGImageAlphaNone|kCGBitmapByteOrderDefault,// bitmap info
                                        provider,                                   //CGDataProviderRef
                                        NULL,                                       //decode
                                        false,                                      //should interpolate
                                        kCGRenderingIntentDefault                   //intent
                                        );
    
    
    // Getting UIImage from CGImage
    UIImage *finalImage = [UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);
    
    return finalImage;
}

- (cv::Mat)cvMatFromUIImage:(UIImage *)image
{
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(image.CGImage);
    CGFloat cols = image.size.width;
    CGFloat rows = image.size.height;
    
    cv::Mat cvMat(rows, cols, CV_8UC4); // 8 bits per component, 4 channels (color channels + alpha)
    
    CGContextRef contextRef = CGBitmapContextCreate(cvMat.data,                 // Pointer to  data
                                                    cols,                       // Width of bitmap
                                                    rows,                       // Height of bitmap
                                                    8,                          // Bits per component
                                                    cvMat.step[0],              // Bytes per row
                                                    colorSpace,                 // Colorspace
                                                    kCGImageAlphaNoneSkipLast |
                                                    kCGBitmapByteOrderDefault); // Bitmap info flags
    
    CGContextDrawImage(contextRef, CGRectMake(0, 0, cols, rows), image.CGImage);
    CGContextRelease(contextRef);
    
    return cvMat;
}

@end
