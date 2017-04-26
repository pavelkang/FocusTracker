//
//  DataBuffer.cpp
//  FocusTracker
//
//  Created by Ted Li on 4/8/17.
//  Copyright © 2017 Ted Li. All rights reserved.
//

#include "DataBuffer.hpp"

DataBuffer::DataBuffer(int maxLength) {
    _maxLength = maxLength;
    _mat = arma::mat(3, _maxLength);
    _current = 0;
    _size = 0;
    _timestamps.reserve(maxLength);
    mach_timebase_info(&_info);
}

bool DataBuffer::hasData() {
    return _size == _maxLength;
}

void DataBuffer::pushData(double r, double g, double b) {
    _mat(0, _current) = r;
    _mat(1, _current) = g;
    _mat(2, _current) = b;
    if (_size < _maxLength) {
        ++_size;
    }
    _timestamps[_current] = mach_absolute_time();
    _current = (_current + 1) % _maxLength;
}

arma::mat DataBuffer::getData() {
    arma::mat data(3, _maxLength);
    data(arma::span::all, arma::span(0, _maxLength - _current - 1)) = _mat(arma::span::all, arma::span(_current, _maxLength - 1));
    data(arma::span::all, arma::span(_maxLength - _current, _maxLength - 1)) = _mat(arma::span::all, arma::span(0, _current - 1));
    return data;
}

uint64_t DataBuffer::getTimeElapsed() {
    uint64_t start_time = _timestamps[_current];
    uint64_t current_time = _timestamps[(_current - 1) % _maxLength];
    uint64_t timeElapsed = (current_time - start_time) * _info.numer / _info.denom;
    return timeElapsed;
}
