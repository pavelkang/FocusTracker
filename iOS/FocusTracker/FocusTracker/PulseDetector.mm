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
using namespace std;
#endif

@implementation PulseDetector

// 0.75 to 4 Hz
int UPPER_BOUND = 120; //4 / (1.0 / 30.0);
int LOWER_BOUND = 23; //0.75 / (1.0 / 30.0);


+ (int)getPulse:(DataBuffer *) db{
    if (!db->hasData()) {
        return -1;
    }
    arma::mat RGBdata = db->getData();
    //cout << RGBdata << endl;
    assert(RGBdata.n_rows == 3);

    // ICA Decomposition
    Fast_ICA ica(RGBdata);
    ica.set_nrof_independent_components(3);
    ica.set_non_linearity(FICA_NONLIN_TANH);
    ica.set_approach( FICA_APPROACH_DEFL );
    ica.separate();
    
    // FFT
    // window? hamming?
    arma::mat ICs = ica.get_independent_components();
    arma::mat transICs = arma::trans(ICs);
    
    
    arma::mat Gdata = RGBdata.submat(1, 0, 1, RGBdata.n_cols-1);
    
    
    arma::mat transGdata = arma::trans(Gdata);
    arma::cx_mat src_g = arma::fft(transGdata);
    
    arma::cx_mat sources = arma::fft(transICs);
    
    //cout << ICs << endl;
    
    // Find peak
    // we take the magnitudes of the complex numbers. IMPROVE THIS. http://blog.bjornroche.com/2012/07/frequency-detection-using-fft-aka-pitch.html
    arma::mat sources_real = abs(sources);
    arma::mat gdata_real = abs(src_g);
    arma::vec peaks(3);
    
    cout << gdata_real << endl;
    
    for (int i = 0; i < 3; i++) {
        cout << "component " << (i+1) << endl;
        arma::vec comp = arma::conv_to<arma::vec>::from(sources_real.col(i));
        //cout << comp << endl;
        
//        arma::uvec indices = sort_index(comp);
//        for (int i = indices.n_elem-1; i >=indices.n_elem-4; i--) {
//            cout << "bin number: " << indices[i] << ", bpm: " << indices[i] * 60 << endl;
//        }
    }

    //std::cout << peaks << std::endl;
    
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
