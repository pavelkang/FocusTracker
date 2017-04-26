//
//  DataBuffer.hpp
//  FocusTracker
//
//  Created by Ted Li on 4/8/17.
//  Copyright © 2017 Ted Li. All rights reserved.
//

#ifndef DataBuffer_hpp
#define DataBuffer_hpp

#include <stdio.h>
#include <vector>
#include "armadillo"
#include <mach/mach_time.h>

class DataBuffer {
private:
    arma::mat _mat;
    int _maxLength;
    int _current;
    int _size;
    std::vector<uint64_t> _timestamps;
    mach_timebase_info_data_t _info;
    
public:
    DataBuffer(int maxLength);
    bool hasData();
    void pushData(double r, double g, double b);
    arma::mat getData();
    uint64_t getTimeElapsed();
};

#endif /* DataBuffer_hpp */
