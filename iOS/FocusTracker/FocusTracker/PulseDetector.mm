//
//  PulseDetector.m
//  FocusTracker
//
//  Created by Kai Kang on 4/8/17.
//  Copyright © 2017 Ted Li. All rights reserved.
//

#import "PulseDetector.h"

#ifdef __cplusplus
#include <cstdlib>
#include "ica.h"
#include "DataBuffer.hpp"
#include <math.h>
using namespace std;
#endif

@implementation PulseDetector

#define FFT_SIZE 1024

+ (double)getPulse:(DataBuffer *)db hamming_window:(arma::vec &)hamming_window prevPulse:(double)prevPulse {
    if (!db->hasData()) {
        return -1;
    }
    arma::mat RGBdata = db->getData();
    uint64_t timePassed = db->getTimeElapsed();
    cout << "FPS: " << FFT_SIZE / (timePassed / 1000000000.0) << endl;
    double fps = FFT_SIZE / (timePassed / 1000000000.0);
    // whitening
    // TODO optimize this
    arma::vec means(3), stddevs(3);
    
    for (int i = 0; i < 3; i++) {
        means(i) = arma::mean(RGBdata.row(i));
        stddevs(i) = arma::stddev(RGBdata.row(i));
    }
    
    for (int i = 0; i < 3; i++) {
        for (int j = 0; j < FFT_SIZE; j++) {
            RGBdata(i, j) = (RGBdata(i,j) - means(i)) / stddevs(i);
        }
    }


    // ICA Decomposition
    Fast_ICA ica(RGBdata);
    ica.set_nrof_independent_components(3);
    ica.set_non_linearity( FICA_NONLIN_TANH );
    ica.set_approach( FICA_APPROACH_DEFL );
    ica.separate();
    
    // FFT
    arma::mat ICs = ica.get_independent_components();
    
    /*
    for (int i = 0; i < 3; i++) {
        for (int j = 0; j < FFT_SIZE; j++) {
            ICs(i, j) *= hamming_window(j);
        }
    }*/
    arma::mat transICs = arma::trans(ICs);
    //cout << "windowed ICs" << endl;
    //cout << ICs << endl;
    
    //arma::mat Gdata = RGBdata.submat(1, 0, 1, RGBdata.n_cols-1);
    //arma::mat transGdata = arma::trans(Gdata);
    //arma::cx_mat src_g = arma::fft(transGdata);
    
    arma::cx_mat sources = arma::fft(transICs);
    
    // Find peak
    // we take the magnitudes of the complex numbers. IMPROVE THIS. http://blog.bjornroche.com/2012/07/frequency-detection-using-fft-aka-pitch.html
    arma::mat sources_real = abs(sources);
    
    arma::vec comp = arma::conv_to<arma::vec>::from(sources_real.col(1));
    //TODO calculate FPS
        
    int lower = ceil((50/60.0)/(fps/FFT_SIZE));
    int upper = ceil((200/60.0)/(fps/FFT_SIZE));
    arma::vec validcomp = comp.subvec(lower, upper);
        
    arma::uvec indices = arma::sort_index(validcomp);
    unsigned long index = indices[indices.n_elem - 1];
    
    if (prevPulse >= 60 && prevPulse <= 100) {
        for (int i = indices.n_elem - 1; i >= indices.n_elem - 10; i--) {
            double pulse = (indices[i] + lower) * (fps / FFT_SIZE) * 60;
            if (fabs(pulse - prevPulse) < 5) {
                return pulse;
            }
        }
        return prevPulse;
    } else {
        for (int i = indices.n_elem - 1; i >= indices.n_elem - 10; i--) {
            double pulse = (indices[i] + lower) * (fps / FFT_SIZE) * 60;
            if (pulse >= 60 && pulse <= 100) {
                return pulse;
            }
        }
        return -1;
    }
    return -1;
}

////-------------------------------------------------------------------
//// Simple class used to employ vDSP's efficient FFTs within Armadillo
////
//// Written by Simon Lucey 2016
////-------------------------------------------------------------------
//class vDSP_FFT2{
//public:
//    int wlog2_; // Log 2 width of matrix (rounded to nearest integer)
//    int hlog2_; // Log 2 height of matrix (rounded to nearest integer)
//    int total_size_; // Total size of the signal
//    FFTSetup setup_; // Setup stuff for fft (part of vDSP)
//    float *ptr_xf_; // pointer to output of FFT on x
//    DSPSplitComplex xf_; // Special vDSP struct for complex arrays
//    
//    // Class functions
//    
//    // Constructor based on size of x
//    vDSP_FFT2(arma::fmat &x){
//        
//        // Get the width and height in power of 2
//        wlog2_ = ceil(log2(x.n_cols));
//        hlog2_ = ceil(log2(x.n_rows));
//        
//        // Setup FFT for Radix2 FFT
//        int nlog2 = std::max(wlog2_, hlog2_); // Get the max value
//        setup_ = vDSP_create_fftsetup(nlog2, FFT_RADIX2);
//        
//        // Get the total size
//        total_size_ = pow(2, wlog2_)*pow(2,hlog2_);
//        
//        // Allocate space for result of the FFT
//        ptr_xf_ = (float *) malloc(total_size_*sizeof(float));
//        
//        // Special struct that vDSP uses for FFTs
//        xf_ = DSPSplitComplex{ptr_xf_, ptr_xf_ + total_size_/2};
//    };
//    
//    // Destructor
//    ~vDSP_FFT2(){
//        // Destroy everything setup for FFT
//        vDSP_destroy_fftsetup(setup_);
//        
//        // Free up the memory
//        free(ptr_xf_);
//    };
//    
//    // Member function to apply the 2D FFT
//    DSPSplitComplex *apply(arma::fmat &x) {
//        
//        // Split the signal into real and imaginary components
//        vDSP_ctoz((DSPComplex *) x.memptr(), 2, &xf_, 1, total_size_/2);
//        
//        // Apply the FFT to the signal
//        vDSP_fft2d_zrip(setup_, &xf_, 1, 0, wlog2_, hlog2_, FFT_FORWARD);
//        
//        // Return the pointer
//        return(&xf_);
//    };
//    
//    // Display the contents of the fft
//    void display() {
//        int w = pow(2,wlog2_); int h = pow(2,hlog2_);
//        for(int i=0; i<(w*h)/2; i++) {
//            std::cout << xf_.realp[i]/2 << " j*" << xf_.imagp[i]/2 << std::endl;
//        }
//    }
//};


@end
