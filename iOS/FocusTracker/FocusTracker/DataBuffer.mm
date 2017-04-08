//
//  DataBuffer.m
//  FocusTracker
//
//  Created by Ted Li on 4/8/17.
//  Copyright © 2017 Ted Li. All rights reserved.
//

#import "DataBuffer.h"


using namespace std;

@interface DataBuffer () {
    arma::mat _mat;
    int _maxLength;
    int _current;
    int _size;
}
@end

@implementation DataBuffer

- (id)initWithMaxLength:(int)length
{
    self = [super init];
    if (self) {
        _maxLength = length;
        _mat = arma::mat(3, _maxLength);
    }
    return self;
}

- (BOOL)hasData
{
    return _size == _maxLength;
}

- (void)pushData:(double)r g:(double)g b:(double)b
{
    _mat(0, _current) = r;
    _mat(1, _current) = g;
    _mat(2, _current) = b;
    if (_size < _maxLength) {
        ++_size;
    }
    _current = (_current + 1) % _maxLength;
}

- (arma::mat)getData
{
    arma::mat data(3, _maxLength);
    data(arma::span::all, arma::span(0, _maxLength - _current - 1)) = _mat(arma::span::all, arma::span(_current, _maxLength - 1));
    data(arma::span::all, arma::span(_maxLength - _current, _maxLength - 1)) = _mat(arma::span::all, arma::span(0, _current - 1));
    return data;
}


@end
