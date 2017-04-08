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
#include "armadillo"


class DataBuffer {
private:
    arma::mat _mat;
    int _maxLength;
    int _current;
    int _size;
    
public:
    DataBuffer(int maxLength);
    bool hasData();
    void pushData(double r, double g, double b);
    arma::mat getData();
};

#endif /* DataBuffer_hpp */
